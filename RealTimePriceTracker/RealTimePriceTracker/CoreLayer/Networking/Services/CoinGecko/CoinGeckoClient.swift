//
//  CoinGeckoClient.swift
//  RealTimePriceTracker
//

import Foundation

nonisolated protocol CoinGeckoClientProtocol: Sendable {
    func fetchTopAssets(limit: Int) async throws -> [CoinMarket]
    func fetchPriceChart(coinID: String, days: Int) async throws -> [PricePoint]
}

nonisolated enum CoinGeckoClientError: Error, Equatable, Sendable {
    case invalidRequest
    case invalidHTTPResponse
    case rateLimited
    case httpStatusCode(Int)
    case invalidPayload
    case emptyChart
}

/// Configuration for CoinGecko's keyless or authenticated Demo API.
nonisolated struct CoinGeckoConfiguration: Equatable, Sendable {
    static let keyless = Self(
        baseURL: URL(string: "https://api.coingecko.com/api/v3")!,
        demoAPIKey: nil,
        requestTimeout: 20
    )

    let baseURL: URL
    let demoAPIKey: String?
    let requestTimeout: TimeInterval
}

private nonisolated struct CoinGeckoMarketChartResponse: Decodable, Sendable {
    let prices: [[Double]]
}

/// Actor-isolated CoinGecko HTTP client implemented only with async `URLSession`.
///
/// The client validates status codes and performs JSON decoding away from the main
/// actor. Its keyless default is appropriate for demos; production should inject a
/// Demo/Pro configuration and a rate-limit policy.
actor CoinGeckoClient: CoinGeckoClientProtocol {
    typealias DataLoader = @Sendable (
        URLRequest
    ) async throws -> (Data, URLResponse)

    private let configuration: CoinGeckoConfiguration
    private let dataLoader: DataLoader

    init(
        configuration: CoinGeckoConfiguration = .keyless,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.dataLoader = { request in
            try await session.data(for: request)
        }
    }

    init(
        configuration: CoinGeckoConfiguration = .keyless,
        dataLoader: @escaping DataLoader
    ) {
        self.configuration = configuration
        self.dataLoader = dataLoader
    }

    /// Fetches one market-cap-sorted page from `/coins/markets`.
    func fetchTopAssets(limit: Int = 100) async throws -> [CoinMarket] {
        guard (1...250).contains(limit) else {
            throw CoinGeckoClientError.invalidRequest
        }

        let queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "order", value: "market_cap_desc"),
            URLQueryItem(name: "per_page", value: String(limit)),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "sparkline", value: "false"),
            URLQueryItem(name: "price_change_percentage", value: "24h")
        ]
        let request = try makeRequest(
            pathComponents: ["coins", "markets"],
            queryItems: queryItems
        )
        let data = try await load(request)

        do {
            return try JSONDecoder().decode([CoinMarket].self, from: data)
        } catch {
            throw CoinGeckoClientError.invalidPayload
        }
    }

    /// Fetches seven-day-style historical points using automatic CoinGecko
    /// granularity. For 2–90 days, CoinGecko returns hourly data.
    func fetchPriceChart(
        coinID: String,
        days: Int = 7
    ) async throws -> [PricePoint] {
        guard !coinID.isEmpty, days > 0 else {
            throw CoinGeckoClientError.invalidRequest
        }

        let request = try makeRequest(
            pathComponents: ["coins", coinID, "market_chart"],
            queryItems: [
                URLQueryItem(name: "vs_currency", value: "usd"),
                URLQueryItem(name: "days", value: String(days))
            ]
        )
        let data = try await load(request)
        let response: CoinGeckoMarketChartResponse

        do {
            response = try JSONDecoder().decode(
                CoinGeckoMarketChartResponse.self,
                from: data
            )
        } catch {
            throw CoinGeckoClientError.invalidPayload
        }

        let points = response.prices.compactMap { sample -> PricePoint? in
            guard sample.count >= 2,
                  sample[0].isFinite,
                  sample[1].isFinite else {
                return nil
            }

            return PricePoint(
                date: Date(timeIntervalSince1970: sample[0] / 1_000),
                price: Decimal(sample[1])
            )
        }

        guard !points.isEmpty else {
            throw CoinGeckoClientError.emptyChart
        }

        return points.sorted { $0.date < $1.date }
    }

    private func makeRequest(
        pathComponents: [String],
        queryItems: [URLQueryItem]
    ) throws -> URLRequest {
        let endpoint = pathComponents.reduce(configuration.baseURL) {
            $0.appendingPathComponent($1)
        }
        guard var components = URLComponents(
            url: endpoint,
            resolvingAgainstBaseURL: false
        ) else {
            throw CoinGeckoClientError.invalidRequest
        }

        components.queryItems = queryItems
        guard let url = components.url else {
            throw CoinGeckoClientError.invalidRequest
        }

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadRevalidatingCacheData,
            timeoutInterval: configuration.requestTimeout
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let key = configuration.demoAPIKey, !key.isEmpty {
            request.setValue(key, forHTTPHeaderField: "x-cg-demo-api-key")
        }

        return request
    }

    private func load(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await dataLoader(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoinGeckoClientError.invalidHTTPResponse
        }
        guard httpResponse.statusCode != 429 else {
            throw CoinGeckoClientError.rateLimited
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw CoinGeckoClientError.httpStatusCode(
                httpResponse.statusCode
            )
        }

        return data
    }
}

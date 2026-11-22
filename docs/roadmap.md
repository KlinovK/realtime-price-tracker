# Roadmap

The four strategic priorities have equal weight: **production-quality product**, **senior iOS engineering**, **professional AI-assisted workflow**, and **Python / AI Engineer learning**. Sequence work by dependencies and product risk rather than treating one learning track as expendable. [ARCHITECTURE.md](../ARCHITECTURE.md) describes current design and invariants; this file is the single prioritized work list.

## DONE

- Offline-first architecture with SwiftData-backed market, favorite, and chart presentation.
- Core CoinGecko market data and Binance realtime integration.
- Shared XCTest scheme and GitHub Actions test reporting.
- Explicit Binance identity mapping for approved assets, completed on the `codex/binance-identity-mapping` branch.

## CURRENT

- AI Engineering Workflow Setup: establish agent instructions, risk-based delivery, independent review, and a lightweight Engineering Learning Review.

## PLANNED

### Next iOS market-data stages

1. **Stage 4.3 — Binance Spot Metadata Validation:** verify approved pairs against current Spot availability and trading status.
2. **Stage 4.4 — Per-pair Freshness / USD-USDT:** define freshness per subscribed pair and make currency/unit presentation explicit.
3. **Stage 4.5 — Mapping Coverage:** measure supported versus unsupported favorite pairs and surface gaps accurately.

### Product and engineering hardening

- iOS reliability and product hardening: quota-aware API behavior, offline icon needs, persistence migration planning, UI coverage, and release readiness. Prioritize from observed risks; technical details remain in [ARCHITECTURE.md](../ARCHITECTURE.md#remaining-production-hardening).

### Python / AI Engineer learning and product exploration

- Python backend architecture, then FastAPI and PostgreSQL.
- LLM API integration, tool calling, RAG / embeddings, and LangGraph, with small verifiable projects before product integration.
- **AI Chat Module — Medium / P2.** Design and schedule it after its dependencies and acceptance criteria are clear; it is planned, not implemented.

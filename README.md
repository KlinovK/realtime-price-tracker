# Realtime Price Tracker

A modern real-time price tracking application built with **SwiftUI**, **WebSockets**, and **modern Swift concurrency**.

The project follows a **custom TCA-inspired architecture** for predictable state management and scalable feature development, while maintaining high performance and testability.

---

## Features

- ⚡ Real-time price updates using WebSockets
- 📈 Live market/asset tracking
- 🧠 Custom TCA-inspired architecture
- 🧵 Modern Swift Concurrency (`async/await`)
- 📱 Built entirely with SwiftUI
- 🛠 Modular and scalable codebase
- 🚀 High-performance real-time communication

---

## Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Architecture:** Custom TCA (The Composable Architecture inspired)
- **Networking:** WebSockets
- **Concurrency:** Async/Await & Structured Concurrency
- **Testing:** XCTest
- **Platform:** iOS

---

## Architecture Overview

The application uses a custom implementation inspired by **The Composable Architecture (TCA)** principles:

- Single source of truth
- Unidirectional data flow
- Reducer-based state updates
- Dependency injection
- Predictable side effects
- Testable business logic

This structure makes the app highly maintainable and scalable for real-time systems.

---

## Installation

Clone the repository:

```bash
git clone https://github.com/KlinovK/realtime-price-tracker.git
cd realtime-price-tracker
```

Open the project in Xcode:

```bash
open realtime-price-tracker.xcodeproj
```

Run the app on simulator or device.

---

## Requirements

- Xcode 15+
- iOS 17+
- Swift 5.9+

---

## Real-Time Updates

The app connects to live data streams using WebSockets, enabling:

- Instant price updates
- Low-latency communication
- Efficient streaming
- Reactive UI synchronization

Swift concurrency ensures smooth async data handling without callback complexity.

---

## Testing

The project includes comprehensive test coverage:

- ✅ Reducer tests
- ✅ State transition tests
- ✅ WebSocket service tests
- ✅ Async concurrency tests
- ✅ Integration tests

Run tests with:

```bash
⌘ + U
```

or:

```bash
xcodebuild test
```

---

## Future Improvements

- [ ] Multiple exchange support
- [ ] Historical charting
- [ ] Push notifications
- [ ] Offline persistence
- [ ] Widget support
- [ ] macOS/iPadOS support

---

## Contributing

Contributions are welcome.

1. Fork the repository
2. Create a feature branch

```bash
git checkout -b feature/amazing-feature
```

3. Commit changes

```bash
git commit -m "Add amazing feature"
```

4. Push to branch

```bash
git push origin feature/amazing-feature
```

5. Open a Pull Request

---

## License

This project is licensed under the MIT License.

---

## Author

Created by [KlinovK](https://github.com/KlinovK)

Repository: [Realtime Price Tracker](https://github.com/KlinovK/realtime-price-tracker)

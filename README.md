# wild-OCR

**Universal, offline-first, multilingual OCR foundation for iPhone.**

Independent Swift Package; not a fork of GameLingoAI. The existing GameLingoAI main and ML Kit experiment branches remain independent.

## Current capabilities

- Universal OCR block representation with normalized coordinates, reading order, script and optional confidence.
- Unicode script classification for Han, kana, hangul, Latin, Cyrillic, Arabic, Devanagari, Thai, Greek and Hebrew. Script heuristics **do not** guarantee language detection.
- Installed-model-aware routing with Apple Vision fallback, local ROI-change gate, and privacy-safe P50/P95 measurement.
- Apple Vision recognition for iOS using VNRecognizeTextRequest and CVPixelBuffer.
- PaddleOCR integration interface only. **Paddle models, ONNX Runtime, iOS build and benchmarks have NOT yet been integrated or verified.**
- No game capture, translation, PiP, cloud OCR, paid API or persistent screenshots in this library.

## Swift Package

Requires Swift 5.9+, iOS 17+ or macOS 13+; platform-independent logic can also be tested on Linux.

Run: `swift test`

Main modules:

- `WildOCRCore`: data models, Unicode script heuristics, routing, change detection, metrics.
- `WildOCRAppleVision`: native on-device image OCR.
- `WildOCRPaddleBridge`: placeholder API for verified future PaddleOCR model integration.

See `docs/ARCHITECTURE.md`. Contributions must preserve offline-first behavior, language accuracy and performance measurement before promising additional language support.
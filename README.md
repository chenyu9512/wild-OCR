# wild-OCR

**Independent offline-first iPhone multilingual OCR project.** Not a GameLingoAI fork.

## iPhone App 0.2.0

The `ios/WildOCRApp` app includes offline native Apple Vision OCR using PhotosPicker or Files, Fast/Accurate selection, automatic or explicit language hints, text copy, detected script and per-line positions, and actual device OCR P50/P95 timing.

It also includes a **verified local PaddleOCR model manager** (manifest + SHA-256 check) and a Vision vs PaddleOCR comparison screen with exact-image matching and ground-truth character error rate. The Paddle runtime is **not yet running inside this app**; its models remain inactive even after verification. To benchmark real Paddle inference, a second Codemagic workflow builds PaddleOCR's **official standalone iOS demo** with ONNX Runtime.

## Build

Use Codemagic `ios-wild-ocr-unsigned` to build `wild-OCR-0.2.0-unsigned.ipa`, then sign for iPhone. Optional `ios-paddle-upstream-unsigned` builds the independent PaddleOCR sample IPA. Native iOS build status must be verified before claiming a working build.

The Swift Package remains independently testable with `swift test`; core OCR structures, script classification, model routing, timing, manifest validation and CER comparison have unit tests.

See [iOS build & test guide](docs/IOS_APP.md) and [architecture](docs/ARCHITECTURE.md). No paid OCR API, cloud image upload or automatic model download is performed.

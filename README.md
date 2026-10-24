# wild-OCR

**Independent offline-first iPhone multilingual OCR project.** Not a GameLingoAI fork.

## iPhone App 0.4.0

New in 0.4.0:
- **Batch offline OCR:** 1–24 images from Photos or Files; sequential work on device, cancellation, per-image status and text export.
- **Editable ROI:** full-frame, center, bottom and draggable/resizable custom scan region with percentage sliders; Vision and optional Paddle both use the same normalized region.
- **Privacy-safe performance lab:** per-run image decode and inference latency, P50/P95/max, thermal indicator, CSV export. No image text or screenshot is stored in performance telemetry.
- **In-app PaddleOCR (experimental separate build):** the `ios-wild-paddle-integrated-unsigned` workflow vendors the official pinned PaddleOCR iOS detection/recognition code, OpenCV, Yams and ONNX Runtime, and bundles SHA-256-verified PaddlePaddle PP-OCRv5 Mobile models. The experimental app can switch between genuine Vision and Paddle inference or run an explicit A/B test. The default `ios-wild-ocr-unsigned` build remains dependency-free and Apple Vision only.
- **Important:** PP-OCRv5 Mobile in this build mainly targets Chinese, English and Japanese; this does **not** mean every language is supported. More script-specific models require separate integration and testing.

The integrated Paddle build has its own bundle ID and is not the same as the standalone upstream demo. Model downloads occur at **build time**, not on the iPhone. Successful iOS compilation does not prove accuracy or performance until tested on a device.



The `ios/WildOCRApp` app now provides a four-tab SwiftUI product experience: **Recognize, Session Records, Model Center, Benchmark Lab**, plus appearance/privacy settings. It includes offline Apple Vision OCR from PhotosPicker or Files, Fast/Accurate selection, region presets (full / center / bottom), automatic or explicit language hints, text-box overlays, copy and share, manual session-only saved results, detected scripts and positions, and actual device OCR P50/P95 timing.

The standard IPA includes a **verified local PaddleOCR model manager** (manifest + SHA-256 check) and a Vision vs external PaddleOCR comparison screen with exact-image matching and ground-truth CER. Manually imported Paddle models do not become executable simply by importing them. The **separate integrated experimental IPA** builds actual in-process PaddleOCR ONNX detection and recognition with a bundled, pinned PP-OCRv5 Mobile model; it can run two local engines, if its native build passes. The independent original PaddleOCR demo can still be built for cross-checking.

## Build

Use Codemagic `ios-wild-ocr-unsigned` to build `wild-OCR-0.4.0-unsigned.ipa`, then sign for iPhone. Optional `ios-paddle-upstream-unsigned` builds the independent PaddleOCR sample IPA. Native iOS build status must be verified before claiming a working build.

The Swift Package remains independently testable with `swift test`; core OCR structures, script classification, model routing, timing, manifest validation and CER comparison have unit tests.

See [iOS build & test guide](docs/IOS_APP.md) and [architecture](docs/ARCHITECTURE.md). No paid OCR API, cloud image upload or automatic model download is performed.

# wild-OCR 0.2.0 iPhone app

This is a standalone iOS 17+ SwiftUI app. It includes local Apple Vision recognition (Fast/Accurate and automatic language hints), PhotosPicker/Files image import, OCR text and reading-order blocks, copy action, native timing P50/P95, externally reported PaddleOCR A/B and character error rate (CER).

## Offline model packs

Import a folder containing manifest.json and the actual ONNX model assets. The manifest must provide schemaVersion=1, id, displayName, engine=paddle-onnx, license, scripts[], languages[], and assets[] with path, SHA-256 and byte length for every asset. Installation rejects unsafe paths, symbolic links, file size and checksum mismatches. No model bytes are fetched automatically.

**Imported PaddleOCR models are only verified local files. They are not yet an executing inference engine inside the wild-OCR app.**

## Genuine PaddleOCR experiment

The Codemagic `ios-paddle-upstream-unsigned` workflow checks out official PaddleOCR v3.7.0 at pinned commit, installs the upstream ONNX Runtime dependencies and downloads a supported model using the original script. It compiles and packages the **separate** official PaddleOCR iOS demo. Specify PADDLE_MODEL_PRESET=PP-OCRv6_small to test v6 instead of the default PP-OCRv5_mobile.

Compare the same screenshot in both apps; manually enter the external Paddle time and recognized text, or import an external JSON OCRBenchmarkResult with matching imageSHA256. External manual timings must not be reported as local benchmark results.

## Build

Codemagic `ios-wild-ocr-unsigned` generates the Xcode project with XcodeGen and produces an unsigned wild-OCR-0.2.0-unsigned.ipa for further signing (e.g. SideStore). GitHub Actions checks the Swift Package and native Xcode app. Neither iOS build nor real device speed has been confirmed until CI actually succeeds.

## Work remaining

Actual PaddleOCR inside wild-OCR process, full 100+ language pack compatibility, mixed-script per-region routing, live screen capture, native cross-engine speed/CER/thermal benchmarks and 30-minute stability tests.

Official guide: https://www.paddleocr.ai/latest/en/version3.x/inference_deployment/cross_platform/ios_deployment.html

# wild-OCR 0.4.0 iPhone application


This is a standalone iOS 17+ SwiftUI app. It includes local Apple Vision recognition (Fast/Accurate and automatic language hints), PhotosPicker/Files image import, OCR text and reading-order blocks, copy action, native timing P50/P95, externally reported PaddleOCR A/B and character error rate (CER).

## User experience (0.4.0)

- **Recognize:** redesigned capture workspace, picture-box overlay, multi-language choices, Fast/Accurate modes, scan region presets, copied/shared results, and detailed per-line text.
- **Records:** explicitly save recent OCR output to an in-memory list for the current session. This is not a persistent archive; closing the app discards it.
- **Model Center:** separate the functioning Apple Vision engine from verified-but-inactive PaddleOCR model packs. Import models with checksum validation, view installed packs and delete them with confirmation.
- **Benchmark Lab:** run five actual local Vision measurements; compare manually collected Paddle results (or SHA-matched JSON); calculate character error rate against manually provided ground truth.
- **Settings:** dark/light/system appearance, bounding-box visibility, privacy disclosure, and clear session data.

The app does **not** perform live system-wide OCR, PiP, in-app PaddleOCR inference or cloud-based recognition. Unsupported Vision language hints may fall back to auto recognition. The application needs on-device benchmarking before performance claims.

## Offline model packs

Import a folder containing manifest.json and the actual ONNX model assets. The manifest must provide schemaVersion=1, id, displayName, engine=paddle-onnx, license, scripts[], languages[], and assets[] with path, SHA-256 and byte length for every asset. Installation rejects unsafe paths, symbolic links, file size and checksum mismatches. No model bytes are fetched automatically.

**Imported PaddleOCR models are only verified local files. They are not yet an executing inference engine inside the wild-OCR app.**

## Genuine PaddleOCR experiment

The Codemagic `ios-paddle-upstream-unsigned` workflow checks out official PaddleOCR v3.7.0 at pinned commit, installs the upstream ONNX Runtime dependencies and downloads a supported model using the original script. It compiles and packages the **separate** official PaddleOCR iOS demo. Specify PADDLE_MODEL_PRESET=PP-OCRv6_small to test v6 instead of the default PP-OCRv5_mobile.

Compare the same screenshot in both apps; manually enter the external Paddle time and recognized text, or import an external JSON OCRBenchmarkResult with matching imageSHA256. External manual timings must not be reported as local benchmark results.

## Build

Codemagic `ios-wild-ocr-unsigned` generates the Xcode project with XcodeGen and produces an unsigned wild-OCR-0.4.0-unsigned.ipa for further signing (e.g. SideStore). GitHub Actions checks the Swift Package and native Xcode app. Neither iOS build nor real device speed has been confirmed until CI actually succeeds.

## Work remaining

Actual PaddleOCR inside wild-OCR process, full 100+ language pack compatibility, mixed-script per-region routing, live screen capture, native cross-engine speed/CER/thermal benchmarks and 30-minute stability tests.

Official guide: https://www.paddleocr.ai/latest/en/version3.x/inference_deployment/cross_platform/ios_deployment.html


## 0.4.0 additions

- Bulk OCR accepts at most 24 photos/images; decodes sequentially to avoid concurrently saturating an iPhone. The results can be copied individually or shared as a plain-text batch. Cancel retains already completed results. File size is limited to 16 MB per image.
- Custom Vision ROI is expressed in normalized bottom-left coordinates, matching Vision. The image editor lets the user drag/resize and adjust x, y, width, height with sliders.
- Per-operation OCR diagnostics split image decoding from recognition and report total P50/P95/maximum, sample count, basic thermal state, and exportable metrics CSV. Do not mix source images or language/ROI quality settings when comparing.
- The experimental in-app PaddleOCR build uses PaddlePaddle PP-OCRv5 Mobile detection and recognition ONNX models together with original iOS demo inference engine/bridges. SwiftUI engine selection, batch OCR, and direct Vision/Paddle A/B exercise actual ONNX inference. It is **not** part of the default Vision-only IPA.

### Integrated PaddleOCR experiment

GitHub Actions: \`iOS PaddleOCR integrated build\` (manual and integration-source changes).
Codemagic: \`ios-wild-paddle-integrated-unsigned\`.

Both workflows pin PaddleOCR source tag v3.7.0 at commit b03f46425e8ff4442b268ce449e3eef758146cd4, fetch \`PaddlePaddle/PP-OCRv5_mobile_det_onnx\` and \`PaddlePaddle/PP-OCRv5_mobile_rec_onnx\` from PaddlePaddle's official Hugging Face repos at build time, verify ONNX SHA-256, vendor all official Swift/ObjC++ engine components, then compile the separate \`com.chenyu9512.wildocr.paddle\` application with ONNX Runtime, OpenCV and Yams.

The downloaded v5 model is not a universal 106-language model; targeted alternative script recognizers (Korean, Cyrillic, Arabic, South Asian, etc.) are future work.

Do not claim a valid experimental IPA unless its actual CI has passed. The app itself does not automatically download model files or call paid APIs.

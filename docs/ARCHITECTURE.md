# wild-OCR: Universal OCR architecture

1. Frame acquisition: app-specific capture adapter provides CVPixelBuffer, orientation and capture timestamp. No screen capture privilege is included in this library.
2. Frame change detection: compute a cheap region fingerprint upstream. OCRChangeGate caches only fingerprint/time, never screenshots.
3. Primary OCR: AppleVisionOCR uses VNRecognizeTextRequest on-device, automatic language mode by default. Query supported languages for the actual recognition revision.
4. Structured output: each block has lower-left normalized coordinates, script hint, optional language hint, confidence (only if provided), engine and reading order.
5. Model routing: first OCR obtains preliminary text/regions; script classifier decides which optional installed model might help for failed or difficult regions. A script is not a language; Latin is not necessarily English, Han is not necessarily Chinese.
6. Optional PaddleOCR: adapter protocol is included. Runtime, model file packaging, language dictionary, preprocessing, layout/detector and postprocessing are **not yet integrated**. Avoid claiming support for 106 languages in the executable until models are verified.
7. Downstream: translation and PiP are separate consumers. No automatic network requests, no subscription or paid API, no screenshots persisted.

## Performance and privacy gates

- Measure P50 and P95 separately for detection, script routing, recognition and complete OCR. Also measure memory pressure, cold-start and 30-minute thermal drift on a real device.
- Default to Vision. Enable a secondary model only by explicit configuration or bounded fallback after a primary low-confidence result. Do not run every model continuously.
- Pin model versions, validate hashes, and never silently download language models. Respect model licenses before redistribution.
- Test against real game screenshots with independent ground-truth transcription for CER and per-language coverage; speed alone does not prove non-regression.

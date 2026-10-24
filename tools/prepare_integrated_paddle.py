#!/usr/bin/env python3
"""Vendor the official PaddleOCR v3.7.0 iOS inference pipeline for one CI build.

No third-party source or model is silently downloaded at app runtime.
Run only after the pinned upstream repository and official model installer.
"""
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = "b03f46425e8ff4442b268ce449e3eef758146cd4"
if len(sys.argv) not in (2, 3):
    raise SystemExit("usage: prepare_integrated_paddle.py /path/to/PaddleOCR-upstream [v5-mobile|v6-small]")
preset = sys.argv[2] if len(sys.argv) == 3 else "v5-mobile"
if preset not in ("v5-mobile", "v6-small"):
    raise SystemExit("Unsupported model preset")
repo = Path(sys.argv[1]).resolve()
if not (repo / "deploy/ios_demo/PaddleOCRDemo").is_dir():
    raise SystemExit("Missing official PaddleOCR iOS source")
import subprocess
head = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"],
                               text=True).strip()
if head != EXPECTED:
    raise SystemExit(f"Unexpected PaddleOCR source revision {head}, expected {EXPECTED}")

app = repo / "deploy/ios_demo/PaddleOCRDemo"
vendor = ROOT / "ios/PaddleVendor"
vendor.mkdir(parents=True, exist_ok=True)
for name, source in [
    ("Engine", app / "Engine"),
    ("ThirdParty/Clipper1", app / "ThirdParty/Clipper1"),
    ("Supporting", app / "Supporting"),
]:
    destination = vendor / name
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(source, destination)

# XcodeGen/CocoaPods exposes the ONNX Objective-C API as a framework.
# The original demo's flat header import relies on its own Xcode header paths.
bridge = vendor / "Supporting/PaddleOCRDemo-Bridging-Header.h"
header = bridge.read_text()
header = header.replace("#import <onnxruntime.h>",
                        "#import <onnxruntime_objc/onnxruntime.h>")
bridge.write_text(header)

# The demo's optional ORT JSON profiler reads private onnxruntime-objc C++ ivars.
# We do not enable that profiling mode in wild-OCR. Replace it with a safe
# explicit unsupported stub rather than linking against unstable private APIs.
# Detection and recognition inference remain exactly the official implementation.
(vendor / "Engine/ORTProfilingBridge.mm").write_text(
    '#import "ORTProfilingBridge.h"\n'
    '@implementation ORTProfilingBridge\n'
    '+ (BOOL)enableProfilingOnSessionOptions:(ORTSessionOptions *)options '
    'pathPrefix:(NSString *)prefix error:(NSError **)error {\n'
    '  if (error) *error = [NSError errorWithDomain:@"wild.paddle" code:501 '
    'userInfo:@{NSLocalizedDescriptionKey:@"ORT JSON profiling disabled"}];\n'
    '  return NO;\n}\n'
    '+ (NSString *)endProfilingOnSession:(ORTSession *)session '
    'error:(NSError **)error {\n'
    '  if (error) *error = [NSError errorWithDomain:@"wild.paddle" code:501 '
    'userInfo:@{NSLocalizedDescriptionKey:@"ORT JSON profiling disabled"}];\n'
    '  return nil;\n}\n@end\n'
)

# Both projects compile into one Swift module. Avoid a global enum symbol
# collision without changing the public wild-OCR core API.
for file in (vendor / "Engine").glob("*.swift"):
    code = file.read_text()
    code = code.replace("OCREngineError", "PaddlePipelineError")
    file.write_text(code)

models = app / "Models"
for name in ["det", "rec"]:
    folder = models / name
    if not (folder / "inference.onnx").exists() and not list(folder.glob("inference*.ort")):
        raise SystemExit(f"Official model installer did not populate {folder}")
    if not (folder / "inference.yml").exists():
        raise SystemExit(f"Official model config missing: {folder}/inference.yml")
dest = ROOT / "ios/WildOCRApp/Models"
if dest.exists():
    shutil.rmtree(dest)
shutil.copytree(models, dest)
(dest / "preset.txt").write_text(preset + "\n", encoding="utf-8")
print("PaddleOCR inference sources and real model prepared:", preset)

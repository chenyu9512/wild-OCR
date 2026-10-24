#!/usr/bin/env python3
"""Create a wild-OCR same-image report from a genuine external Paddle run."""
import argparse
import hashlib
import json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument("--image", required=True)
p.add_argument("--text-file", required=True)
p.add_argument("--duration-ms", required=True, type=int)
p.add_argument("--output", required=True)
p.add_argument("--model", default=None)
a = p.parse_args()
assert a.duration_ms >= 0
record = {
    "imageSHA256": hashlib.sha256(Path(a.image).read_bytes()).hexdigest(),
    "engineID": "paddle-ocr-external",
    "modelID": a.model,
    "quality": "upstream-demo",
    "durationMs": a.duration_ms,
    "text": Path(a.text_file).read_text(encoding="utf-8")
}
Path(a.output).write_text(
    json.dumps(record, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
print("Created", a.output)

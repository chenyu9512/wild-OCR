#!/usr/bin/env python3
"""Fetch official PaddlePaddle PP-OCRv5 Mobile ONNX artifacts from Hugging Face.

Used by the experimental integrated iPhone build because the older Baidu BOS
tar download can return HTTP 403 on hosted macOS CI runners.
Pin SHA-256 checksums of both model weights. Never download on the device.
"""
from pathlib import Path
import hashlib
import sys
import urllib.request

if len(sys.argv) != 2:
    raise SystemExit("Usage: fetch_official_paddle_onnx.py /output/Models")
root = Path(sys.argv[1])
models = {
    "det": ("PaddlePaddle/PP-OCRv5_mobile_det_onnx",
            "a431985659dc921974177a95adcfbb90fd9e51989a5e04d70d0b75f597b6e61d"),
    "rec": ("PaddlePaddle/PP-OCRv5_mobile_rec_onnx",
            "da72dc72ca4dc220df0dfde68c1dedc31c58d3e76a25871122e5056227d50092"),
}
for part, (model, expected_sha) in models.items():
    destination = root / part
    destination.mkdir(parents=True, exist_ok=True)
    for filename in ("inference.onnx", "inference.yml"):
        target = destination / filename
        url = f"https://huggingface.co/{model}/resolve/main/{filename}"
        print("Downloading verified official PaddlePaddle artifact:", model, filename,
              flush=True)
        headers = {"User-Agent": "wild-OCR/0.4.0 official-model-fetcher"}
        request = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(request, timeout=180) as response, target.open("wb") as output:
            sha = hashlib.sha256()
            total = 0
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                total += len(chunk)
                if total > 100_000_000:
                    raise RuntimeError("Model download exceeds expected size")
                output.write(chunk)
                sha.update(chunk)
        if filename.endswith(".onnx") and sha.hexdigest() != expected_sha:
            target.unlink(missing_ok=True)
            raise RuntimeError(f"{model}: unexpected ONNX SHA-256: {sha.hexdigest()}")
        if filename.endswith(".yml"):
            value = target.read_text(encoding="utf-8")
            if "Global:" not in value or "PreProcess:" not in value:
                raise RuntimeError("Unexpected model metadata")
            if part == "rec" and "character_dict:" not in value:
                raise RuntimeError("Recognition dictionary missing")
        print(f"  validated {filename}: {total} bytes", flush=True)
print("Verified PaddlePaddle ONNX artifacts ready")

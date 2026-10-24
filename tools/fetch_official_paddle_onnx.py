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

if len(sys.argv) not in (2, 3):
    raise SystemExit("Usage: fetch_official_paddle_onnx.py /output/Models [v5-mobile|v6-small]")
root = Path(sys.argv[1])
preset = sys.argv[2] if len(sys.argv) == 3 else "v5-mobile"
presets = {
    "v5-mobile": {
        "det": ("PaddlePaddle/PP-OCRv5_mobile_det_onnx",
                "a431985659dc921974177a95adcfbb90fd9e51989a5e04d70d0b75f597b6e61d"),
        "rec": ("PaddlePaddle/PP-OCRv5_mobile_rec_onnx",
                "da72dc72ca4dc220df0dfde68c1dedc31c58d3e76a25871122e5056227d50092"),
    },
    "v6-small": {
        "det": ("PaddlePaddle/PP-OCRv6_small_det_onnx",
                "d73e0058b7a8086bbd57f3d10b8bcd4ff95363f67e06e2762b5e814fe9c9410e"),
        "rec": ("PaddlePaddle/PP-OCRv6_small_rec_onnx",
                "5435fd747c9e0efe15a96d0b378d5bd157e9492ed8fd80edf08f30d02fa24634"),
    },
}
if preset not in presets:
    raise SystemExit("Unsupported Paddle OCR preset: " + preset)
models = presets[preset]

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

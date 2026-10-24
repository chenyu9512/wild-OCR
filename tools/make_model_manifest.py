#!/usr/bin/env python3
"""Build verifiable offline manifests for assets the user already obtained."""
import argparse
import hashlib
import json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument("--folder", required=True)
p.add_argument("--id", required=True)
p.add_argument("--title", required=True)
p.add_argument("--license", required=True)
p.add_argument("--scripts", required=True)
p.add_argument("--languages", required=True)
a = p.parse_args()
folder = Path(a.folder).resolve()
assert folder.is_dir()
assert a.id and all(c in "abcdefghijklmnopqrstuvwxyz0123456789-_" for c in a.id)
assets = []
for file in sorted(folder.rglob("*")):
    if file.name == "manifest.json":
        continue
    assert not file.is_symlink()
    if not file.is_file():
        continue
    assert 0 < file.stat().st_size <= 1_000_000_000
    digest = hashlib.sha256()
    with file.open("rb") as source:
        for chunk in iter(lambda: source.read(1048576), b""):
            digest.update(chunk)
    assets.append(dict(path=file.relative_to(folder).as_posix(),
                       size=file.stat().st_size, sha256=digest.hexdigest()))
assert 1 <= len(assets) <= 32
assert sum(item["size"] for item in assets) <= 1_500_000_000
manifest = dict(schemaVersion=1, id=a.id, displayName=a.title,
                engine="paddle-onnx", license=a.license,
                scripts=a.scripts.split(","), languages=a.languages.split(","),
                assets=assets)
(folder/"manifest.json").write_text(
    json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print("Created", folder/"manifest.json")

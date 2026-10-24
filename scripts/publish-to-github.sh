#!/usr/bin/env bash
set -euo pipefail
# This repository is now initialized on GitHub.
# Clone it, apply changes, then use your configured Git credentials to push.
echo 'Repository: https://github.com/chenyu9512/wild-OCR.git'
echo 'git clone https://github.com/chenyu9512/wild-OCR.git'
echo 'cd wild-OCR && swift test'
echo "To publish updates: git add . && git commit -m 'Update wild-OCR' && git push"

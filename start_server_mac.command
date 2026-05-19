#!/bin/bash
set -e

cd "$(dirname "$0")"
PORT=5500

open "http://localhost:${PORT}/index.html"
python3 -m http.server "${PORT}"

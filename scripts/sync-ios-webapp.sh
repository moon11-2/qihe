#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "${IOS_DIFY:-}" == "1" ]]; then
  export VITE_DIFY_ENABLED=true
  export VITE_DIFY_PROXY_PATH="${IOS_DIFY_PROXY_URL:-http://127.0.0.1:8787/api/dify}"
fi

npm run build:h5

rm -rf ios/HetongBang/HetongBang/WebApp
mkdir -p ios/HetongBang/HetongBang/WebApp
cp -R dist/build/h5/. ios/HetongBang/HetongBang/WebApp/

echo "Synced H5 build to ios/HetongBang/HetongBang/WebApp"

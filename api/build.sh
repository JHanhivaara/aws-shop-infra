#!/usr/bin/env bash
# Package the API for Lambda (python3.13, arm64) into build/lambda.zip.
set -euo pipefail
cd "$(dirname "$0")"

rm -rf build && mkdir -p build/package
uv export --frozen --no-dev --no-emit-project --no-hashes --quiet -o build/requirements.txt
# Lambda runs Amazon Linux on Graviton: install arm64 Linux wheels, whatever machine builds this.
uv pip install --quiet --target build/package --python-version 3.13 \
  --python-platform aarch64-manylinux_2_28 --only-binary :all: -r build/requirements.txt
cp -r src/shop build/package/
find build/package -name __pycache__ -prune -exec rm -rf {} +

# Fixed timestamps and file order, so the same code always gives the same zip (and hash).
python3 - <<'EOF'
import pathlib, zipfile
root = pathlib.Path("build/package")
with zipfile.ZipFile("build/lambda.zip", "w", zipfile.ZIP_DEFLATED) as z:
    for path in sorted(p for p in root.rglob("*") if p.is_file()):
        info = zipfile.ZipInfo(str(path.relative_to(root)), date_time=(2020, 1, 1, 0, 0, 0))
        info.external_attr = 0o644 << 16
        z.writestr(info, path.read_bytes(), zipfile.ZIP_DEFLATED)
EOF
echo "build/lambda.zip: $(du -h build/lambda.zip | cut -f1)"

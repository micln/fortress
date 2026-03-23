#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEB_DIR="${ROOT_DIR}/build/web"
GODOT_BIN="${GODOT_BIN:-godot}"

echo "[1/4] 导出 Web 构建..."
"${GODOT_BIN}" --headless --path "${ROOT_DIR}" --export-release Web "${WEB_DIR}/index.html"

echo "[2/4] 校验关键产物..."
test -f "${WEB_DIR}/index.html"
test -f "${WEB_DIR}/index.js"
test -f "${WEB_DIR}/index.wasm"
test -f "${WEB_DIR}/index.pck"

echo "[3/4] 校验 index.js 语法..."
node --check "${WEB_DIR}/index.js"

echo "[4/4] 校验 HTML 启动片段..."
if ! rg -q "const engine = new Engine\\(GODOT_CONFIG\\);" "${WEB_DIR}/index.html"; then
	echo "缺少 Engine 初始化代码：${WEB_DIR}/index.html"
	exit 1
fi

echo "Web 冒烟检查通过。"

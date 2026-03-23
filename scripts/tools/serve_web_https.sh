#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEB_DIR="${ROOT_DIR}/build/web"
CERT_DIR="${ROOT_DIR}/.tmp/https"
CERT_FILE="${CERT_DIR}/localhost.pem"
KEY_FILE="${CERT_DIR}/localhost-key.pem"
PORT="${1:-18443}"

mkdir -p "${CERT_DIR}"

if [[ ! -f "${CERT_FILE}" || ! -f "${KEY_FILE}" ]]; then
	echo "生成本地 HTTPS 证书..."
	openssl req \
		-x509 \
		-newkey rsa:2048 \
		-sha256 \
		-nodes \
		-keyout "${KEY_FILE}" \
		-out "${CERT_FILE}" \
		-days 30 \
		-subj "/CN=localhost" \
		-addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
fi

echo "启动 HTTPS 静态服务: https://0.0.0.0:${PORT}/index.html"
echo "局域网访问时请用电脑 IP，并先在手机上信任该自签名证书。"

cd "${WEB_DIR}"
python3 -m http.server "${PORT}" \
	--bind 0.0.0.0 \
	--protocol HTTP/1.1 \
	--tls-cert "${CERT_FILE}" \
	--tls-key "${KEY_FILE}"

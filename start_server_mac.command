#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
START_PORT=5500
MAX_TRIES=50

PY_CMD=""
if command -v python3 >/dev/null 2>&1; then
  PY_CMD="python3"
elif command -v python >/dev/null 2>&1; then
  PY_CMD="python"
else
  echo "[ERROR] Python не найден. Установите Python 3 (например: brew install python)."
  read -r -p "Нажмите Enter для выхода..."
  exit 1
fi

echo "[INFO] Использую: ${PY_CMD}"

find_free_port() {
  local p
  for ((i=0; i<MAX_TRIES; i++)); do
    p=$((START_PORT + i))
    if ! lsof -iTCP:"${p}" -sTCP:LISTEN -n -P >/dev/null 2>&1; then
      echo "${p}"
      return 0
    fi
  done
  return 1
}

PORT="$(find_free_port)" || {
  echo "[ERROR] Не найден свободный порт в диапазоне ${START_PORT}..$((START_PORT + MAX_TRIES - 1))."
  read -r -p "Нажмите Enter для выхода..."
  exit 1
}

echo "[INFO] Запуск на порту ${PORT}"
open "http://localhost:${PORT}/index.html"

if ! "${PY_CMD}" -m http.server "${PORT}"; then
  echo "[ERROR] Не удалось запустить сервер на порту ${PORT}."
  read -r -p "Нажмите Enter для выхода..."
  exit 1
fi

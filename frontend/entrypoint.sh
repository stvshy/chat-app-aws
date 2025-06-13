#!/bin/sh
set -e

ROOT_DIR=/app/dist
TARGET_JS_FILES=$(find "$ROOT_DIR" -type f -name '*.js')
TARGET_HTML_FILES=$(find "$ROOT_DIR" -maxdepth 1 -type f -name '*.html')
ALL_TARGET_FILES="$TARGET_JS_FILES $TARGET_HTML_FILES"
DEFAULT_PORT=3000

echo "Uruchamianie entrypoint.sh..."

# Podmień tylko placeholder dla CHAT_API_URL
if [ -n "$VITE_CHAT_API_URL" ]; then
  echo "Wstrzykiwanie VITE_CHAT_API_URL..."
  for file_path in $ALL_TARGET_FILES; do
    if [ -f "$file_path" ]; then
      # Używamy `|` jako separatora dla sed
      sed -i "s|__VITE_CHAT_API_URL__|${VITE_CHAT_API_URL}|g" "$file_path"
    fi
  done
  echo "Zakończono wstrzykiwanie."
else
  echo "OSTRZEŻENIE: Zmienna VITE_CHAT_API_URL nie jest ustawiona!"
fi

echo "Uruchamianie serwera 'serve' na porcie ${PORT:-$DEFAULT_PORT}..."
exec serve -s dist -l "tcp://0.0.0.0:${PORT:-$DEFAULT_PORT}"
#!/bin/sh
set -e # Wyjdź natychmiast, jeśli polecenie zakończy się błędem

ROOT_DIR=/app/dist # Katalog, gdzie są zbudowane pliki
ASSETS_DIR="$ROOT_DIR/assets" # Często pliki JS są w podkatalogu assets
DEFAULT_PORT=3000

echo "Uruchamianie entrypoint.sh..."
echo "Katalog root dla plików statycznych: $ROOT_DIR"
echo "Katalog assets (dla plików JS): $ASSETS_DIR"

# Sprawdź, czy katalog assets istnieje, jeśli tam szukamy plików JS
if [ ! -d "$ASSETS_DIR" ]; then
  echo "OSTRZEŻENIE: Katalog assets '$ASSETS_DIR' nie został znaleziony! Przeszukam $ROOT_DIR dla plików JS."
  TARGET_JS_FILES=$(find "$ROOT_DIR" -type f -name '*.js')
else
  TARGET_JS_FILES=$(find "$ASSETS_DIR" -type f -name '*.js')
fi

# Możemy też chcieć przetworzyć index.html, jeśli tam też są placeholdery
TARGET_HTML_FILES=$(find "$ROOT_DIR" -maxdepth 1 -type f -name '*.html')

ALL_TARGET_FILES="$TARGET_JS_FILES $TARGET_HTML_FILES"

if [ -z "$ALL_TARGET_FILES" ]; then
  echo "OSTRZEŻENIE: Nie znaleziono plików .js ani .html do przetworzenia."
else
  echo "Pliki do przetworzenia: $ALL_TARGET_FILES"
fi

# Zmienne środowiskowe, które chcemy wstrzyknąć
# Elastic Beanstalk ustawi te zmienne na podstawie konfiguracji Terraform
echo "Dostępne zmienne środowiskowe VITE_:"
env | grep '^VITE_' || echo "Nie znaleziono zmiennych VITE_"

# Iteruj po wszystkich znalezionych plikach JS i HTML
for file_path in $ALL_TARGET_FILES; do
  if [ -f "$file_path" ]; then
    echo "Przetwarzanie pliku: $file_path"
    temp_file=$(mktemp)

    # Kopiujemy oryginalny plik do tymczasowego
    cp "$file_path" "$temp_file"

    # Zastąp placeholdery __NAZWA_ZMIENNEJ__ wartościami zmiennych środowiskowych
    # Używamy `printenv` aby bezpiecznie pobrać wartość zmiennej, nawet jeśli jest pusta.
    # Używamy innego separatora dla sed (np. `|`), aby uniknąć problemów, jeśli URL zawiera `/`.

    if printenv VITE_AUTH_API_URL > /dev/null; then
      echo "  Podmieniam __VITE_AUTH_API_URL__ na $(printenv VITE_AUTH_API_URL)"
      sed -i "s|__VITE_AUTH_API_URL__|$(printenv VITE_AUTH_API_URL)|g" "$temp_file"
    fi
    if printenv VITE_CHAT_API_URL > /dev/null; then
      echo "  Podmieniam __VITE_CHAT_API_URL__ na $(printenv VITE_CHAT_API_URL)"
      sed -i "s|__VITE_CHAT_API_URL__|$(printenv VITE_CHAT_API_URL)|g" "$temp_file"
    fi
    if printenv VITE_FILE_API_URL > /dev/null; then
      echo "  Podmieniam __VITE_FILE_API_URL__ na $(printenv VITE_FILE_API_URL)"
      sed -i "s|__VITE_FILE_API_URL__|$(printenv VITE_FILE_API_URL)|g" "$temp_file"
    fi
    if printenv VITE_NOTIFICATION_API_URL > /dev/null; then
      echo "  Podmieniam __VITE_NOTIFICATION_API_URL__ na $(printenv VITE_NOTIFICATION_API_URL)"
      sed -i "s|__VITE_NOTIFICATION_API_URL__|$(printenv VITE_NOTIFICATION_API_URL)|g" "$temp_file"
    fi
    # Możesz dodać więcej zmiennych w ten sam sposób

    # Zastąp oryginalny plik zmodyfikowanym
    cat "$temp_file" > "$file_path"
    rm "$temp_file"
    echo "Zakończono przetwarzanie (sed): $file_path"
  else
    echo "OSTRZEŻENIE: Ścieżka '$file_path' nie jest plikiem."
  fi
done

echo "Zakończono podstawianie zmiennych środowiskowych."

# Uruchom serwer 'serve'
# PORT jest zazwyczaj przekazywany przez Elastic Beanstalk
echo "Uruchamianie serwera 'serve' na porcie ${PORT:-$DEFAULT_PORT} z katalogu $ROOT_DIR..."
exec serve -s $ROOT_DIR -l ${PORT:-$DEFAULT_PORT}


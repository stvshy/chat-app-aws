#!/bin/bash
# 'set -e' to ważna komenda. Mówi ona skryptowi, żeby natychmiast się zatrzymał, jeśli jakakolwiek komenda zakończy się błędem.
# To zapobiega sytuacji, w której skrypt kontynuuje działanie mimo problemów, potencjalnie pogarszając sytuację.
set -e

# --- Konfiguracja i Zmienne ---
# W tej sekcji definiujemy wszystkie zmienne, których skrypt będzie używał.
# Trzymanie ich w jednym miejscu ułatwia zarządzanie i aktualizację.

# ID konta AWS.
AWS_ACCOUNT_ID="863340998271"
# Region AWS, w którym działamy. Musi być taki sam jak w Terraform.
AWS_REGION="us-east-1"
# Prefiks nazwy projektu, również musi być zgodny z Terraform.
PROJECT_NAME_PREFIX="projekt-chmury-v2"
# Tagi (wersje) obrazów Docker dla poszczególnych usług. Łatwo je tu zmienić przed wdrożeniem nowej wersji.
FRONTEND_TAG="v1.0.19"
AUTH_SERVICE_TAG="v1.0.19"
FILE_SERVICE_TAG="v1.0.17"
NOTIFICATION_SERVICE_TAG="v1.0.17"
# Wersje plików JAR dla funkcji Lambda.
LAMBDA_CHAT_HANDLERS_JAR_VERSION="1.0.0"
LAMBDA_DB_INITIALIZER_JAR_VERSION="1.0.0"
# Pełne nazwy plików JAR, które zostaną zbudowane przez Mavena.
LAMBDA_CHAT_HANDLERS_BUILT_JAR_NAME="chat-lambda-handlers-${LAMBDA_CHAT_HANDLERS_JAR_VERSION}.jar"
LAMBDA_DB_INITIALIZER_BUILT_JAR_NAME="db-initializer-lambda-${LAMBDA_DB_INITIALIZER_JAR_VERSION}.jar"
# Nazwy, pod jakimi pliki JAR będą zapisane w S3. Uproszczone dla łatwiejszego odwoływania się w Terraform.
LAMBDA_CHAT_HANDLERS_S3_KEY="chat-lambda-handlers.jar"
LAMBDA_DB_INITIALIZER_S3_KEY="db-initializer-lambda.jar"
# Pełny adres URL rejestru ECR, gdzie będziemy wysyłać obrazy Docker.
ECR_REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# --- Funkcje Pomocnicze ---
# Definiujemy funkcje, aby uniknąć powtarzania kodu.

# Funkcja do logowania się do rejestru ECR. Potrzebne, żeby Docker mógł wysyłać (push) obrazy.
login_to_ecr() {
  echo "INFO: Logowanie do AWS ECR..."
  # Używamy AWS CLI do pobrania tymczasowego hasła i przekazujemy je do komendy docker login.
  aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY_URL}"
  echo "INFO: Logowanie do ECR zakończone pomyślnie."
}

# Funkcja do budowania serwisów Java (Maven) i tworzenia ich obrazów Docker.
build_java_service_and_docker_image() {
  local service_name="$1"   # Nazwa serwisu, np. "auth-service"
  local service_path="$2"   # Ścieżka do katalogu serwisu
  local image_tag="$3"      # Tag obrazu Docker
  local full_image_name="${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/${service_name}:${image_tag}"

  echo "--- Budowanie serwisu Java: ${service_name} ---"
  # Sprawdzamy system operacyjny, żeby użyć odpowiedniej komendy Mavena (.cmd dla Windows, .sh dla reszty).
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    (cd "${service_path}" && ./mvnw.cmd clean package -DskipTests)
  else
    (cd "${service_path}" && ./mvnw clean package -DskipTests)
  fi

  echo "--- Budowanie obrazu Docker dla ${service_name} ---"
  # Budujemy obraz Docker na podstawie pliku Dockerfile w katalogu serwisu.
  docker build -t "${full_image_name}" "${service_path}"
}

# Funkcja do budowania obrazu Docker dla frontendu.
build_frontend_docker_image() {
  local service_name="frontend"
  local service_path="./frontend"
  local image_tag="$1"
  local full_image_name="${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/${service_name}:${image_tag}"

  echo "--- Budowanie obrazu Docker dla ${service_name} ---"
  docker build -t "${full_image_name}" "${service_path}"
}

# Funkcja do budowania paczek JAR dla funkcji Lambda za pomocą Mavena.
build_lambda_package() {
  local lambda_module_path="$1" # Ścieżka do modułu Mavena z kodem Lambdy
  echo "--- Budowanie paczki JAR dla ${lambda_module_path} ---"
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    (cd "${lambda_module_path}" && ./mvnw.cmd clean package)
  else
    (cd "${lambda_module_path}" && ./mvnw clean package)
  fi
}

# ==============================================================================
# --- Główny Skrypt (Logika Wdrożenia) ---
# ==============================================================================
# Tutaj zaczyna się właściwe działanie skryptu, krok po kroku.

# KROK 1: Budowanie wszystkich artefaktów LOKALNIE
# Najpierw budujemy wszystko na naszej maszynie. Jeśli cokolwiek się nie uda, skrypt zatrzyma się tutaj.
echo ">>> KROK 1: Budowanie wszystkich artefaktów lokalnie..."
build_frontend_docker_image "${FRONTEND_TAG}"
build_java_service_and_docker_image "auth-service" "./auth-service" "${AUTH_SERVICE_TAG}"
build_java_service_and_docker_image "file-service" "./file-service" "${FILE_SERVICE_TAG}"
build_java_service_and_docker_image "notification-service" "./notification-service" "${NOTIFICATION_SERVICE_TAG}"
build_lambda_package "./chat-lambda-handlers"
build_lambda_package "./db-initializer-lambda"
echo ">>> Budowanie artefaktów zakończone."
echo "------------------------------------------------------------------"

# KROK 2: Wdrożenie PEŁNEJ infrastruktury za pomocą Terraform.
# Teraz uruchamiamy Terraform, który stworzy całą infrastrukturę w AWS.
# WAŻNE: Na tym etapie Lambdy są tworzone z "pustym" kodem (dummy zip), a usługi ECS z definicjami zadań, które wskazują na tagi obrazów. Obrazy jeszcze nie istnieją w ECR.
echo ">>> KROK 2: Wdrażanie/Aktualizacja pełnej infrastruktury Terraform..."
(
  # Przechodzimy do katalogu terraform.
  cd ./terraform || exit 1
  # Inicjalizujemy Terraform, pobierając potrzebne wtyczki.
  terraform init -upgrade
  # Uruchamiamy 'apply', aby stworzyć/zaktualizować zasoby. '-auto-approve' pomija pytanie "czy na pewno?".
  # Przekazujemy tagi obrazów i nazwy plików JAR jako zmienne (-var), aby Terraform wiedział, jakich wersji użyć.
  terraform apply -auto-approve \
    -var="frontend_image_tag=${FRONTEND_TAG}" \
    -var="auth_service_image_tag=${AUTH_SERVICE_TAG}" \
    -var="file_service_image_tag=${FILE_SERVICE_TAG}" \
    -var="notification_service_image_tag=${NOTIFICATION_SERVICE_TAG}" \
    -var="lambda_chat_handlers_jar_key=${LAMBDA_CHAT_HANDLERS_S3_KEY}" \
    -var="db_initializer_jar_key=${LAMBDA_DB_INITIALIZER_S3_KEY}"
)
echo ">>> Wdrożenie Terraform zakończone. Powłoki Lambd i repozytoria ECR istnieją."
echo "------------------------------------------------------------------"

# KROK 3: Wypchnij prawdziwy kod i obrazy do AWS
# Skoro Terraform stworzył nam repozytoria ECR i bucket S3, teraz możemy je wypełnić naszymi zbudowanymi artefaktami.
echo ">>> KROK 3: Wypychanie artefaktów do AWS..."
# Logujemy się do ECR.
login_to_ecr

echo "INFO: Wypychanie obrazów Docker do ECR..."
# Wysyłamy każdy zbudowany obraz Docker do odpowiedniego repozytorium w ECR.
docker push "${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/frontend:${FRONTEND_TAG}"
docker push "${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/auth-service:${AUTH_SERVICE_TAG}"
docker push "${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/file-service:${FILE_SERVICE_TAG}"
docker push "${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/notification-service:${NOTIFICATION_SERVICE_TAG}"
echo "INFO: Obrazy Docker wypchnięte."

echo "INFO: Wypychanie prawdziwego kodu Lambda do S3..."
# Pobieramy nazwę bucketa na kod Lambd z outputów Terraform.
LAMBDA_BUCKET_NAME=$(cd ./terraform && terraform output -raw s3_lambda_code_bucket_name)
# Kopiujemy zbudowane pliki JAR do tego bucketa w S3.
aws s3 cp "./chat-lambda-handlers/target/${LAMBDA_CHAT_HANDLERS_BUILT_JAR_NAME}" "s3://${LAMBDA_BUCKET_NAME}/${LAMBDA_CHAT_HANDLERS_S3_KEY}"
aws s3 cp "./db-initializer-lambda/target/${LAMBDA_DB_INITIALIZER_BUILT_JAR_NAME}" "s3://${LAMBDA_BUCKET_NAME}/${LAMBDA_DB_INITIALIZER_S3_KEY}"
echo "INFO: Prawdziwy kod Lambda jest już w S3."
echo "------------------------------------------------------------------"

# KROK 4: Zaktualizuj usługi, aby pobrały nowy kod/obrazy
# To kluczowy krok. Mamy już infrastrukturę i artefakty w AWS. Teraz musimy "powiedzieć" usługom, żeby z nich skorzystały.
echo ">>> KROK 4: Aktualizacja usług w AWS do najnowszej wersji..."

echo "INFO: Aktualizacja kodu funkcji Lambda z S3..."
# Pobieramy nazwy funkcji Lambda z outputów Terraform.
SEND_LAMBDA_NAME=$(cd ./terraform && terraform output -raw send_message_lambda_name)
GET_SENT_LAMBDA_NAME=$(cd ./terraform && terraform output -raw get_sent_messages_lambda_name)
GET_RECEIVED_LAMBDA_NAME=$(cd ./terraform && terraform output -raw get_received_messages_lambda_name)
MARK_READ_LAMBDA_NAME=$(cd ./terraform && terraform output -raw mark_message_as_read_lambda_name)
DB_INIT_LAMBDA_NAME=$(cd ./terraform && terraform output -raw db_initializer_lambda_function_name)

# Aktualizujemy kod każdej funkcji Lambda, wskazując na prawdziwy plik .jar w S3.
# To zamienia "zaślepkę" na działający kod. '> /dev/null' ukrywa szczegółowe wyjście komendy.
aws lambda update-function-code --function-name "${SEND_LAMBDA_NAME}" --s3-bucket "${LAMBDA_BUCKET_NAME}" --s3-key "${LAMBDA_CHAT_HANDLERS_S3_KEY}" > /dev/null
aws lambda update-function-code --function-name "${GET_SENT_LAMBDA_NAME}" --s3-bucket "${LAMBDA_BUCKET_NAME}" --s3-key "${LAMBDA_CHAT_HANDLERS_S3_KEY}" > /dev/null
aws lambda update-function-code --function-name "${GET_RECEIVED_LAMBDA_NAME}" --s3-bucket "${LAMBDA_BUCKET_NAME}" --s3-key "${LAMBDA_CHAT_HANDLERS_S3_KEY}" > /dev/null
aws lambda update-function-code --function-name "${MARK_READ_LAMBDA_NAME}" --s3-bucket "${LAMBDA_BUCKET_NAME}" --s3-key "${LAMBDA_CHAT_HANDLERS_S3_KEY}" > /dev/null
aws lambda update-function-code --function-name "${DB_INIT_LAMBDA_NAME}" --s3-bucket "${LAMBDA_BUCKET_NAME}" --s3-key "${LAMBDA_DB_INITIALIZER_S3_KEY}" > /dev/null
echo "INFO: Funkcje Lambda zaktualizowane."

echo "INFO: Wywoływanie funkcji Lambda inicjalizującej schemat bazy danych..."
# Po zaktualizowaniu jej kodu, wywołujemy ją jednorazowo, żeby stworzyła tabele w bazie danych RDS.
aws lambda invoke --function-name "${DB_INIT_LAMBDA_NAME}" --payload "{}" --cli-binary-format raw-in-base64-out /dev/null
echo "INFO: Funkcja inicjalizująca schemat bazy danych wywołana."

echo "INFO: Wymuszanie nowego wdrożenia dla usług ECS..."
# Pobieramy nazwę klastra ECS z outputu Terraform.
CLUSTER_NAME=$(cd ./terraform && terraform output -raw ecs_cluster_name)

echo "DEBUG: Sprawdzanie tożsamości AWS, której użyje skrypt..."
# To polecenie jest dobre do debugowania, pokazuje, z jakimi uprawnieniami (rolą/użytkownikiem) działa skrypt.
aws sts get-caller-identity

echo "INFO: Pobieranie nazw usług ECS do aktualizacji..."
# Pobieramy listę usług ECS z outputu Terraform, a następnie w pętli aktualizujemy każdą z nich.
(cd ./terraform && terraform output -json ecs_service_names) | jq -r '.[]' | tr -d '\r' | while IFS= read -r service_name; do
  if [ -n "$service_name" ]; then
    echo "  -> Aktualizacja usługi: [${service_name}]"
    # To jest "kopniak" dla usługi. Mówi jej: "Hej, zrób sobie restart i pobierz najnowszy obraz Docker z ECR".
    # ECS zobaczy, że definicja zadania wskazuje na tag np. "v1.0.19", pobierze ten obraz i uruchomi nowe kontenery.
    aws ecs update-service --cluster "${CLUSTER_NAME}" --service "${service_name}" --force-new-deployment --region "${AWS_REGION}" > /dev/null
  fi
done
echo "INFO: Usługi ECS zaktualizowane."
echo ">>> Aktualizacja usług zakończona."
echo "------------------------------------------------------------------"

# KROK 5: Wyświetl outputy
# Na sam koniec, wyświetlamy wszystkie ważne informacje z Terraform, takie jak adresy URL, ID zasobów itp.
echo ">>> KROK 5: Wyniki Terraform (Outputs)..."
(
  cd ./terraform || exit 1
  terraform output
)

echo ">>> Skrypt wdrożeniowy zakończony pomyślnie."
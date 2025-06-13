#!/bin/bash
set -e

# --- Konfiguracja i Funkcje (bez zmian) ---
AWS_ACCOUNT_ID="044902896603"
AWS_REGION="us-east-1"
PROJECT_NAME_PREFIX="projekt-chmury-v2"
FRONTEND_TAG="v1.0.19"
AUTH_SERVICE_TAG="v1.0.19"
FILE_SERVICE_TAG="v1.0.17"
NOTIFICATION_SERVICE_TAG="v1.0.17"
LAMBDA_CHAT_HANDLERS_JAR_VERSION="1.0.0"
LAMBDA_DB_INITIALIZER_JAR_VERSION="1.0.0"
LAMBDA_CHAT_HANDLERS_BUILT_JAR_NAME="chat-lambda-handlers-${LAMBDA_CHAT_HANDLERS_JAR_VERSION}.jar"
LAMBDA_DB_INITIALIZER_BUILT_JAR_NAME="db-initializer-lambda-${LAMBDA_DB_INITIALIZER_JAR_VERSION}.jar"
LAMBDA_CHAT_HANDLERS_S3_KEY="chat-lambda-handlers.jar"
LAMBDA_DB_INITIALIZER_S3_KEY="db-initializer-lambda.jar"
ECR_REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

login_to_ecr() {
  echo "INFO: Logowanie do AWS ECR..."
  aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY_URL}"
  echo "INFO: Logowanie do ECR zakończone pomyślnie."
}
build_java_service_and_docker_image() {
  local service_name="$1"
  local service_path="$2"
  local image_tag="$3"
  local full_image_name="${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/${service_name}:${image_tag}"
  echo "--- Budowanie serwisu Java: ${service_name} ---"
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    (cd "${service_path}" && ./mvnw.cmd clean package -DskipTests)
  else
    (cd "${service_path}" && ./mvnw clean package -DskipTests)
  fi
  echo "--- Budowanie obrazu Docker dla ${service_name} ---"
  docker build -t "${full_image_name}" "${service_path}"
}
build_frontend_docker_image() {
  local service_name="frontend"
  local service_path="./frontend"
  local image_tag="$1"
  local full_image_name="${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/${service_name}:${image_tag}"
  echo "--- Budowanie obrazu Docker dla ${service_name} ---"
  docker build -t "${full_image_name}" "${service_path}"
}
build_lambda_package() {
  local lambda_module_path="$1"
  echo "--- Budowanie paczki JAR dla ${lambda_module_path} ---"
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    (cd "${lambda_module_path}" && ./mvnw.cmd clean package)
  else
    (cd "${lambda_module_path}" && ./mvnw clean package)
  fi
}
# ==============================================================================
# --- Główny Skrypt (LOGIKA ZGODNA Z ARTYKUŁEM) ---
# ==============================================================================

# KROK 1: Budowanie wszystkich artefaktów LOKALNIE
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
# Terraform stworzy "puste powłoki" Lambd używając dummy ZIP-a.
echo ">>> KROK 2: Wdrażanie/Aktualizacja pełnej infrastruktury Terraform..."
(
  cd ./terraform || exit 1
  terraform init -upgrade
  terraform apply -auto-approve \
    -var="frontend_image_tag=${FRONTEND_TAG}" \
    -var="auth_service_image_tag=${AUTH_SERVICE_TAG}" \
    -var="file_service_image_tag=${FILE_SERVICE_TAG}" \
    -var="notification_service_image_tag=${NOTIFICATION_SERVICE_TAG}" \
    -var="lambda_chat_handlers_jar_key=${LAMBDA_CHAT_HANDLERS_S3_KEY}" \
    -var="db_initializer_jar_key=${LAMBDA_DB_INITIALIZER_S3_KEY}"
)
echo ">>> Wdrożenie Terraform zakończone. Powłoki Lambd istnieją."
echo "------------------------------------------------------------------"

# KROK 3: Wypchnij prawdziwy kod i obrazy do AWS
echo ">>> KROK 3: Wypychanie artefaktów do AWS..."
login_to_ecr

echo "INFO: Wypychanie obrazów Docker do ECR..."
docker push "${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/frontend:${FRONTEND_TAG}"
docker push "${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/auth-service:${AUTH_SERVICE_TAG}"
docker push "${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/file-service:${FILE_SERVICE_TAG}"
docker push "${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/notification-service:${NOTIFICATION_SERVICE_TAG}"
echo "INFO: Obrazy Docker wypchnięte."

echo "INFO: Wypychanie prawdziwego kodu Lambda do S3..."
LAMBDA_BUCKET_NAME=$(cd ./terraform && terraform output -raw s3_lambda_code_bucket_name)
aws s3 cp "./chat-lambda-handlers/target/${LAMBDA_CHAT_HANDLERS_BUILT_JAR_NAME}" "s3://${LAMBDA_BUCKET_NAME}/${LAMBDA_CHAT_HANDLERS_S3_KEY}"
aws s3 cp "./db-initializer-lambda/target/${LAMBDA_DB_INITIALIZER_BUILT_JAR_NAME}" "s3://${LAMBDA_BUCKET_NAME}/${LAMBDA_DB_INITIALIZER_S3_KEY}"
echo "INFO: Prawdziwy kod Lambda jest już w S3."
echo "------------------------------------------------------------------"

# KROK 4: Zaktualizuj usługi, aby pobrały nowy kod/obrazy
echo ">>> KROK 4: Aktualizacja usług w AWS do najnowszej wersji..."

echo "INFO: Aktualizacja kodu funkcji Lambda z S3..."
# Pobieramy nazwy funkcji Lambda z outputów Terraform
SEND_LAMBDA_NAME=$(cd ./terraform && terraform output -raw send_message_lambda_name)
GET_SENT_LAMBDA_NAME=$(cd ./terraform && terraform output -raw get_sent_messages_lambda_name)
GET_RECEIVED_LAMBDA_NAME=$(cd ./terraform && terraform output -raw get_received_messages_lambda_name)
MARK_READ_LAMBDA_NAME=$(cd ./terraform && terraform output -raw mark_message_as_read_lambda_name)
DB_INIT_LAMBDA_NAME=$(cd ./terraform && terraform output -raw db_initializer_lambda_function_name)

# Aktualizujemy kod każdej Lambdy, wskazując na prawdziwy plik .jar w S3
aws lambda update-function-code --function-name "${SEND_LAMBDA_NAME}" --s3-bucket "${LAMBDA_BUCKET_NAME}" --s3-key "${LAMBDA_CHAT_HANDLERS_S3_KEY}" > /dev/null
aws lambda update-function-code --function-name "${GET_SENT_LAMBDA_NAME}" --s3-bucket "${LAMBDA_BUCKET_NAME}" --s3-key "${LAMBDA_CHAT_HANDLERS_S3_KEY}" > /dev/null
aws lambda update-function-code --function-name "${GET_RECEIVED_LAMBDA_NAME}" --s3-bucket "${LAMBDA_BUCKET_NAME}" --s3-key "${LAMBDA_CHAT_HANDLERS_S3_KEY}" > /dev/null
aws lambda update-function-code --function-name "${MARK_READ_LAMBDA_NAME}" --s3-bucket "${LAMBDA_BUCKET_NAME}" --s3-key "${LAMBDA_CHAT_HANDLERS_S3_KEY}" > /dev/null
aws lambda update-function-code --function-name "${DB_INIT_LAMBDA_NAME}" --s3-bucket "${LAMBDA_BUCKET_NAME}" --s3-key "${LAMBDA_DB_INITIALIZER_S3_KEY}" > /dev/null
echo "INFO: Funkcje Lambda zaktualizowane."
echo "INFO: Wywoływanie funkcji Lambda inicjalizującej schemat bazy danych..."
aws lambda invoke --function-name "${DB_INIT_LAMBDA_NAME}" --payload "{}" --cli-binary-format raw-in-base64-out /dev/null # Przekieruj wyjście do /dev/null
echo "INFO: Funkcja inicjalizująca schemat bazy danych wywołana."
echo "INFO: Wymuszanie nowego wdrożenia dla usług ECS..."
CLUSTER_NAME=$(cd ./terraform && terraform output -raw ecs_cluster_name)

# --- DODAJ TĘ LINIĘ DO DEBUGOWANIA ---
echo "DEBUG: Sprawdzanie tożsamości AWS, której użyje skrypt..."
aws sts get-caller-identity
# --- KONIEC LINII DO DEBUGOWANIA ---

echo "INFO: Pobieranie nazw usług ECS do aktualizacji..."
(cd ./terraform && terraform output -json ecs_service_names) | jq -r '.[]' | tr -d '\r' | while IFS= read -r service_name; do
  if [ -n "$service_name" ]; then
    echo "  -> Aktualizacja usługi: [${service_name}]" # Dodaję nawiasy kwadratowe, żeby zobaczyć ewentualne białe znaki
    aws ecs update-service --cluster "${CLUSTER_NAME}" --service "${service_name}" --force-new-deployment --region "${AWS_REGION}" > /dev/null
  fi
done
echo "INFO: Usługi ECS zaktualizowane."
echo ">>> Aktualizacja usług zakończona."
echo "------------------------------------------------------------------"

# KROK 5: Wyświetl outputy
echo ">>> KROK 5: Wyniki Terraform (Outputs)..."
(
  cd ./terraform || exit 1
  terraform output
)

echo ">>> Skrypt wdrożeniowy zakończony pomyślnie."

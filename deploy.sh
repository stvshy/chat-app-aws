#!/bin/bash

set -e # Jeśli jakakolwiek komenda w skrypcie zakończy się błędem (zwróci status inny niż 0),
       # cały skrypt natychmiast się zakończy. To pomaga szybko wykryć problemy.

# --- Konfiguracja ---
AWS_ACCOUNT_ID="044902896603"
AWS_REGION="us-east-1"
PROJECT_NAME_PREFIX="projekt-chmury-v2"

# Tagi obrazów Docker i wersja JAR dla Lambda
FRONTEND_TAG="v1.0.17"
AUTH_SERVICE_TAG="v1.0.19"
FILE_SERVICE_TAG="v1.0.17"
NOTIFICATION_SERVICE_TAG="v1.0.17"

LAMBDA_CHAT_HANDLERS_JAR_VERSION="1.0.0"
LAMBDA_CHAT_HANDLERS_BUILT_JAR_NAME="chat-lambda-handlers-${LAMBDA_CHAT_HANDLERS_JAR_VERSION}.jar"
LAMBDA_CHAT_HANDLERS_S3_KEY="chat-lambda-handlers.jar"

ECR_REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# --- Funkcje Pomocnicze ---
login_to_ecr() {
  echo "INFO: Logowanie do AWS ECR..."
  aws ecr get-login-password --region "${AWS_REGION}" | \
  docker login --username AWS --password-stdin "${ECR_REGISTRY_URL}"
  echo "INFO: Logowanie do ECR zakończone pomyślnie."
}

build_java_service_and_docker_image() {
  local service_name="$1"
  local service_path="$2"
  local image_tag="$3"
  local ecr_repo_name_suffix="$1"
  local full_image_name="${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/${ecr_repo_name_suffix}:${image_tag}"

  echo "------------------------------------------------------------------"
  echo "INFO: Budowanie serwisu Java: ${service_name} w ${service_path}"
  echo "------------------------------------------------------------------"
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    (cd "${service_path}" && ./mvnw.cmd clean package -DskipTests)
  else
    (cd "${service_path}" && ./mvnw clean package -DskipTests)
  fi

  echo "------------------------------------------------------------------"
  echo "INFO: Budowanie obrazu Docker dla ${service_name} z tagiem ${image_tag}"
  echo "INFO: Nazwa obrazu: ${full_image_name}"
  echo "------------------------------------------------------------------"
  docker build -t "${full_image_name}" "${service_path}"

  login_to_ecr

  echo "------------------------------------------------------------------"
  echo "INFO: Wypychanie obrazu ${service_name} do ECR: ${full_image_name}"
  echo "------------------------------------------------------------------"
  docker push "${full_image_name}"
  echo "INFO: Pomyślnie wypchnięto ${service_name}."
}

build_frontend_docker_image() {
  local service_name="frontend"
  local service_path="./frontend"
  local image_tag="$1"
  local ecr_repo_name_suffix="frontend"
  local full_image_name="${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/${ecr_repo_name_suffix}:${image_tag}"

  echo "------------------------------------------------------------------"
  echo "INFO: Budowanie obrazu Docker dla ${service_name} z tagiem ${image_tag}"
  echo "INFO: Nazwa obrazu: ${full_image_name}"
  echo "------------------------------------------------------------------"
  docker build -t "${full_image_name}" "${service_path}"

  login_to_ecr

  echo "------------------------------------------------------------------"
  echo "INFO: Wypychanie obrazu ${service_name} do ECR: ${full_image_name}"
  echo "------------------------------------------------------------------"
  docker push "${full_image_name}"
  echo "INFO: Pomyślnie wypchnięto ${service_name}."
}

build_lambda_package() {
  local lambda_module_path="./chat-lambda-handlers"
  echo "------------------------------------------------------------------"
  echo "INFO: Budowanie paczki JAR dla chat-lambda-handlers w ${lambda_module_path}"
  echo "------------------------------------------------------------------"
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    (cd "${lambda_module_path}" && ./mvnw.cmd clean package)
  else
    (cd "${lambda_module_path}" && ./mvnw clean package)
  fi
  echo "INFO: Pomyślnie zbudowano paczkę chat-lambda-handlers."
}

upload_lambda_package_to_s3() {
  local lambda_jar_path="./chat-lambda-handlers/target/${LAMBDA_CHAT_HANDLERS_BUILT_JAR_NAME}"
  local s3_bucket_name
  local s3_key="${LAMBDA_CHAT_HANDLERS_S3_KEY}"

  echo "------------------------------------------------------------------"
  echo "INFO: Wgrywanie paczki Lambda ${lambda_jar_path} do S3..."
  echo "------------------------------------------------------------------"

  s3_bucket_name=$(cd ./terraform && terraform output -raw s3_lambda_code_bucket_name)

  if [ -z "$s3_bucket_name" ]; then
    echo "BŁĄD: Nie można pobrać nazwy bucketu S3 dla kodu Lambda (s3_lambda_code_bucket_name)."
    echo "Upewnij się, że Krok 1 (terraform apply dla s3_lambda_code_bucket) został wykonany."
    exit 1
  fi
  echo "INFO: Bucket S3 dla kodu Lambda: s3://${s3_bucket_name}/${s3_key}"

  if [ ! -f "$lambda_jar_path" ]; then
    echo "BŁĄD: Plik JAR funkcji Lambda nie został znaleziony: ${lambda_jar_path}"
    echo "Upewnij się, że budowanie paczki Lambda (build_lambda_package) zakończyło się pomyślnie."
    exit 1
  fi

  aws s3 cp "${lambda_jar_path}" "s3://${s3_bucket_name}/${s3_key}"
  echo "INFO: Pomyślnie wgrano paczkę Lambda do s3://${s3_bucket_name}/${s3_key}"
}


# --- Główny Skrypt ---

# KROK 1: Stwórz/zapewnij istnienie repozytoriów ECR i bucketu S3 dla Lambd
echo ">>> KROK 1: Tworzenie/zapewnianie istnienia repozytoriów ECR i bucketu S3 dla Lambd..."
(
  cd ./terraform || { echo "BŁĄD: Nie można przejść do katalogu ./terraform"; exit 1; }
  terraform init -upgrade
  echo "INFO: Stosowanie konfiguracji Terraform dla repozytoriów ECR i bucketu S3 Lambda..."
  terraform apply -auto-approve \
    -target=aws_ecr_repository.frontend_repo \
    -target=aws_ecr_repository.auth_service_repo \
    -target=aws_ecr_repository.file_service_repo \
    -target=aws_ecr_repository.notification_service_repo \
    -target=aws_s3_bucket.lambda_code_bucket \
    -target=random_string.suffix
)
echo ">>> Repozytoria ECR i bucket S3 dla Lambd powinny teraz istnieć."
echo "------------------------------------------------------------------"

# KROK 2: Zbuduj obrazy Docker i paczkę Lambda
echo ">>> KROK 2: Budowanie artefaktów..."

build_frontend_docker_image "${FRONTEND_TAG}"
build_java_service_and_docker_image "auth-service" "./auth-service" "${AUTH_SERVICE_TAG}"
build_java_service_and_docker_image "file-service" "./file-service" "${FILE_SERVICE_TAG}"
build_java_service_and_docker_image "notification-service" "./notification-service" "${NOTIFICATION_SERVICE_TAG}"

build_lambda_package

echo ">>> Wszystkie obrazy Docker i paczka Lambda zostały zbudowane."
echo "------------------------------------------------------------------"

# KROK 3: Wypchnij obrazy Docker do ECR i paczkę Lambda do S3
echo ">>> KROK 3: Wypychanie artefaktów do AWS..."

upload_lambda_package_to_s3

echo ">>> Wszystkie artefakty zostały wypchnięte."
echo "------------------------------------------------------------------"


# KROK 4: Uruchom pełne terraform apply dla reszty infrastruktury
echo ">>> KROK 4: Wdrażanie/Aktualizacja pełnej infrastruktury Terraform..."
(
  cd ./terraform || { echo "BŁĄD: Nie można przejść do katalogu ./terraform"; exit 1; }

  echo "INFO: Stosowanie pełnej konfiguracji Terraform..."
  # Upewnij się, że nie ma spacji po znakach '\' i że ostatnia linia -var nie ma '\'
  terraform apply -auto-approve \
    -var="frontend_image_tag=${FRONTEND_TAG}" \
    -var="auth_service_image_tag=${AUTH_SERVICE_TAG}" \
    -var="file_service_image_tag=${FILE_SERVICE_TAG}" \
    -var="notification_service_image_tag=${NOTIFICATION_SERVICE_TAG}" \
    -var="lambda_chat_handlers_jar_key=${LAMBDA_CHAT_HANDLERS_S3_KEY}"

  TF_APPLY_EXIT_CODE=$?
  echo "DEBUG: terraform apply w Kroku 4 zakończone z kodem: ${TF_APPLY_EXIT_CODE}"
  if [ ${TF_APPLY_EXIT_CODE} -ne 0 ]; then
    echo "BŁĄD: terraform apply w Kroku 4 nie powiodło się z kodem ${TF_APPLY_EXIT_CODE}!"
    exit ${TF_APPLY_EXIT_CODE}
  fi
)
echo ">>> Wdrożenie Terraform zakończone."
echo "------------------------------------------------------------------"

# KROK 5: Wyświetl outputy Terraform
echo ">>> KROK 5: Wyniki Terraform (Outputs)..."
(
  cd ./terraform || { echo "BŁĄD: Nie można przejść do katalogu ./terraform"; exit 1; }
  terraform output

  frontend_url=$(terraform output -raw frontend_url)
  api_gateway_url=$(terraform output -raw api_gateway_chat_invoke_url)
  echo "------------------------------------------------------------------"
  echo "Frontend URL: $frontend_url"
  echo "Chat API Gateway URL: $api_gateway_url"
  echo "------------------------------------------------------------------"
)

echo ">>> Skrypt wdrożeniowy zakończony pomyślnie."
echo "------------------------------------------------------------------"
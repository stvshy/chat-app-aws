#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Konfiguracja ---
# Zaktualizuj te wartości, jeśli są inne!
AWS_ACCOUNT_ID="044902896603"
AWS_REGION="us-east-1"
PROJECT_NAME_PREFIX="projekt-chmury-v2" # Zgodnie z terraform/main.tf locals.project_name_prefix

# ZDEFINIUJ TAGI OBRAZÓW DLA TEGO WDROŻENIA
# Możesz je zmieniać przy każdym nowym wdrożeniu, aby odróżnić wersje.
FRONTEND_TAG="v1.0.17"                 # Użyj tagu, który ostatnio przygotowywaliśmy
AUTH_SERVICE_TAG="v1.0.19"             # Przykładowy tag, zmień wg potrzeb
CHAT_SERVICE_TAG="v1.0.17"             # Przykładowy tag, zmień wg potrzeb
FILE_SERVICE_TAG="v1.0.17"             # Przykładowy tag, zmień wg potrzeb
NOTIFICATION_SERVICE_TAG="v1.0.17"     # Przykładowy tag, zmień wg potrzeb

ECR_REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# --- Funkcje Pomocnicze ---
login_to_ecr() {
  echo "INFO: Logowanie do AWS ECR..."
  aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY_URL}"
  echo "INFO: Logowanie do ECR zakończone pomyślnie."
}

# Funkcja do budowania serwisu Java/Maven i jego obrazu Docker
build_java_service_and_docker_image() {
  local service_name="$1"
  local service_path="$2" # Ścieżka do katalogu serwisu, np. "./auth-service"
  local image_tag="$3"
  local ecr_repo_name_suffix="$1" # Domyślnie nazwa serwisu jako suffix repozytorium ECR

  local full_image_name="${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/${ecr_repo_name_suffix}:${image_tag}"

  echo "------------------------------------------------------------------"
  echo "INFO: Budowanie serwisu Java: ${service_name} w ${service_path}"
  echo "------------------------------------------------------------------"
  (cd "${service_path}" && ./mvnw clean package -DskipTests)

  echo "------------------------------------------------------------------"
  echo "INFO: Budowanie obrazu Docker dla ${service_name} z tagiem ${image_tag}"
  echo "INFO: Nazwa obrazu: ${full_image_name}"
  echo "------------------------------------------------------------------"
  docker build -t "${full_image_name}" "${service_path}"

  # Logowanie tuż przed pushem
  login_to_ecr

  echo "------------------------------------------------------------------"
  echo "INFO: Wypychanie obrazu ${service_name} do ECR: ${full_image_name}"
  echo "------------------------------------------------------------------"
  docker push "${full_image_name}"
  echo "INFO: Pomyślnie wypchnięto ${service_name}."
}

# Funkcja do budowania obrazu Docker dla frontendu (Node.js)
build_frontend_docker_image() {
  local service_name="frontend"
  local service_path="./frontend" # Ścieżka do katalogu frontendu
  local image_tag="$1"
  local ecr_repo_name_suffix="frontend"

  local full_image_name="${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/${ecr_repo_name_suffix}:${image_tag}"

  echo "------------------------------------------------------------------"
  echo "INFO: Budowanie obrazu Docker dla ${service_name} z tagiem ${image_tag}"
  echo "INFO: Nazwa obrazu: ${full_image_name}"
  echo "------------------------------------------------------------------"
  docker build -t "${full_image_name}" "${service_path}"

  # Logowanie tuż przed pushem
  login_to_ecr

  echo "------------------------------------------------------------------"
  echo "INFO: Wypychanie obrazu ${service_name} do ECR: ${full_image_name}"
  echo "------------------------------------------------------------------"
  docker push "${full_image_name}"
  echo "INFO: Pomyślnie wypchnięto ${service_name}."
}


# --- Główny Skrypt ---

# KROK 1: Stwórz/zapewnij istnienie repozytoriów ECR (i niezbędnych zależności)
echo ">>> KROK 1: Tworzenie/zapewnianie istnienia repozytoriów ECR..."
(
  cd ./terraform || { echo "BŁĄD: Nie można przejść do katalogu ./terraform"; exit 1; }
  echo "INFO: Inicjalizacja Terraform (jeśli potrzebna)..."
  terraform init -upgrade # -upgrade może być przydatne

  echo "INFO: Stosowanie konfiguracji Terraform tylko dla repozytoriów ECR..."
  # Używamy -auto-approve dla pełnej automatyzacji
  # random_string.suffix jest potrzebny, bo nazwy repozytoriów od niego zależą
  terraform apply -auto-approve \
    -target=aws_ecr_repository.frontend_repo \
    -target=aws_ecr_repository.auth_service_repo \
    -target=aws_ecr_repository.chat_service_repo \
    -target=aws_ecr_repository.file_service_repo \
    -target=aws_ecr_repository.notification_service_repo \
    -target=random_string.suffix # Upewnij się, że ten zasób jest tworzony, jeśli nazwy repo od niego zależą
)
echo ">>> Repozytoria ECR powinny teraz istnieć."
echo "------------------------------------------------------------------"


# KROK 2: Zbuduj i wypchnij wszystkie obrazy Docker
echo ">>> KROK 2: Budowanie i wypychanie obrazów Docker..."

build_frontend_docker_image "${FRONTEND_TAG}"
build_java_service_and_docker_image "auth-service" "./auth-service" "${AUTH_SERVICE_TAG}"
build_java_service_and_docker_image "chat-service" "./chat-service" "${CHAT_SERVICE_TAG}"
build_java_service_and_docker_image "file-service" "./file-service" "${FILE_SERVICE_TAG}"
build_java_service_and_docker_image "notification-service" "./notification-service" "${NOTIFICATION_SERVICE_TAG}"

echo ">>> Wszystkie obrazy zostały zbudowane i wypchnięte pomyślnie."
echo "------------------------------------------------------------------"


# KROK 3: Uruchom pełne terraform apply dla reszty infrastruktury
echo ">>> KROK 3: Wdrażanie reszty infrastruktury Terraform..."
(
  cd ./terraform || { echo "BŁĄD: Nie można przejść do katalogu ./terraform"; exit 1; }
  # init nie jest tu zwykle potrzebny ponownie, jeśli był w kroku 1 i nic się nie zmieniło w konfiguracji backendu/providerów
  # ale dla pewności można go zostawić lub uruchomić warunkowo.
  # echo "INFO: Ponowna inicjalizacja Terraform (dla pewności)..."
  # terraform init -upgrade

  echo "INFO: Stosowanie pełnej konfiguracji Terraform..."
  terraform apply -auto-approve \
    -var="frontend_image_tag=${FRONTEND_TAG}" \
    -var="auth_service_image_tag=${AUTH_SERVICE_TAG}" \
    -var="chat_service_image_tag=${CHAT_SERVICE_TAG}" \
    -var="file_service_image_tag=${FILE_SERVICE_TAG}" \
    -var="notification_service_image_tag=${NOTIFICATION_SERVICE_TAG}"
)
echo ">>> Wdrożenie Terraform zakończone."
echo "------------------------------------------------------------------"


# KROK 4: Wyświetl outputy Terraform
echo ">>> KROK 4: Wyniki Terraform (Outputs)..."
(
  cd ./terraform || { echo "BŁĄD: Nie można przejść do katalogu ./terraform"; exit 1; }
  terraform output

  # Pobierz URL frontendu z outputów Terraform
  frontend_url=$(terraform output -raw frontend_url)
  echo "Frontend URL: $frontend_url"
  echo "Setting CORS origin for auth-service to frontend URL: $frontend_url"
)

echo "------------------------------------------------------------------"
echo ">>> Skrypt wdrożeniowy zakończony pomyślnie."
echo "------------------------------------------------------------------"


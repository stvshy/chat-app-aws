#!/bin/bash

set -e # Jeśli jakakolwiek komenda w skrypcie zakończy się błędem (zwróci status inny niż 0),
       # cały skrypt natychmiast się zakończy. To pomaga szybko wykryć problemy.

# --- Konfiguracja ---
# Tutaj ustawiamy podstawowe informacje potrzebne do wdrożenia.
AWS_ACCOUNT_ID="044902896603"    # unikalny numer konta AWS.
AWS_REGION="us-east-1"          # Region AWS, w którym będziemy tworzyć zasoby
PROJECT_NAME_PREFIX="projekt-chmury-v2" # Główny przedrostek nazwy projektu, taki sam jak w plikach Terraform.
                                        # Pomaga w nazywaniu zasobów w spójny sposób.


# Tagi to wersje obrazów Docker. Zmieniając je tutaj, możemy wdrożyć nową wersję aplikacji.
FRONTEND_TAG="v1.0.17"
AUTH_SERVICE_TAG="v1.0.19"
CHAT_SERVICE_TAG="v1.0.17"
FILE_SERVICE_TAG="v1.0.17"
NOTIFICATION_SERVICE_TAG="v1.0.17"

# Pełny adres URL do prywatnego rejestru obrazów Docker w AWS (ECR - Elastic Container Registry).
# Obrazy Docker będą tam przechowywane.
ECR_REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# --- Funkcje Pomocnicze ---
# To są małe "mini-programy" (funkcje), których będziemy używać później w skrypcie, żeby nie powtarzać kodu.
login_to_ecr() {
  # Ta funkcja loguje nas do rejestru ECR w AWS.
  # Jest to potrzebne, żeby móc wypychać (push) obrazy Docker do ECR.
  echo "INFO: Logowanie do AWS ECR..."
  # Komenda AWS CLI, która pobiera tymczasowe hasło do ECR...
  aws ecr get-login-password --region "${AWS_REGION}" | \
  # ...i przekazuje je (przez "|") do komendy docker login, która loguje się jako użytkownik "AWS" z tym hasłem.
  docker login --username AWS --password-stdin "${ECR_REGISTRY_URL}"
  echo "INFO: Logowanie do ECR zakończone pomyślnie."
}

# Funkcja do budowania serwisu Java/Maven i jego obrazu Docker
build_java_service_and_docker_image() {
  # Ta funkcja wykonuje kilka kroków:
  # 1. Buduje aplikację Java (tworzy plik .jar).
  # 2. Buduje obraz Docker dla tej aplikacji.
  # 3. Wypycha obraz Docker do ECR.

  local service_name="$1" # Pierwszy argument przekazany do funkcji (np. "auth-service").
  local service_path="$2" # Drugi argument (np. "./auth-service" - ścieżka do katalogu serwisu).
  local image_tag="$3"    # Trzeci argument (np. "v1.0.19" - tag/wersja obrazu).
  # Nazwa, pod którą obraz będzie zapisany w ECR (np. "auth-service").
  local ecr_repo_name_suffix="$1"

  # Pełna nazwa obrazu Docker, włącznie z adresem ECR, nazwą projektu, nazwą serwisu i tagiem.
  # Np. 044902896603.dkr.ecr.us-east-1.amazonaws.com/projekt-chmury-v2/auth-service:v1.0.19
  local full_image_name="${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/${ecr_repo_name_suffix}:${image_tag}"

  echo "------------------------------------------------------------------"
  echo "INFO: Budowanie serwisu Java: ${service_name} w ${service_path}"
  echo "------------------------------------------------------------------"
  # Przejdź do katalogu serwisu (np. ./auth-service) i uruchom komendę Mavena:
  # `clean package` - czyści stare pliki i buduje nowy plik .jar aplikacji.
  # `-DskipTests` - pomija uruchamianie testów jednostkowych (przyspiesza budowanie).
  (cd "${service_path}" && ./mvnw clean package -DskipTests)

  echo "------------------------------------------------------------------"
  echo "INFO: Budowanie obrazu Docker dla ${service_name} z tagiem ${image_tag}"
  echo "INFO: Nazwa obrazu: ${full_image_name}"
  echo "------------------------------------------------------------------"
  # Buduje obraz Docker:
  # `-t "${full_image_name}"` - nadaje obrazowi pełną nazwę (taguje go).
  # `"${service_path}"` - mówi Dockerowi, gdzie znaleźć plik Dockerfile i pliki aplikacji (kontekst budowania).
  docker build -t "${full_image_name}" "${service_path}"

  # Logowanie do ECR tuż przed próbą wypchnięcia obrazu, żeby mieć pewność, że sesja jest aktywna.
  login_to_ecr

  echo "------------------------------------------------------------------"
  echo "INFO: Wypychanie obrazu ${service_name} do ECR: ${full_image_name}"
  echo "------------------------------------------------------------------"
  # Wypycha (uploaduje) zbudowany i otagowany obraz Docker do rejestru ECR.
  docker push "${full_image_name}"
  echo "INFO: Pomyślnie wypchnięto ${service_name}."
}

# Funkcja do budowania obrazu Docker dla frontendu (Node.js)
build_frontend_docker_image() {
  # Ta funkcja jest podobna do poprzedniej, ale tylko buduje i wypycha obraz Docker
  # (zakładamy, że frontend jest już zbudowany np. przez `npm run build` wewnątrz Dockerfile).

  local service_name="frontend"
  local service_path="./frontend" # Ścieżka do katalogu frontendu.
  local image_tag="$1"            # Tag/wersja obrazu przekazana jako argument.
  local ecr_repo_name_suffix="frontend" # Nazwa repozytorium w ECR dla frontendu.

  # Pełna nazwa obrazu Docker dla frontendu.
  local full_image_name="${ECR_REGISTRY_URL}/${PROJECT_NAME_PREFIX}/${ecr_repo_name_suffix}:${image_tag}"

  echo "------------------------------------------------------------------"
  echo "INFO: Budowanie obrazu Docker dla ${service_name} z tagiem ${image_tag}"
  echo "INFO: Nazwa obrazu: ${full_image_name}"
  echo "------------------------------------------------------------------"
  # Buduje obraz Docker dla frontendu.
  docker build -t "${full_image_name}" "${service_path}"

  # Logowanie do ECR.
  login_to_ecr

  echo "------------------------------------------------------------------"
  echo "INFO: Wypychanie obrazu ${service_name} do ECR: ${full_image_name}"
  echo "------------------------------------------------------------------"
  # Wypycha obraz frontendu do ECR.
  docker push "${full_image_name}"
  echo "INFO: Pomyślnie wypchnięto ${service_name}."
}


# --- Główny Skrypt ---
# Tutaj zaczyna się właściwe działanie skryptu, krok po kroku.

# KROK 1: Stwórz/zapewnij istnienie repozytoriów ECR (i niezbędnych zależności)
# Najpierw musimy mieć "garaże" (repozytoria ECR) w AWS, zanim będziemy mogli "zaparkować" tam nasze "samochody" (obrazy Docker).
echo ">>> KROK 1: Tworzenie/zapewnianie istnienia repozytoriów ECR..."
( # Użycie nawiasów `{...}` tworzy subshell - komendy wewnątrz działają w osobnym środowisku.
  # Jeśli `cd` się nie uda, `exit 1` zakończy subshell (i dzięki `set -e` cały skrypt).
  cd ./terraform || { echo "BŁĄD: Nie można przejść do katalogu ./terraform"; exit 1; }

  echo "INFO: Inicjalizacja Terraform (jeśli potrzebna)..."
  # `terraform init` przygotowuje Terraform do pracy: pobiera pluginy dostawców (np. AWS), konfiguruje backend (gdzie trzymać stan).
  # `-upgrade` próbuje zaktualizować pluginy do najnowszych kompatybilnych wersji.
  terraform init -upgrade

  echo "INFO: Stosowanie konfiguracji Terraform tylko dla repozytoriów ECR..."
  # `terraform apply` wprowadza zmiany zdefiniowane w plikach .tf.
  # `-auto-approve` - automatycznie zatwierdza zmiany, nie pyta "Do you want to perform these actions?".
  # `-target=...` - mówi Terraformowi, żeby zastosował zmiany TYLKO dla określonych zasobów.
  # Tutaj tworzymy (lub upewniamy się, że istnieją) tylko repozytoria ECR i zasób `random_string.suffix`,
  # bo nazwy repozytoriów mogą od niego zależeć.
  terraform apply -auto-approve \
    -target=aws_ecr_repository.frontend_repo \
    -target=aws_ecr_repository.auth_service_repo \
    -target=aws_ecr_repository.chat_service_repo \
    -target=aws_ecr_repository.file_service_repo \
    -target=aws_ecr_repository.notification_service_repo \
    -target=random_string.suffix
)
echo ">>> Repozytoria ECR powinny teraz istnieć."
echo "------------------------------------------------------------------"


# KROK 2: Zbuduj i wypchnij wszystkie obrazy Docker
# Teraz, gdy mamy "garaże" (repozytoria ECR), budujemy nasze "samochody" (obrazy Docker) i je tam parkujemy.
echo ">>> KROK 2: Budowanie i wypychanie obrazów Docker..."

# Wywołujemy nasze funkcje pomocnicze, żeby zbudować i wypchnąć obraz dla każdego serwisu.
# Przekazujemy odpowiednie tagi (wersje) zdefiniowane na początku skryptu.
build_frontend_docker_image "${FRONTEND_TAG}"
build_java_service_and_docker_image "auth-service" "./auth-service" "${AUTH_SERVICE_TAG}"
build_java_service_and_docker_image "chat-service" "./chat-service" "${CHAT_SERVICE_TAG}"
build_java_service_and_docker_image "file-service" "./file-service" "${FILE_SERVICE_TAG}"
build_java_service_and_docker_image "notification-service" "./notification-service" "${NOTIFICATION_SERVICE_TAG}"

echo ">>> Wszystkie obrazy zostały zbudowane i wypchnięte pomyślnie."
echo "------------------------------------------------------------------"


# KROK 3: Uruchom pełne terraform apply dla reszty infrastruktury
# Mamy już obrazy Docker w ECR. Teraz Terraform może stworzyć resztę infrastruktury
# (Load Balancer, bazy danych, usługi Fargate, które będą używać tych obrazów).
echo ">>> KROK 3: Wdrażanie reszty infrastruktury Terraform..."
(
  cd ./terraform || { echo "BŁĄD: Nie można przejść do katalogu ./terraform"; exit 1; }
  # `terraform init` zwykle nie jest tu potrzebny ponownie, jeśli był w kroku 1 i nic się nie zmieniło
  # w konfiguracji backendu Terraform lub dostawców. Ale nie zaszkodzi.
  # echo "INFO: Ponowna inicjalizacja Terraform (dla pewności)..."
  # terraform init -upgrade

  echo "INFO: Stosowanie pełnej konfiguracji Terraform..."
  # Tym razem `terraform apply` bez `-target`, więc stworzy/zaktualizuje WSZYSTKIE zasoby zdefiniowane w plikach .tf.
  # Przekazujemy tagi obrazów jako zmienne (`-var="..."`) do Terraformu.
  # Terraform użyje tych tagów w definicjach zadań ECS, żeby wiedzieć, którą wersję obrazu Docker uruchomić.
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
# Po zakończeniu `terraform apply`, chcemy zobaczyć pewne ważne informacje, np. adres URL naszego frontendu.
echo ">>> KROK 4: Wyniki Terraform (Outputs)..."
(
  cd ./terraform || { echo "BŁĄD: Nie można przejść do katalogu ./terraform"; exit 1; }
  # `terraform output` wyświetla wartości zdefiniowane w blokach `output "nazwa" { ... }` w plikach .tf.
  terraform output

  # Pobierz konkretny output (URL frontendu) do zmiennej bashowej.
  # `-raw` usuwa cudzysłowy z outputu.
  frontend_url=$(terraform output -raw frontend_url)
  echo "Frontend URL: $frontend_url"
  # Ta linia jest bardziej informacyjna, faktyczne ustawienie CORS dzieje się w Terraformie
  # przez przekazanie adresu frontendu jako zmiennej środowiskowej do backendów.
  echo "Setting CORS origin for auth-service to frontend URL: $frontend_url"
)

echo "------------------------------------------------------------------"
echo ">>> Skrypt wdrożeniowy zakończony pomyślnie."
echo "------------------------------------------------------------------"

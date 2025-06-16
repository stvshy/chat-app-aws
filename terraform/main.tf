terraform { # Blok 'terraform' to takie ustawienia globalne dla całego projektu Terraform.
  # Mówimy mu tutaj, jakich "wtyczek" (czyli dostawców usług chmurowych) będziemy używać
  # i jakie mają mieć wersje.
  required_providers {
    # Tutaj deklarujemy, że potrzebujemy dostawcy AWS.
    # To jest "wtyczka", która pozwoli Terraformowi "rozmawiać" z usługami Amazona (AWS).
    aws = {
      # source mówi, skąd wziąć tę wtyczkę – to jest oficjalna wtyczka HashiCorp dla AWS.
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Używamy dostawcy random do generowania losowych ciągów znaków
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    # To "wtyczka", która pozwala na operacje związane z czasem, np. do tworzenia unikalnych identyfikatorów
    # opartych o timestampy albo do wymuszania zmian zasobów.
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# --- Konfiguracja dostawcy AWS ---
# Ten blok 'provider' to takie "logowanie się" do AWS i ustawienie domyślnych parametrów.
# Mówimy Terraformowi, że chcemy używać AWS.
provider "aws" {
  # Tutaj ustawiamy region AWS, czyli fizyczną lokalizację centrum danych, w którym będą tworzone nasze zasoby.
  region = "us-east-1"    # Ważne, żeby wszystkie zasoby były w tym samym regionie.
}

# Ten blok 'data' to coś, co nie tworzy nowego zasobu, tylko przygotowuje dane.
# W tym przypadku, używamy 'archive_file', żeby tymczasowo spakować coś do pliku ZIP.
data "archive_file" "dummy_lambda_zip" {
  # Mówimy, że chcemy stworzyć archiwum typu ZIP.
  type        = "zip"
  # Tutaj definiujemy ścieżkę, gdzie ten tymczasowy plik ZIP zostanie zapisany na naszym komputerze.
  # `${path.module}` oznacza katalog, w którym znajduje się ten plik Terraform.
  output_path = "${path.module}/dummy_lambda_code.zip" # Gdzie zapisać plik tymczasowo

  # Wkładamy do ZIP-a jeden plik z byle jaką treścią, żeby nie był pusty.
  # To jest "zaślepka" – faktyczny kod Lambdy jest wrzucany później za pomocą skryptu deploy.sh, ale Terraform potrzebuje tu pliku.
  source {
    content  = "dummy content" # Treść, która znajdzie się w pliku.
    filename = "placeholder.txt"  # Nazwa tego pliku wewnątrz archiwum ZIP.
  }
}

# --- Zmienne wejściowe dla tagów obrazów Docker ---
# Bloki 'variable' to miejsca, gdzie możemy zdefiniować wartości, które mogą być zmieniane
# przy uruchamianiu Terraform (np. z linii komend). To sprawia, że kod jest bardziej elastyczny.

# Definicja zmiennej dla taga (wersji) obrazu Docker dla usługi "auth-service".
variable "auth_service_image_tag" {
  description = "Docker image tag for auth-service"  # Opis zmiennej, żeby było wiadomo, do czego służy.
  type        = string   # Typ zmiennej – w tym przypadku tekst (ciąg znaków).
  default     = "v1.0.1"   # Domyślna wartość, jeśli nie zostanie podana inna.
}
# Definicja zmiennej dla taga obrazu Docker dla usługi "file-service".
variable "file_service_image_tag" {
  description = "Docker image tag for file-service"
  type        = string
  default     = "v1.0.0"
}
# Definicja zmiennej dla taga obrazu Docker dla usługi "notification-service".
variable "notification_service_image_tag" {
  description = "Docker image tag for notification-service"
  type        = string
  default     = "v1.0.0"
}
# Definicja zmiennej dla taga obrazu Docker dla usługi "frontend".
variable "frontend_image_tag" {
  description = "Docker image tag for frontend"
  type        = string
  default     = "v1.0.1"
}
# Zmienna przechowująca nazwę pliku JAR dla Lambd czatu w buckecie S3.
variable "lambda_chat_handlers_jar_key" {
  description = "S3 key for the chat Lambda handlers JAR file"
  type        = string
  default     = "chat-lambda-handlers.jar" # Domyślna nazwa pliku.
}

# --- Generowanie losowego ciągu znaków ---
resource "random_string" "suffix" {
  length  = 4   # Chcemy, żeby miał 4 znaki długości.
  special = false  # Nie chcemy znaków specjalnych.
  upper   = false  # Nie chcemy wielkich liter.
}

# Tworzymy zasób 'time_static', który łapie aktualny czas w momencie tworzenia.
# Jest używany głównie po to, by wymusić ponowne tworzenie zasobów, które się od niego odwołują.
resource "time_static" "timestamp" {}

# --- Lokalne zmienne ---
# 'locals' to takie "wewnętrzne" zmienne, których używamy w tym pliku, żeby nie powtarzać kodu i utrzymać porządek.
locals {
  project_name_prefix = "projekt-chmury-v2"   # Definiujemy stały prefiks dla nazw naszych zasobów, żeby łatwo je było zidentyfikować.
  # Tworzymy pełną, unikalną nazwę projektu, dodając losowy sufiks. Dzięki temu możemy wdrażać wiele wersji tej samej infrastruktury obok siebie.
  project_name        = "${local.project_name_prefix}-${random_string.suffix.result}"

  # Definiujemy zestaw wspólnych tagów (etykiet), które będziemy dodawać do wszystkich naszych zasobów w AWS.
  # Pomaga to w organizacji i zarządzaniu kosztami.
  common_tags = {
    Project     = local.project_name_prefix  # Nazwa projektu.
    Environment = "dev"  # Środowisko (deweloperskie).
    Suffix      = random_string.suffix.result  # Unikalny, losowy sufiks.
  }

  # Definiujemy nazwy naszych mikroserwisów, żeby łatwo się do nich odwoływać.
  auth_service_name         = "auth-service"
  file_service_name         = "file-service"
  notification_service_name = "notification-service"
  frontend_name             = "frontend"

  # Tworzymy mapę z konfiguracją dla każdej usługi Fargate.
  # Dzięki temu możemy tworzyć zasoby (np. definicje zadań, usługi ECS) w pętli `for_each`, zamiast kopiować ten sam kod dla każdej usługi.
  fargate_services = {
    # Konfiguracja dla 'auth-service'
    (local.auth_service_name) = {
      port               = 8081  # Port, na którym aplikacja nasłuchuje w kontenerze.
      ecr_repo_base_url  = aws_ecr_repository.auth_service_repo.repository_url  # Adres URL repozytorium ECR, skąd będzie pobierany obraz Docker.
      image_tag          = var.auth_service_image_tag  # Tag (wersja) obrazu Docker, pobierany ze zmiennej wejściowej.
      log_group_name     = aws_cloudwatch_log_group.auth_service_logs.name  # Nazwa grupy logów w CloudWatch, gdzie będą trafiać logi z kontenera.
      target_group_arn   = aws_lb_target_group.auth_tg.arn  # ARN grupy docelowej w Load Balancerze, do której będzie kierowany ruch.
      environment_vars   = [  # Lista zmiennych środowiskowych, które zostaną wstrzyknięte do kontenera.
        { name = "SPRING_PROFILES_ACTIVE", value = "aws" },  # Ustawia profil Springa na 'aws'.
        { name = "AWS_REGION", value = data.aws_region.current.name },  # Przekazuje aktualny region AWS.
        { name = "AWS_COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.chat_pool.id },  # ID puli użytkowników Cognito.
        { name = "AWS_COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.chat_pool_client.id },  # ID klienta aplikacji w Cognito.
        { name = "SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI", value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.chat_pool.id}" }, # Adres do walidacji tokenów JWT.
        { name = "AWS_DYNAMODB_TABLE_NAME_USER_PROFILES", value = aws_dynamodb_table.user_profiles_table.name },  # Nazwa tabeli DynamoDB z profilami.
        { name = "APP_CORS_ALLOWED_ORIGIN_FRONTEND", value = "http://${aws_lb.main_alb.dns_name}" }  # Adres frontendu dozwolony przez CORS.
      ]
    },
    # Konfiguracja dla 'file-service'
    (local.file_service_name) = {
      port               = 8083  # Port, na którym aplikacja nasłuchuje w kontenerze.
      ecr_repo_base_url  = aws_ecr_repository.file_service_repo.repository_url  # Adres URL repozytorium ECR, skąd będzie pobierany obraz Docker.
      image_tag          = var.file_service_image_tag   # Tag (wersja) obrazu Docker, pobierany ze zmiennej wejściowej.
      log_group_name     = aws_cloudwatch_log_group.file_service_logs.name  # Nazwa grupy logów w CloudWatch, gdzie będą trafiać logi z kontenera.
      target_group_arn   = aws_lb_target_group.file_tg.arn  # ARN grupy docelowej w Load Balancerze, do której będzie kierowany ruch.
      environment_vars   = [
        { name = "SPRING_PROFILES_ACTIVE", value = "aws" },  # Ustawia profil Springa na 'aws'.
        { name = "AWS_REGION", value = data.aws_region.current.name },  # Przekazuje aktualny region AWS.
        { name = "AWS_COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.chat_pool.id }, # ID puli użytkowników Cognito.
        { name = "AWS_COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.chat_pool_client.id }, # ID klienta aplikacji w Cognito.
        { name = "SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI", value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.chat_pool.id}" }, # Adres do walidacji tokenów JWT.
        { name = "AWS_S3_BUCKET_NAME", value = aws_s3_bucket.upload_bucket.bucket },  # Nazwa bucketa S3 na pliki.
        { name = "AWS_DYNAMODB_TABLE_NAME_FILE_METADATA", value = aws_dynamodb_table.file_metadata_table.name }, # Nazwa tabeli DynamoDB z metadanymi plików.
        { name = "APP_CORS_ALLOWED_ORIGIN_FRONTEND", value = "http://${aws_lb.main_alb.dns_name}" }  # Adres frontendu dozwolony przez CORS.
      ]
    },
    # Konfiguracja dla 'frontend'
    (local.frontend_name) = {
      port = 3000 # Port, na którym działa frontend w kontenerze
      ecr_repo_base_url = aws_ecr_repository.frontend_repo.repository_url  # Adres URL repozytorium ECR, skąd będzie pobierany obraz Docker.
      image_tag         = var.frontend_image_tag   # Tag (wersja) obrazu Docker, pobierany ze zmiennej wejściowej.
      log_group_name = aws_cloudwatch_log_group.frontend_logs.name  # Nazwa grupy logów w CloudWatch, gdzie będą trafiać logi z kontenera.
      target_group_arn = aws_lb_target_group.frontend_tg.arn  # ARN grupy docelowej w Load Balancerze, do której będzie kierowany ruch.
      environment_vars = [
        # Przekazujemy adres URL API czatu do frontendu, żeby wiedział, gdzie wysyłać zapytania.
        { name = "VITE_CHAT_API_URL", value = "${aws_api_gateway_stage.chat_api_stage_v1.invoke_url}/messages" }
      ]
    }
    # Konfiguracja dla 'notification-service'
    (local.notification_service_name) = {
      port               = 8084 # Port, na którym działa frontend w kontenerze
      ecr_repo_base_url  = aws_ecr_repository.notification_service_repo.repository_url   # Adres URL repozytorium ECR, skąd będzie pobierany obraz Docker.
      image_tag          = var.notification_service_image_tag  # Tag (wersja) obrazu Docker, pobierany ze zmiennej wejściowej.
      log_group_name     = aws_cloudwatch_log_group.notification_service_logs.name  # Nazwa grupy logów w CloudWatch, gdzie będą trafiać logi z kontenera.
      target_group_arn   = aws_lb_target_group.notification_tg.arn  # ARN grupy docelowej w Load Balancerze, do której będzie kierowany ruch.
      environment_vars   = [
        { name = "SPRING_PROFILES_ACTIVE", value = "aws" }, # Ustawia profil Springa na 'aws'.
        { name = "AWS_REGION", value = data.aws_region.current.name }, # Przekazuje aktualny region AWS.
        { name = "AWS_COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.chat_pool.id }, # ID puli użytkowników Cognito.
        { name = "AWS_COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.chat_pool_client.id }, # ID klienta aplikacji w Cognito.
        { name = "SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI", value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.chat_pool.id}" }, # Adres do walidacji tokenów JWT.
        { name = "AWS_SNS_TOPIC_ARN", value = aws_sns_topic.notifications_topic.arn }, # ARN tematu SNS do wysyłania powiadomień.
        { name = "AWS_DYNAMODB_TABLE_NAME_NOTIFICATION_HISTORY", value = aws_dynamodb_table.notifications_history_table.name }, # Nazwa tabeli z historią powiadomień.
        { name = "APP_SQS_QUEUE_URL", value = aws_sqs_queue.chat_notifications_queue.id }, # URL kolejki SQS z której pobierane są wiadomości.
        { name = "APP_CORS_ALLOWED_ORIGIN_FRONTEND", value = "http://${aws_lb.main_alb.dns_name}" }] # Adres frontendu dozwolony przez CORS.
    }
  }
  # Definiujemy wspólne zmienne środowiskowe dla wszystkich funkcji Lambda obsługujących czat.
  # Dzięki temu nie musimy ich powtarzać w każdej definicji Lambdy.
  chat_lambda_common_environment_variables = {
    DB_URL         = "jdbc:postgresql://${aws_db_instance.chat_db.address}:${aws_db_instance.chat_db.port}/${aws_db_instance.chat_db.db_name}" # Adres połączeniowy do bazy danych RDS.
    DB_USER        = aws_db_instance.chat_db.username  # Nazwa użytkownika bazy danych.
    DB_PASSWORD    = aws_db_instance.chat_db.password  # Hasło do bazy danych.
    SQS_QUEUE_URL  = aws_sqs_queue.chat_notifications_queue.id  # URL kolejki SQS do wysyłania powiadomień o nowych wiadomościach.
    AWS_REGION_ENV = data.aws_region.current.name   # Aktualny region AWS.
  }
}

# Blok danych 'aws_region', który po prostu pobiera informacje o aktualnie skonfigurowanym regionie.
data "aws_region" "current" {}

# Grupa logów dla frontendu
resource "aws_cloudwatch_log_group" "frontend_logs" {
  name              = "/ecs/${local.project_name}/${local.frontend_name}" # Nazwa grupy logów. Używamy konwencji, która ułatwia znalezienie logów dla konkretnej usługi.
  retention_in_days = 7  # Logi będą przechowywane przez 7 dni, a potem automatycznie usuwane, żeby oszczędzać koszty.
  tags              = local.common_tags  # Dodajemy wspólne tagi.
}

# Grupa docelowa (Target Group) dla frontendu
# Load Balancer będzie kierował ruch do kontenerów zarejestrowanych w tej grupie.
resource "aws_lb_target_group" "frontend_tg" {
  name        = substr("${local.project_name}-fe-tg", 0, 32)  # Nazwa grupy. substr ucina nazwę do 32 znaków, bo AWS ma taki limit.
  port        = 3000  # Port, na którym nasłuchuje aplikacja w kontenerze.
  protocol    = "HTTP"  # Protokół komunikacji.
  vpc_id      = data.aws_vpc.default.id  # ID sieci VPC, w której działa grupa.
  target_type = "ip"  # Typ celu to 'ip', bo w Fargate kontenery dostają własne adresy IP.
  health_check {
    path     = "/" # Load Balancer będzie odpytywał ścieżkę "/" w kontenerze.
    protocol = "HTTP" # Używając protokołu HTTP.
    matcher  = "200" # Oczekuje odpowiedzi z kodem 200 (OK), aby uznać kontener za zdrowy.
  }
  tags = local.common_tags # Dodajemy wspólne tagi.
}

# Tworzymy regułę w Load Balancerze dla frontendu.
# Ta reguła decyduje, jaki ruch ma trafić do grupy docelowej frontendu.
resource "aws_lb_listener_rule" "frontend_rule" {
  listener_arn = aws_lb_listener.http_listener.arn # ARN "nasłuchiwacza" (listenera) w Load Balancerze, do którego przypisujemy regułę.
  priority     = 500 # Priorytet reguły. Niższa liczba = wyższy priorytet. Ustawiamy wysoki numer, żeby była to reguła domyślna (łapiąca wszystko, co nie pasuje do innych).

  action { # Akcja, która ma być wykonana, gdy warunek jest spełniony.
    type             = "forward"  # Przekieruj ruch (forward).
    target_group_arn = aws_lb_target_group.frontend_tg.arn  # Do grupy docelowej frontendu.
  }

  condition { # Warunek, który musi być spełniony, aby reguła zadziałała.
    path_pattern { # Warunek oparty na ścieżce w adresie URL.
      values = ["/*"] # Wartość "/*" oznacza "złap wszystko", co czyni tę regułę domyślną.
    }
  }
}

# --- ODPORNA KONFIGURACJA SIECI ---
# 1. Znajdź domyślną sieć VPC na koncie AWS.
data "aws_vpc" "default" {
  default = true # Szukamy tej, która jest oznaczona jako domyślna.
}
# 2. Znajdź wszystkie podsieci w tej domyślnej VPC.
data "aws_subnets" "default" {
  filter {  # Filtrujemy podsieci, żeby należały do znalezionej wcześniej VPC.
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 3. ZNAJDŹ istniejącą bramę internetową, która jest już podpięta do domyślnej VPC.
#    Nie tworzymy nowej, tylko odczytujemy dane istniejącej.
data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 3. Zarządzaj domyślną tablicą routingu
#    Ten zasób odnajdzie domyślną tablicę routingu dla VPC i pozwoli nam
#    zadeklarować, jakie trasy mają w niej być. Jeśli trasa już istnieje,
#    Terraform po prostu przejmie nad nią zarządzanie.
resource "aws_default_route_table" "main_rt" {
  # Używamy poprawnego atrybutu z data.aws_vpc
  default_route_table_id = data.aws_vpc.default.main_route_table_id # <<< POPRAWKA TUTAJ

  # Definiujemy trasę do internetu
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.default.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-default-rt"
  })
}

# --- Grupy bezpieczeństwa ---
# Grupy bezpieczeństwa działają jak wirtualny firewall dla zasobów, kontrolując ruch przychodzący i wychodzący.

# Grupa bezpieczeństwa dla Application Load Balancera (ALB).
resource "aws_security_group" "alb_sg" {
  name        = "${local.project_name}-alb-sg"  # Unikalna nazwa grupy.
  description = "Security group for ALB"
  vpc_id      = data.aws_vpc.default.id   # Przypisujemy do naszej VPC.
  ingress { # Reguły ruchu przychodzącego (ingress).
    # Zezwalamy na ruch na porcie 80 (HTTP).
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Z dowolnego miejsca w internecie.
  }
  egress { # Reguły ruchu wychodzącego (egress).
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags  # Wspólne tagi
}

# resource "aws_security_group" "fargate_sg" {
#   name        = "${local.project_name}-fargate-sg"
#   description = "Security group for Fargate services"
#   vpc_id      = data.aws_vpc.default.id
#   ingress {
#     from_port       = 8081
#     to_port         = 8081
#     protocol        = "tcp"
#     security_groups = [aws_security_group.alb_sg.id]
#   }
#   ingress {
#     from_port       = 8083
#     to_port         = 8083
#     protocol        = "tcp"
#     security_groups = [aws_security_group.alb_sg.id]
#   }
#   ingress {
#     from_port       = 8084
#     to_port         = 8084
#     protocol        = "tcp"
#     security_groups = [aws_security_group.alb_sg.id]
#   }
#   ingress {
#     from_port       = 3000
#     to_port         = 3000
#     protocol        = "tcp"
#     security_groups = [aws_security_group.alb_sg.id]
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = local.common_tags
# }

# Grupa bezpieczeństwa dla zasobów wewnętrznych (usług Fargate i funkcji Lambda).
# Ta grupa jest kluczowa dla komunikacji między różnymi częściami naszej aplikacji.
resource "aws_security_group" "internal_sg" {
  name        = "${local.project_name}-internal-sg"
  description = "Security group for internal resources (Fargate and Lambda)"
  vpc_id      = data.aws_vpc.default.id

  # --- Reguły przychodzące ---
  # Zezwalamy na ruch od Load Balancera (który jest w grupie 'alb_sg') na porty poszczególnych aplikacji.
  ingress {
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    from_port       = 8083
    to_port         = 8083
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    from_port       = 8084
    to_port         = 8084
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # KLUCZOWA REGUŁA: Zezwól na cały ruch wewnątrz tej samej grupy bezpieczeństwa.
  # To pozwala Lambdom komunikować się z bazą RDS i usługom Fargate ze sobą (jeśli zajdzie potrzeba) bez otwierania konkretnych portów.
  ingress {
    protocol  = "-1" # Dowolny protokół.
    from_port = 0    # Dowolny port.
    to_port   = 0    # Dowolny port.
    self      = true # 'self = true' oznacza, że źródłem ruchu może być inny zasób w tej samej grupie.
  }

  # --- Reguła wychodząca (bez zmian) ---
  # Zezwalamy na cały ruch wychodzący, aby nasze usługi i Lambdy mogły łączyć się z innymi usługami AWS i internetem.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
}

# --- Repozytoria ECR ---
# ECR (Elastic Container Registry) to usługa AWS do przechowywania obrazów Docker. Tworzymy osobne repozytorium dla każdej mikroserwisuy.
# Repozytorium dla auth-service.
resource "aws_ecr_repository" "auth_service_repo" {
  name         = "${local.project_name_prefix}/${local.auth_service_name}" # Nazwa repozytorium, zgodna z konwencją projektu.
  tags         = local.common_tags
  force_delete = true  # Jeśli usuniemy repozytorium przez Terraform, to zostanie ono usunięte nawet jeśli zawiera obrazy. Użyteczne w środowiskach deweloperskich.
}
# Repozytorium dla file-service.
resource "aws_ecr_repository" "file_service_repo" {
  name         = "${local.project_name_prefix}/${local.file_service_name}" # POPRAWIONA NAZWA
  tags         = local.common_tags
  force_delete = true # Jeśli usuniemy repozytorium przez Terraform, to zostanie ono usunięte nawet jeśli zawiera obrazy. Użyteczne w środowiskach deweloperskich.
}
# Repozytorium dla notification-service.
resource "aws_ecr_repository" "notification_service_repo" {
  name         = "${local.project_name_prefix}/${local.notification_service_name}" # POPRAWIONA NAZWA
  tags         = local.common_tags
  force_delete = true # Jeśli usuniemy repozytorium przez Terraform, to zostanie ono usunięte nawet jeśli zawiera obrazy. Użyteczne w środowiskach deweloperskich.
}
# Repozytorium dla frontendu.
resource "aws_ecr_repository" "frontend_repo" {
  name         = "${local.project_name_prefix}/${local.frontend_name}" # POPRAWIONA NAZWA
  tags         = local.common_tags
  force_delete = true # Jeśli usuniemy repozytorium przez Terraform, to zostanie ono usunięte nawet jeśli zawiera obrazy. Użyteczne w środowiskach deweloperskich.
}

# --- Klaster ECS ---
# ECS (Elastic Container Service) to usługa do orkiestracji kontenerów. Klaster to logiczne zgrupowanie zasobów (w naszym przypadku usług Fargate)
resource "aws_ecs_cluster" "main_cluster" {
  name = "${local.project_name}-cluster"  # Nadajemy klastrowi unikalną nazwę.
  tags = local.common_tags
}

# --- Application Load Balancer (ALB) ---
# ALB to "inteligentny" rozdzielacz ruchu, który kieruje przychodzące zapytania HTTP do odpowiednich usług na podstawie ścieżki URL, hosta itp.
resource "aws_lb" "main_alb" {
  name               = "${local.project_name}-alb" # Unikalna nazwa.
  internal           = false  # 'false' oznacza, że jest publicznie dostępny z internetu.
  load_balancer_type = "application" # Typ 'application' jest przeznaczony dla ruchu HTTP/HTTPS.
  security_groups    = [aws_security_group.alb_sg.id] # Przypisujemy mu grupę bezpieczeństwa, którą stworzyliśmy wcześniej.
  subnets            = data.aws_subnets.default.ids # ALB musi działać w co najmniej dwóch podsieciach dla wysokiej dostępności.
  tags               = local.common_tags
  idle_timeout       = 60 # Czas bezczynności połączenia (w sekundach).
  enable_http2       = true  # Włączamy obsługę protokołu HTTP/2.
  drop_invalid_header_fields = false  # Nie odrzucamy zapytań z nieprawidłowymi nagłówkami.
}

# Listener dla ALB. Nasłuchuje na określonym porcie i protokole na przychodzący ruch.
resource "aws_lb_listener" "http_listener" {
  # ARN load balancera, do którego należy ten listener.
  load_balancer_arn = aws_lb.main_alb.arn
  # Nasłuchuje na porcie 80.
  port              = "80"
  # Używając protokołu HTTP.
  protocol          = "HTTP"
  # Akcja domyślna, która jest wykonywana, jeśli żadna inna reguła nie pasuje.
  default_action {
    # Zwróć stałą odpowiedź.
    type = "fixed-response"
    # Konfiguracja tej odpowiedzi.
    fixed_response {
      content_type = "text/plain"
      # Wiadomość, która zostanie zwrócona.
      message_body = "Service not found - Check ALB Rules or API Gateway for Chat"
      # Kod statusu HTTP.
      status_code  = "404"
    }
  }
}

# --- Grupy Docelowe (Target Groups) dla ALB ---
# Grupa docelowa to zbiór celów (w naszym przypadku kontenerów Fargate), do których ALB przesyła ruch.

# Grupa docelowa dla auth-service.
resource "aws_lb_target_group" "auth_tg" {
  # Nazwa grupy.
  name        = "${local.project_name}-auth-tg"
  # Port, na którym nasłuchuje aplikacja w kontenerze.
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"
  # Konfiguracja sprawdzania stanu zdrowia.
  health_check {
    enabled             = true
    # Musi być 5 udanych sprawdzeń z rzędu, aby uznać cel za zdrowy.
    healthy_threshold   = 5
    # Sprawdzanie co 60 sekund.
    interval            = 60
    # Oczekiwany kod odpowiedzi HTTP.
    matcher             = "200-299"
    # Ścieżka, którą ALB będzie odpytywać.
    path                = "/actuator/health"
    port                = "traffic-port" # Użyj portu, na który kierowany jest ruch.
    protocol            = "HTTP"
    # Czas oczekiwania na odpowiedź.
    timeout             = 20
    # 5 nieudanych sprawdzeń z rzędu, aby uznać cel za niezdrowy.
    unhealthy_threshold = 5
  }
  tags = local.common_tags
  # Cykl życia zasobu. 'create_before_destroy' zapewnia płynne wdrożenia bez przestojów.
  lifecycle {
    create_before_destroy = true
  }
}
# Grupa docelowa dla file-service.
resource "aws_lb_target_group" "file_tg" {
  name        = "${local.project_name}-file-tg"
  port        = 8083
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"
  health_check {
    path     = "/actuator/health"
    protocol = "HTTP"
    matcher  = "200"
  }
  tags = local.common_tags
}
# Grupa docelowa dla notification-service.
resource "aws_lb_target_group" "notification_tg" {
  name        = "${local.project_name}-notif-tg"
  port        = 8084
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"
  health_check {
    path     = "/actuator/health"
    protocol = "HTTP"
    matcher  = "200"
  }
  tags = local.common_tags
}

# --- Reguły Listenera ALB ---
# Te reguły mówią listenerowi, jak kierować ruch na podstawie ścieżki URL.

# Reguła dla auth-service.--
resource "aws_lb_listener_rule" "auth_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  # Priorytet 100 (im niższy, tym ważniejszy).
  priority     = 100
  action {
    type             = "forward"
    # Przekieruj do grupy docelowej auth-service.
    target_group_arn = aws_lb_target_group.auth_tg.arn
  }
  condition {
    path_pattern {
      # Jeśli ścieżka zaczyna się od "/api/auth/".
      values = ["/api/auth/*"]
    }
  }
}
# Reguła dla file-service.
resource "aws_lb_listener_rule" "file_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 120
  action {
    type             = "forward"
    # Przekieruj do grupy docelowej file-service.
    target_group_arn = aws_lb_target_group.file_tg.arn
  }
  condition {
    path_pattern {
      # Jeśli ścieżka zaczyna się od "/api/files/".
      values = ["/api/files/*"]
    }
  }
}
# Reguła dla notification-service.
resource "aws_lb_listener_rule" "notification_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 130
  action {
    type             = "forward"
    # Przekieruj do grupy docelowej notification-service.
    target_group_arn = aws_lb_target_group.notification_tg.arn
  }
  condition {
    path_pattern {
      # Jeśli ścieżka zaczyna się od "/api/notifications/".
      values = ["/api/notifications/*"]
    }
  }
}

# --- Baza Danych RDS ---
# RDS (Relational Database Service) to zarządzana usługa baz danych. Używamy jej do uruchomienia bazy PostgreSQL dla serwisu czatu.

# Grupa podsieci dla RDS. Mówi bazie danych, w których podsieciach może działać.
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${local.project_name}-rds-subnet-group"
  # Używamy wszystkich domyślnych podsieci.
  subnet_ids = data.aws_subnets.default.ids
  tags       = local.common_tags
}
# Grupa bezpieczeństwa dla instancji RDS.
resource "aws_security_group" "rds_sg" {
  name        = "${local.project_name}-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = data.aws_vpc.default.id
  # Reguła przychodząca.
  ingress {
    description     = "Allow Lambda to connect to RDS"
    # Zezwól na ruch na porcie 5432 (domyślny port PostgreSQL).
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    # Tylko z zasobów należących do grupy 'internal_sg' (czyli naszych Lambd).
    security_groups = [aws_security_group.internal_sg.id]
  }
  # Zezwól na cały ruch wychodzący.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
}

# Definicja samej instancji bazy danych.
resource "aws_db_instance" "chat_db" {
  # Unikalny identyfikator instancji.
  identifier           = "${local.project_name}-chat-db"
  # Rozmiar dysku w GB.
  allocated_storage    = 20
  # Silnik bazy danych.
  engine               = "postgres"
  # Wersja silnika.
  engine_version       = "14.15"
  # Typ maszyny wirtualnej (mała, deweloperska).
  instance_class       = "db.t3.micro"
  # Nazwa początkowej bazy danych, która zostanie utworzona.
  db_name              = "chat_service_db"
  # Login administratora.
  username             = "chatadmin"
  # Hasło administratora (w prawdziwym projekcie powinno być zarządzane przez sekrety!).
  password             = "admin1234"
  # Domyślna grupa parametrów dla PostgreSQL 14.
  parameter_group_name = "default.postgres14"
  # Przypisujemy grupę podsieci.
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  # Przypisujemy grupę bezpieczeństwa.
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  # Nie twórz końcowego snapshotu przy usuwaniu instancji (dobre dla dev).
  skip_final_snapshot  = true
  tags = local.common_tags
}


# --- Tabele DynamoDB ---
# DynamoDB to zarządzana baza danych NoSQL. Używamy jej do przechowywania danych, które nie wymagają schematu relacyjnego.

# Tabela do przechowywania profili użytkowników.
resource "aws_dynamodb_table" "user_profiles_table" {
  # Unikalna nazwa tabeli.
  name         = "${local.project_name}-user-profiles"
  # Model rozliczeń 'PAY_PER_REQUEST' jest idealny dla nieregularnego ruchu, płacimy tylko za to, co użyjemy.
  billing_mode = "PAY_PER_REQUEST"
  # Klucz główny (hash key), czyli unikalny identyfikator rekordu.
  hash_key     = "userId"
  # Definicja atrybutu klucza głównego.
  attribute {
    name = "userId"
    type = "S" # 'S' oznacza String (ciąg znaków).
  }
  tags = local.common_tags
}

# Tabela do przechowywania metadanych o plikach.
resource "aws_dynamodb_table" "file_metadata_table" {
  name         = "${local.project_name}-file-metadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "fileId"
  attribute {
    name = "fileId"
    type = "S"
  }
  tags = local.common_tags
}
# Tabela do przechowywania historii powiadomień.
resource "aws_dynamodb_table" "notifications_history_table" {
  name         = "${local.project_name}-notifications-history"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "notificationId"
  # Definicje atrybutów, które będą używane w kluczach.
  attribute {
    name = "notificationId"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "N" # 'N' oznacza Number (liczba).
  }
  attribute {
    name = "userId"
    type = "S"
  }
  # Definiujemy globalny indeks dodatkowy (GSI).
  # Pozwala on na efektywne wyszukiwanie rekordów po innym kluczu niż główny (tutaj: po userId i timestamp).
  global_secondary_index {
    name            = "userId-timestamp-index"
    hash_key        = "userId"
    range_key       = "timestamp" # Klucz sortujący.
    projection_type = "ALL" # Kopiuj wszystkie atrybuty do indeksu.
  }
  tags = local.common_tags
}

# --- Bucket S3 ---
# S3 (Simple Storage Service) to usługa do przechowywania obiektów (plików).

# Bucket do przechowywania plików wgrywanych przez użytkowników.
resource "aws_s3_bucket" "upload_bucket" {
  # Nazwa bucketa musi być globalnie unikalna, stąd dodajemy losowy sufiks.
  bucket        = "${local.project_name_prefix}-uploads-${random_string.suffix.result}"
  tags          = local.common_tags
  # Wymuś usunięcie bucketa nawet, jeśli nie jest pusty (dobre dla dev).
  force_destroy = true
}
# Blokada publicznego dostępu do bucketa. Ważne ze względów bezpieczeństwa.
resource "aws_s3_bucket_public_access_block" "upload_bucket_access_block" {
  bucket = aws_s3_bucket.upload_bucket.id
  # Blokuj publiczne listy kontroli dostępu (ACL).
  block_public_acls       = true
  # Blokuj publiczne polityki.
  block_public_policy     = true
  # Ignoruj publiczne ACL.
  ignore_public_acls      = true
  # Ogranicz publiczne buckety.
  restrict_public_buckets = true
}
# Bucket do przechowywania kodu funkcji Lambda (plików .jar).
resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket        = "${local.project_name_prefix}-lambda-code-${random_string.suffix.result}"
  tags          = local.common_tags
  force_destroy = true
}




# --- AWS Cognito ---
# Cognito to usługa do zarządzania tożsamością użytkowników (rejestracja, logowanie).

# Pula użytkowników (User Pool) to nasza baza użytkowników.
resource "aws_cognito_user_pool" "chat_pool" {
  name = "${local.project_name}-user-pool"
  # Konfiguracja Lambdy.
  lambda_config {
    # Wywołaj tę funkcję Lambda przed rejestracją użytkownika.
    # Używamy jej do automatycznego potwierdzania kont, żeby uprościć proces.
    pre_sign_up = aws_lambda_function.auto_confirm_user.arn
  }
  # Polityka haseł.
  password_policy {
    minimum_length    = 6
    require_lowercase = true
    require_numbers   = false # Uproszczone dla celów deweloperskich.
    require_symbols   = false
    require_uppercase = false
  }
  tags = local.common_tags
}
# Klient puli użytkowników (User Pool Client) to aplikacja, która ma dostęp do tej puli.
resource "aws_cognito_user_pool_client" "chat_pool_client" {
  name                = "${local.project_name}-client"
  user_pool_id        = aws_cognito_user_pool.chat_pool.id
  # Nie generuj sekretu klienta, bo nasza aplikacja działa po stronie klienta (w przeglądarce).
  generate_secret     = false
  # Określamy dozwolone przepływy uwierzytelniania.
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
}


# --- AWS SNS ---
# SNS (Simple Notification Service) to usługa do wysyłania powiadomień (np. push, SMS, e-mail).

# Tworzymy temat (topic) SNS. Nasz serwis powiadomień będzie publikował wiadomości na ten temat.
resource "aws_sns_topic" "notifications_topic" {
  name = "${local.project_name}-notifications-topic"
  tags = local.common_tags
}

# --- Kolejka SQS ---
# SQS (Simple Queue Service) to usługa kolejkowania wiadomości. Używamy jej do komunikacji między Lambdą a serwisem powiadomień.

resource "aws_sqs_queue" "chat_notifications_queue" {
  name                        = "${local.project_name}-chat-notifications-queue"
  # Opóźnienie dostarczenia wiadomości (w sekundach).
  delay_seconds               = 0
  # Jak długo wiadomość ma być przechowywana w kolejce (w sekundach).
  message_retention_seconds   = 345600 # 4 dni
  # Jak długo wiadomość jest niewidoczna dla innych konsumentów po pobraniu.
  visibility_timeout_seconds  = 60
  # Jak długo SQS ma czekać na nową wiadomość (long polling).
  receive_wait_time_seconds   = 10
  tags                        = local.common_tags
}

# --- Grupy Logów CloudWatch ---
# Tworzymy grupy logów dla każdej usługi Fargate, aby zbierać logi z kontenerów.

# Grupa logów dla auth-service.
resource "aws_cloudwatch_log_group" "auth_service_logs" {
  name              = "/ecs/${local.project_name}/${local.auth_service_name}"
  retention_in_days = 7
  tags              = local.common_tags
}
# Grupa logów dla file-service.
resource "aws_cloudwatch_log_group" "file_service_logs" {
  name              = "/ecs/${local.project_name}/${local.file_service_name}"
  retention_in_days = 7
  tags              = local.common_tags
}
# Grupa logów dla notification-service.
resource "aws_cloudwatch_log_group" "notification_service_logs" {
  name              = "/ecs/${local.project_name}/${local.notification_service_name}"
  retention_in_days = 7
  tags              = local.common_tags
}

# --- Zmienna dla istniejącej roli IAM ---
# Rola IAM to zbiór uprawnień. Zamiast tworzyć nową, używamy istniejącej roli 'LabRole', która ma szerokie uprawnienia (praktyka dla środowisk laboratoryjnych).
variable "lab_role_arn" {
  description = "ARN of the existing LabRole"
  type        = string
  # Domyślny ARN roli.
  default     = "arn:aws:iam::044902896603:role/LabRole"
}

# --- Definicje Zadań i Usługi ECS dla Fargate ---
# Definicja zadania (Task Definition) to jakby "szablon" dla uruchomienia kontenera - określa obraz, porty, zmienne środowiskowe itp.
resource "aws_ecs_task_definition" "app_fargate_task_definitions" {
  # Używamy pętli 'for_each' na mapie 'local.fargate_services', aby stworzyć definicję zadania dla każdej usługi.
  for_each = local.fargate_services
  # Nazwa rodziny definicji zadania. 'each.key' to nazwa usługi (np. "auth-service").
  family                   = "${local.project_name}-${each.key}-task"
  # Tryb sieciowy 'awsvpc' jest wymagany dla Fargate.
  network_mode             = "awsvpc"
  # Wymagamy kompatybilności z Fargate.
  requires_compatibilities = ["FARGATE"]
  # Ilość CPU alokowana dla zadania (1024 jednostki = 1 vCPU).
  cpu                      = "1024"
  # Ilość pamięci RAM alokowana dla zadania (w MB).
  memory                   = "2048"
  # Rola IAM używana przez ECS do pobrania obrazu i wysyłania logów.
  execution_role_arn       = var.lab_role_arn
  # Rola IAM używana przez aplikację wewnątrz kontenera do komunikacji z innymi usługami AWS.
  task_role_arn            = var.lab_role_arn
  # Definicje kontenerów w zadaniu. To jest serce definicji zadania.
  container_definitions = jsonencode([
    {
      # Nazwa kontenera.
      name      = "${each.key}-container"
      # Pełny adres obrazu Docker. 'each.value' odnosi się do wartości z mapy 'local.fargate_services'.
      image     = "${each.value.ecr_repo_base_url}:${each.value.image_tag}"
      # 'true' oznacza, że jeśli ten kontener się zatrzyma, całe zadanie zostanie zatrzymane.
      essential = true
      # Mapowanie portów.
      portMappings = [{ containerPort = each.value.port, hostPort = each.value.port, protocol = "tcp" }]
      # Zmienne środowiskowe dla kontenera.
      environment = each.value.environment_vars
      # Konfiguracja logowania.
      logConfiguration = {
        # Używamy sterownika 'awslogs' do wysyłania logów do CloudWatch.
        logDriver = "awslogs"
        # Opcje dla sterownika.
        options = {
          # Nazwa grupy logów.
          "awslogs-group"         = each.value.log_group_name
          # Region AWS.
          "awslogs-region"        = data.aws_region.current.name
          # Prefiks dla strumieni logów.
          "awslogs-stream-prefix" = "ecs-${each.key}"
        }
      }
    }
  ])
  tags = local.common_tags
}

# Usługa ECS (ECS Service) odpowiada za utrzymywanie określonej liczby działających instancji zadania (Task).
resource "aws_ecs_service" "app_fargate_services" {
  # Ponownie używamy pętli 'for_each'.
  for_each = local.fargate_services
  # Nazwa usługi.
  name            = "${local.project_name}-${each.key}-service"
  # ID klastra, w którym usługa ma działać.
  cluster         = aws_ecs_cluster.main_cluster.id
  # ARN definicji zadania, którą ma uruchamiać usługa.
  task_definition = aws_ecs_task_definition.app_fargate_task_definitions[each.key].arn
  # Typ uruchomienia - Fargate (serverless).
  launch_type     = "FARGATE"
  # Chcemy, żeby zawsze działała 1 instancja zadania.
  desired_count   = 1
  # Czas (w sekundach) na to, by nowo uruchomione zadanie stało się "zdrowe", zanim stare zostanie usunięte.
  health_check_grace_period_seconds = 120
  # Konfiguracja sieciowa.
  network_configuration {
    # Podsieci, w których mogą być uruchamiane zadania.
    subnets          = data.aws_subnets.default.ids
    # Grupa bezpieczeństwa dla zadań.
    security_groups  = [aws_security_group.internal_sg.id]
    # 'true' oznacza, że każde zadanie dostanie publiczny adres IP.
    assign_public_ip = true
  }
  # Konfiguracja Load Balancera.
  load_balancer {
    # ARN grupy docelowej, do której zadania mają być rejestrowane.
    target_group_arn = each.value.target_group_arn
    # Nazwa kontenera w zadaniu, który obsługuje ruch.
    container_name   = "${each.key}-container"
    # Port kontenera.
    container_port   = each.value.port
  }
  # Mechanizm "circuit breaker" do automatycznego wycofywania nieudanych wdrożeń.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  # Używamy domyślnego kontrolera wdrożeń ECS.
  deployment_controller { type = "ECS" }
  # 'depends_on' zapewnia, że usługa ECS będzie tworzona dopiero po utworzeniu wszystkich zasobów, od których zależy.
  # To zapobiega błędom podczas pierwszego wdrożenia.
  depends_on = [
    aws_lb_listener_rule.auth_rule,
    aws_lb_listener_rule.file_rule,
    aws_lb_listener_rule.notification_rule,
    aws_db_instance.chat_db,
    aws_s3_bucket.upload_bucket,
    aws_dynamodb_table.file_metadata_table,
    aws_sns_topic.notifications_topic,
    aws_dynamodb_table.notifications_history_table,
    aws_dynamodb_table.user_profiles_table,
    aws_sqs_queue.chat_notifications_queue,
    aws_lb_listener_rule.frontend_rule,
  ]
  tags = local.common_tags
}


# --- Automatyczne Skalowanie Usług ECS ---
# Konfigurujemy automatyczne skalowanie, aby dodawać lub usuwać instancje usług w odpowiedzi na obciążenie.

# Cel skalowania (Scaling Target) określa, co chcemy skalować i jakie są limity.
resource "aws_appautoscaling_target" "app_fargate_scaling_targets" {
  for_each = local.fargate_services
  # Maksymalna liczba instancji zadania.
  max_capacity       = 2
  # Minimalna liczba instancji zadania.
  min_capacity       = 1
  # ID zasobu do skalowania (naszej usługi ECS).
  resource_id        = "service/${aws_ecs_cluster.main_cluster.name}/${aws_ecs_service.app_fargate_services[each.key].name}"
  # Wymiar skalowania - liczba zadań w usłudze.
  scalable_dimension = "ecs:service:DesiredCount"
  # Przestrzeń nazw usługi.
  service_namespace  = "ecs"
}
# Polityka skalowania (Scaling Policy) określa, kiedy skalowanie ma nastąpić.
resource "aws_appautoscaling_policy" "app_fargate_cpu_scaling_policies" {
  for_each = local.fargate_services
  name               = "${local.project_name}-${each.key}-cpu-scaling"
  # Typ polityki: śledzenie celu (Target Tracking).
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.app_fargate_scaling_targets[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.app_fargate_scaling_targets[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.app_fargate_scaling_targets[each.key].service_namespace
  # Konfiguracja śledzenia celu.
  target_tracking_scaling_policy_configuration {
    # Używamy predefiniowanej metryki.
    predefined_metric_specification {
      # Średnie zużycie CPU przez usługę.
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    # Cel: utrzymuj średnie zużycie CPU na poziomie 75%. Jeśli wzrośnie, dodaj instancje. Jeśli spadnie, usuń.
    target_value       = 75.0
    # Czas "uspokojenia" po skalowaniu w dół (w sekundach).
    scale_in_cooldown  = 300
    # Czas "uspokojenia" po skalowaniu w górę (w sekundach).
    scale_out_cooldown = 60
  }
}

# --- Funkcja Lambda do automatycznego potwierdzania użytkowników Cognito ---
resource "aws_lambda_function" "auto_confirm_user" {
  function_name = "${local.project_name}-auto-confirm-user"
  # Środowisko uruchomieniowe.
  runtime       = "python3.9"
  # Nazwa pliku i funkcji, która ma być wywołana.
  handler       = "auto_confirm_user.lambda_handler"
  # Rola IAM z uprawnieniami.
  role          = var.lab_role_arn
  # Ścieżka do spakowanego kodu Lambdy.
  filename         = "${path.module}/lambda/auto_confirm_user.zip"
  # Skrót (hash) pliku z kodem. Zmiana kodu spowoduje aktualizację Lambdy.
  source_code_hash = filebase64sha256(length(fileset(path.module, "lambda/auto_confirm_user.zip")) > 0 ? "${path.module}/lambda/auto_confirm_user.zip" : "dummy")
  tags             = local.common_tags
}
# Uprawnienie dla Cognito do wywoływania naszej funkcji Lambda.
resource "aws_lambda_permission" "allow_cognito" {
  statement_id  = "AllowCognitoToCallLambda"
  # Akcja, na którą zezwalamy.
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_confirm_user.function_name
  # Kto może wywoływać (principal) - usługa Cognito.
  principal     = "cognito-idp.amazonaws.com"
  # Z jakiego źródła (ARN naszej puli użytkowników).
  source_arn    = aws_cognito_user_pool.chat_pool.arn
}

# --- Definicje funkcji Lambda dla logiki czatu ---
# Tworzymy funkcje Lambda, które będą obsługiwać logikę biznesową czatu.
# WAŻNE: Początkowo wdrażamy je z "zaślepką" (dummy zip), a prawdziwy kod .jar jest wgrywany przez skrypt deploy.sh.

# Lambda do wysyłania wiadomości.
resource "aws_lambda_function" "send_message_lambda" {
  function_name = "${local.project_name}-SendMessageLambda"
  # Handler w kodzie Javy (ścieżka do klasy i metody).
  handler       = "pl.projektchmury.chatapp.lambda.SendMessageLambda::handleRequest"
  role          = var.lab_role_arn
  runtime       = "java17"
  memory_size   = 512
  timeout       = 30
  # Początkowo używamy "zaślepki".
  filename         = data.archive_file.dummy_lambda_zip.output_path
  source_code_hash = data.archive_file.dummy_lambda_zip.output_base64sha256
  # Używamy wspólnych zmiennych środowiskowych.
  environment { variables = local.chat_lambda_common_environment_variables }
  # Konfiguracja VPC, aby Lambda mogła połączyć się z bazą danych RDS.
  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.internal_sg.id]
  }
  tags = local.common_tags
  # Mówimy Terraformowi, aby ignorował zmiany w pliku i jego hashu, ponieważ będą one zarządzane przez skrypt deploy.sh.
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}
# Lambda do pobierania wysłanych wiadomości.
resource "aws_lambda_function" "get_sent_messages_lambda" {
  function_name = "${local.project_name}-GetSentMessagesLambda"
  handler       = "pl.projektchmury.chatapp.lambda.GetSentMessagesLambda::handleRequest"
  role          = var.lab_role_arn
  runtime       = "java17"
  memory_size   = 256
  timeout       = 20
  filename         = data.archive_file.dummy_lambda_zip.output_path
  source_code_hash = data.archive_file.dummy_lambda_zip.output_base64sha256
  environment { variables = local.chat_lambda_common_environment_variables }
  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.internal_sg.id]
  }
  tags = local.common_tags
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}
# Lambda do pobierania otrzymanych wiadomości.
resource "aws_lambda_function" "get_received_messages_lambda" {
  function_name = "${local.project_name}-GetReceivedMessagesLambda"
  handler       = "pl.projektchmury.chatapp.lambda.GetReceivedMessagesLambda::handleRequest"
  role          = var.lab_role_arn
  runtime       = "java17"
  memory_size   = 256
  timeout       = 20
  filename         = data.archive_file.dummy_lambda_zip.output_path
  source_code_hash = data.archive_file.dummy_lambda_zip.output_base64sha256
  environment { variables = local.chat_lambda_common_environment_variables }
  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids # <<< POPRAWKA
    security_group_ids = [aws_security_group.internal_sg.id]
  }
  tags = local.common_tags
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}
# Lambda do oznaczania wiadomości jako przeczytane.
resource "aws_lambda_function" "mark_message_as_read_lambda" {
  function_name = "${local.project_name}-MarkMessageAsReadLambda"
  handler       = "pl.projektchmury.chatapp.lambda.MarkMessageAsReadLambda::handleRequest"
  role          = var.lab_role_arn
  runtime       = "java17"
  memory_size   = 256
  timeout       = 20
  filename         = data.archive_file.dummy_lambda_zip.output_path
  source_code_hash = data.archive_file.dummy_lambda_zip.output_base64sha256
  environment { variables = local.chat_lambda_common_environment_variables }
  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids # <<< POPRAWKA
    security_group_ids = [aws_security_group.internal_sg.id]
  }
  tags = local.common_tags
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,

    ]
  }
}

# --- API Gateway dla funkcji Lambda czatu ---
# API Gateway to usługa, która tworzy API RESTful przed naszymi funkcjami Lambda, wystawiając je na świat.

# Tworzymy nowe API REST.
resource "aws_api_gateway_rest_api" "chat_api" {
  name        = "${local.project_name}-ChatApi"
  description = "API Gateway for Chat Lambdas"
  tags        = local.common_tags
  # Typ 'REGIONAL' jest standardowym wyborem.
  endpoint_configuration { types = ["REGIONAL"] }
}
# Tworzymy "autoryzator" (authorizer), który będzie weryfikował tokeny JWT od Cognito.
# Każde zapytanie do zabezpieczonego endpointu będzie musiało mieć poprawny token.
resource "aws_api_gateway_authorizer" "cognito_authorizer_for_chat_api" {
  name                              = "${local.project_name}-CognitoChatAuthorizer"
  rest_api_id                       = aws_api_gateway_rest_api.chat_api.id
  # Typ autoryzatora.
  type                              = "COGNITO_USER_POOLS"
  # Wskazujemy, której puli użytkowników ma używać.
  provider_arns                     = [aws_cognito_user_pool.chat_pool.arn]
  # Mówimy mu, gdzie ma szukać tokena (w nagłówku 'Authorization').
  identity_source                   = "method.request.header.Authorization"
  # Jak długo wynik autoryzacji ma być przechowywany w pamięci podręcznej (w sekundach).
  authorizer_result_ttl_in_seconds  = 300
}
# Tworzymy zasób (resource), czyli ścieżkę w naszym API, np. /messages.
resource "aws_api_gateway_resource" "messages_resource" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  # "Rodzicem" jest główny zasób API (root).
  parent_id   = aws_api_gateway_rest_api.chat_api.root_resource_id
  # Nazwa ścieżki.
  path_part   = "messages"
}
# Tworzymy metodę HTTP (np. POST) dla tego zasobu.
resource "aws_api_gateway_method" "send_message_post_method" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.messages_resource.id
  http_method   = "POST"
  # Wymagaj autoryzacji przez Cognito.
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer_for_chat_api.id
}

# Tworzymy integrację między metodą API a funkcją Lambda.
# To jest "klej", który mówi API Gateway, żeby po otrzymaniu zapytania POST na /messages wywołał naszą Lambdę.
resource "aws_api_gateway_integration" "send_message_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.chat_api.id
  resource_id             = aws_api_gateway_resource.messages_resource.id
  http_method             = aws_api_gateway_method.send_message_post_method.http_method
  # Metoda HTTP używana do wywołania backendu (Lambdy).
  integration_http_method = "POST"
  # Typ integracji 'AWS_PROXY' przekazuje całe zapytanie do Lambdy i zwraca jej odpowiedź. To najprostszy i najczęstszy sposób.
  type                    = "AWS_PROXY"
  # ARN funkcji Lambda, którą chcemy wywołać.
  uri                     = aws_lambda_function.send_message_lambda.invoke_arn
}
# Uprawnienie dla API Gateway do wywoływania tej konkretnej funkcji Lambda.
resource "aws_lambda_permission" "apigw_lambda_send_message" {
  statement_id  = "AllowAPIGatewayInvokeSendMessageLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_message_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  # 'source_arn' precyzyjnie określa, która metoda w API może wywołać Lambdę.
  source_arn    = "${aws_api_gateway_rest_api.chat_api.execution_arn}/*/${aws_api_gateway_method.send_message_post_method.http_method}${aws_api_gateway_resource.messages_resource.path}"
}

# (Poniższe bloki są analogiczne dla pozostałych endpointów API, więc komentarze będą skrócone)

# Zasób /messages/sent
resource "aws_api_gateway_resource" "messages_sent_resource" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  parent_id   = aws_api_gateway_resource.messages_resource.id
  path_part   = "sent"
}
# Metoda GET dla /messages/sent
resource "aws_api_gateway_method" "get_sent_messages_method" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.messages_sent_resource.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer_for_chat_api.id
  # Określamy, że ta metoda oczekuje parametru 'username' w zapytaniu (query string).
  request_parameters = { "method.request.querystring.username" = true }
}
# Integracja z Lambdą get_sent_messages
resource "aws_api_gateway_integration" "get_sent_messages_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.chat_api.id
  resource_id             = aws_api_gateway_resource.messages_sent_resource.id
  http_method             = aws_api_gateway_method.get_sent_messages_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_sent_messages_lambda.invoke_arn
}
# Uprawnienie dla API Gateway
resource "aws_lambda_permission" "apigw_lambda_get_sent_messages" {
  statement_id  = "AllowAPIGatewayInvokeGetSentMessagesLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_sent_messages_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chat_api.execution_arn}/*/${aws_api_gateway_method.get_sent_messages_method.http_method}${aws_api_gateway_resource.messages_sent_resource.path}"
}

# Zasób /messages/received
resource "aws_api_gateway_resource" "messages_received_resource" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  parent_id   = aws_api_gateway_resource.messages_resource.id
  path_part   = "received"
}
# Metoda GET dla /messages/received
resource "aws_api_gateway_method" "get_received_messages_method" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.messages_received_resource.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer_for_chat_api.id
  request_parameters = { "method.request.querystring.username" = true }
}
# Integracja z Lambdą get_received_messages
resource "aws_api_gateway_integration" "get_received_messages_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.chat_api.id
  resource_id             = aws_api_gateway_resource.messages_received_resource.id
  http_method             = aws_api_gateway_method.get_received_messages_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_received_messages_lambda.invoke_arn
}
# Uprawnienie dla API Gateway
resource "aws_lambda_permission" "apigw_lambda_get_received_messages" {
  statement_id  = "AllowAPIGatewayInvokeGetReceivedMessagesLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_received_messages_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chat_api.execution_arn}/*/${aws_api_gateway_method.get_received_messages_method.http_method}${aws_api_gateway_resource.messages_received_resource.path}"
}
# Zasób /messages/{messageId} (parametr w ścieżce)
resource "aws_api_gateway_resource" "message_id_resource" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  parent_id   = aws_api_gateway_resource.messages_resource.id
  path_part   = "{messageId}"
}
# Zasób /messages/{messageId}/mark-as-read
resource "aws_api_gateway_resource" "mark_as_read_resource" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  parent_id   = aws_api_gateway_resource.message_id_resource.id
  path_part   = "mark-as-read"
}
# Metoda POST dla /mark-as-read
resource "aws_api_gateway_method" "mark_as_read_method" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.mark_as_read_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer_for_chat_api.id
  # Oczekujemy parametru 'messageId' w ścieżce.
  request_parameters = { "method.request.path.messageId" = true }
}
# Integracja z Lambdą mark_message_as_read
resource "aws_api_gateway_integration" "mark_as_read_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.chat_api.id
  resource_id             = aws_api_gateway_resource.mark_as_read_resource.id
  http_method             = aws_api_gateway_method.mark_as_read_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.mark_message_as_read_lambda.invoke_arn
}
# Uprawnienie dla API Gateway
resource "aws_lambda_permission" "apigw_lambda_mark_as_read" {
  statement_id  = "AllowAPIGatewayInvokeMarkAsReadLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mark_message_as_read_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chat_api.execution_arn}/*/${aws_api_gateway_method.mark_as_read_method.http_method}${aws_api_gateway_resource.mark_as_read_resource.path}"
}


# --- Metody OPTIONS dla CORS ---
# CORS (Cross-Origin Resource Sharing) to mechanizm, który pozwala przeglądarkom na wysyłanie zapytań do API hostowanego na innej domenie.
# Przeglądarka najpierw wysyła zapytanie "sprawdzające" metodą OPTIONS. Musimy na nie poprawnie odpowiedzieć.

# Metoda OPTIONS dla zasobu /messages
resource "aws_api_gateway_method" "messages_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.messages_resource.id
  http_method   = "OPTIONS"
  # Nie wymaga autoryzacji.
  authorization = "NONE"
}
# Integracja typu 'MOCK' dla metody OPTIONS.
# Zamiast wywoływać Lambdę, API Gateway od razu zwraca predefiniowaną odpowiedź.
resource "aws_api_gateway_integration" "messages_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.messages_resource.id
  http_method = aws_api_gateway_method.messages_options_method.http_method
  type        = "MOCK"
  # Szablon żądania, który zwraca status 200.
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}
# Definicja odpowiedzi dla metody OPTIONS.
resource "aws_api_gateway_method_response" "messages_options_200" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.messages_resource.id
  http_method   = aws_api_gateway_method.messages_options_method.http_method
  status_code   = "200"
  response_models = {
    "application/json" = "Empty"
  }
  # Definiujemy, które nagłówki CORS będą w odpowiedzi.
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}
# Konfiguracja odpowiedzi z integracji MOCK.
resource "aws_api_gateway_integration_response" "messages_options_integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.messages_resource.id
  http_method = aws_api_gateway_method.messages_options_method.http_method
  status_code = aws_api_gateway_method_response.messages_options_200.status_code
  # Ustawiamy konkretne wartości nagłówków CORS.
  response_parameters = {
    # Dozwolone nagłówki.
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    # Dozwolone metody HTTP.
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    # Dozwolone źródła (domeny). '*' oznacza dowolne.
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  response_templates = {
    "application/json" = "" # Puste ciało odpowiedzi.
  }
  # Zapewnia, że ten zasób jest tworzony po integracji.
  depends_on = [aws_api_gateway_integration.messages_options_integration]
}
# Dla zasobu /messages/sent
resource "aws_api_gateway_method" "messages_sent_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.messages_sent_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "messages_sent_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.messages_sent_resource.id
  http_method = aws_api_gateway_method.messages_sent_options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "messages_sent_options_200" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.messages_sent_resource.id
  http_method   = aws_api_gateway_method.messages_sent_options_method.http_method
  status_code   = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}
resource "aws_api_gateway_integration_response" "messages_sent_options_integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.messages_sent_resource.id
  http_method = aws_api_gateway_method.messages_sent_options_method.http_method
  status_code = aws_api_gateway_method_response.messages_sent_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  response_templates = {
    "application/json" = ""
  }
  depends_on = [aws_api_gateway_integration.messages_sent_options_integration]
}
# Dla zasobu /messages/received
resource "aws_api_gateway_method" "messages_received_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.messages_received_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "messages_received_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.messages_received_resource.id
  http_method = aws_api_gateway_method.messages_received_options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}
resource "aws_api_gateway_method_response" "messages_received_options_200" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.messages_received_resource.id
  http_method   = aws_api_gateway_method.messages_received_options_method.http_method
  status_code   = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}
resource "aws_api_gateway_integration_response" "messages_received_options_integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.messages_received_resource.id
  http_method = aws_api_gateway_method.messages_received_options_method.http_method
  status_code = aws_api_gateway_method_response.messages_received_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  response_templates = {
    "application/json" = ""
  }
  depends_on = [aws_api_gateway_integration.messages_received_options_integration]
}
# Dla zasobu /messages/{id}/mark-as-read
resource "aws_api_gateway_method" "mark_as_read_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.mark_as_read_resource.id # Upewnij się, że to poprawny resource_id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "mark_as_read_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.mark_as_read_resource.id # Upewnij się, że to poprawny resource_id
  http_method = aws_api_gateway_method.mark_as_read_options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}
resource "aws_api_gateway_method_response" "mark_as_read_options_200" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.mark_as_read_resource.id
  http_method   = aws_api_gateway_method.mark_as_read_options_method.http_method
  status_code   = "200"
  response_models = { "application/json" = "Empty" }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}
resource "aws_api_gateway_integration_response" "mark_as_read_options_integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.mark_as_read_resource.id
  http_method = aws_api_gateway_method.mark_as_read_options_method.http_method
  status_code = aws_api_gateway_method_response.mark_as_read_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    # "method.response.header.Access-Control-Allow-Origin"  = "'http://${aws_elastic_beanstalk_environment.frontend_env.cname}'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  response_templates = {
    "application/json" = ""
  }
  depends_on = [aws_api_gateway_integration.mark_as_read_options_integration]
}

# --- DB Schema Initializer Lambda ---

# Zmienna dla nazwy pliku .jar z kodem inicjalizującym bazę danych.
variable "db_initializer_jar_key" {
  description = "S3 key for the DB Initializer Lambda JAR file"
  type        = string
  default     = "db-initializer-lambda.jar"
}

# Definicja funkcji Lambda do inicjalizacji schematu bazy danych.
# Ta funkcja jest uruchamiana raz przez skrypt deploy.sh, aby stworzyć tabele w bazie RDS.
resource "aws_lambda_function" "db_initializer_lambda" {
  # Upewnij się, że ta funkcja jest tworzona dopiero po utworzeniu bazy danych.
  depends_on = [aws_db_instance.chat_db]

  function_name = "${local.project_name}-DbSchemaInitializer"
  handler       = "pl.projektchmury.dbinitializer.SchemaInitializerLambda::handleRequest"
  role          = var.lab_role_arn
  runtime       = "java17"
  memory_size   = 1024
  timeout       = 300 # Dajemy więcej czasu na zimny start i połączenie z DB.
  filename         = data.archive_file.dummy_lambda_zip.output_path
  source_code_hash = data.archive_file.dummy_lambda_zip.output_base64sha256

  # Używamy tych samych zmiennych środowiskowych co inne Lambdy czatu, żeby wiedziała, jak połączyć się z DB.
  environment {
    variables = local.chat_lambda_common_environment_variables
  }

  # Ta funkcja również musi być w VPC, aby połączyć się z RDS.
  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.internal_sg.id]
  }

  tags = local.common_tags
  # Ponownie ignorujemy zmiany w kodzie, bo jest zarządzany przez deploy.sh.
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}

# --- VPC Endpoint dla SQS ---
# Pozwala zasobom wewnątrz VPC (jak nasze Lambdy) komunikować się z SQS
# bez potrzeby posiadania dostępu do publicznego internetu (przez NAT Gateway). Jest to bezpieczniejsze i szybsze.
resource "aws_vpc_endpoint" "sqs_endpoint" {
  vpc_id       = data.aws_vpc.default.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.sqs"   # Nazwa usługi SQS dla danego regionu.
  vpc_endpoint_type = "Interface" # Typ 'Interface' tworzy interfejs sieciowy w podsieciach

  subnet_ids = data.aws_subnets.default.ids
  security_group_ids = [aws_security_group.internal_sg.id] # Używamy tej samej grupy bezpieczeństwa co inne zasoby wewnętrzne.

  private_dns_enabled = true # Włączamy prywatny DNS, aby można było używać standardowych adresów SQS.
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-sqs-vpc-endpoint"
  })
}

# Wdrożenie (Deployment) API Gateway.
# To jest jak "opublikowanie" zmian, które zrobiliśmy w API.
resource "aws_api_gateway_deployment" "chat_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  # 'triggers' to sprytny sposób na wymuszenie nowego wdrożenia, gdy cokolwiek w API się zmieni.
  # Obliczamy hash z ID wszystkich ważnych zasobów API. Jeśli hash się zmieni, Terraform stworzy nowe wdrożenie.
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.messages_resource.id,
      aws_api_gateway_method.send_message_post_method.id,
      aws_api_gateway_integration.send_message_lambda_integration.id,
      aws_api_gateway_resource.messages_sent_resource.id,
      aws_api_gateway_method.get_sent_messages_method.id,
      aws_api_gateway_integration.get_sent_messages_lambda_integration.id,
      aws_api_gateway_resource.messages_received_resource.id,
      aws_api_gateway_method.get_received_messages_method.id,
      aws_api_gateway_integration.get_received_messages_lambda_integration.id,
      aws_api_gateway_resource.message_id_resource.id,
      aws_api_gateway_resource.mark_as_read_resource.id,
      aws_api_gateway_method.mark_as_read_method.id,
      aws_api_gateway_integration.mark_as_read_lambda_integration.id,
      # Metody OPTIONS
      aws_api_gateway_method.messages_options_method.id,
      aws_api_gateway_integration.messages_options_integration.id,
      aws_api_gateway_integration_response.messages_options_integration_response_200.id, # DODANE
      aws_api_gateway_method.messages_sent_options_method.id,
      aws_api_gateway_integration.messages_sent_options_integration.id,
      aws_api_gateway_integration_response.messages_sent_options_integration_response_200.id, # DODANE
      aws_api_gateway_method.messages_received_options_method.id,
      aws_api_gateway_integration.messages_received_options_integration.id,
      aws_api_gateway_integration_response.messages_received_options_integration_response_200.id, # DODANE
      aws_api_gateway_method.mark_as_read_options_method.id,
      aws_api_gateway_integration.mark_as_read_options_integration.id,
      aws_api_gateway_integration_response.mark_as_read_options_integration_response_200.id # DODANE
    ]))
  }
  lifecycle { create_before_destroy = true } # Zapewnia, że nowe wdrożenie jest tworzone, zanim stare zostanie usunięte.
  depends_on = [ # Zależność od wszystkich integracji, aby upewnić się, że są stworzone przed wdrożeniem.
    aws_api_gateway_integration.send_message_lambda_integration,
    aws_api_gateway_integration.get_sent_messages_lambda_integration,
    aws_api_gateway_integration.get_received_messages_lambda_integration,
    aws_api_gateway_integration.mark_as_read_lambda_integration,
    aws_api_gateway_integration.messages_options_integration,
    aws_api_gateway_integration.messages_sent_options_integration,
    aws_api_gateway_integration.messages_received_options_integration,
    aws_api_gateway_integration.mark_as_read_options_integration
  ]
}

# Etap (Stage) wdrożenia. To jest jak nazwana wersja wdrożenia, np. "v1", "prod", "dev".
resource "aws_api_gateway_stage" "chat_api_stage_v1" {
  deployment_id = aws_api_gateway_deployment.chat_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  stage_name    = "v1" # Nazwa etapu, która staje się częścią adresu URL.
  tags          = local.common_tags
}

# --- Wyjścia (Outputs) ---
# 'output' to sposób, w jaki Terraform zwraca informacje o stworzonych zasobach.
# Skrypt deploy.sh będzie używał tych wartości do dalszej konfiguracji.
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main_alb.dns_name
}

output "frontend_url" {
  description = "URL of the deployed frontend application (ALB)"
  value       = "http://${aws_lb.main_alb.dns_name}" # Teraz frontend jest dostępny pod adresem ALB
}

output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.chat_pool.id
}

output "cognito_client_id" {
  description = "Client ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.chat_pool_client.id
}

output "s3_upload_bucket_name" {
  description = "Name of the S3 bucket for file uploads"
  value       = aws_s3_bucket.upload_bucket.bucket
}

output "s3_lambda_code_bucket_name" {
  description = "Name of the S3 bucket for Lambda function code"
  value       = aws_s3_bucket.lambda_code_bucket.id
}

output "rds_chat_db_endpoint" {
  description = "Endpoint address of the RDS database for chat service"
  value       = aws_db_instance.chat_db.address
}

output "rds_chat_db_name" {
  description = "Name of the RDS database for chat service"
  value       = aws_db_instance.chat_db.db_name
}

output "sns_notifications_topic_arn" {
  description = "ARN of the SNS topic for notifications"
  value       = aws_sns_topic.notifications_topic.arn
}

output "sqs_chat_notifications_queue_url" {
  description = "URL of the SQS queue for chat notifications"
  value       = aws_sqs_queue.chat_notifications_queue.id
}

output "sqs_chat_notifications_queue_arn" {
  description = "ARN of the SQS queue for chat notifications"
  value       = aws_sqs_queue.chat_notifications_queue.arn
}

output "api_gateway_chat_invoke_url" {
  description = "Invoke URL for the Chat API Gateway (stage v1)"
  value       = aws_api_gateway_stage.chat_api_stage_v1.invoke_url
}

output "ecr_auth_service_repo_url" {
  value = aws_ecr_repository.auth_service_repo.repository_url
}

output "ecr_file_service_repo_url" {
  value = aws_ecr_repository.file_service_repo.repository_url
}

output "ecr_notification_service_repo_url" {
  value = aws_ecr_repository.notification_service_repo.repository_url
}

output "ecr_frontend_repo_url" {
  value = aws_ecr_repository.frontend_repo.repository_url
}
output "db_initializer_lambda_function_name" {
  description = "The name of the DB schema initializer Lambda function"
  value       = aws_lambda_function.db_initializer_lambda.function_name
}
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main_cluster.name
}

# output "eb_environment_name" {
#   description = "Name of the Elastic Beanstalk environment"
#   value       = aws_elastic_beanstalk_environment.frontend_env.name
# }
output "ecs_service_names" {
  description = "A map of ECS service names"
  value = {
    for name, service in aws_ecs_service.app_fargate_services :
    name => service.name
  }
}
# Zwraca nazwy funkcji Lambda, aby skrypt deploy.sh wiedział, które funkcje zaktualizować.
output "send_message_lambda_name" {
  value = aws_lambda_function.send_message_lambda.function_name
}
output "get_sent_messages_lambda_name" {
  value = aws_lambda_function.get_sent_messages_lambda.function_name
}
output "get_received_messages_lambda_name" {
  value = aws_lambda_function.get_received_messages_lambda.function_name
}
output "mark_message_as_read_lambda_name" {
  value = aws_lambda_function.mark_message_as_read_lambda.function_name
}
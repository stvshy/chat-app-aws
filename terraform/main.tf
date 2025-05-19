# --- Konfiguracja dostawcy AWS ---
provider "aws" {
  region = "us-east-1" # Mówimy Terraformowi, że chcemy tworzyć rzeczy w regionie AWS "us-east-1"
}

# --- Zmienne wejściowe dla tagów obrazów Docker ---
# Te zmienne pozwalają nam łatwo zmieniać wersje (tagi) obrazów Docker dla każdego serwisu bez modyfikowania reszty kodu
variable "auth_service_image_tag" {
  description = "Docker image tag for auth-service"   # Opis tej zmiennej
  type        = string   # Typ zmiennej to tekst (string)
  default     = "v1.0.1"  # Domyślna wersja obrazu dla serwisu autoryzacji
}
variable "chat_service_image_tag" {
  description = "Docker image tag for chat-service"  # Opis
  type        = string  # Typ: tekst
  default     = "v1.0.0"  # Domyślna wersja obrazu dla serwisu czatu
}
variable "file_service_image_tag" {
  description = "Docker image tag for file-service"  # Opis
  type        = string  # Typ: tekst
  default     = "v1.0.0"  # Domyślna wersja obrazu dla serwisu plików
}
variable "notification_service_image_tag" {
  description = "Docker image tag for notification-service"
  type        = string
  default     = "v1.0.0"  # Domyślna wersja obrazu dla serwisu notyfikacji
}
variable "frontend_image_tag" {
  description = "Docker image tag for frontend"
  type        = string
  default     = "v1.0.1"  # Domyślna wersja obrazu dla frontendu
}

# --- Generowanie losowego ciągu znaków ---
# S3 i ECR wymagają unikalnych nazw, więc dodajemy do nich losowy ciąg znaków
resource "random_string" "suffix" {  # Tworzymy zasób, który wygeneruje losowy ciąg znaków
  length  = 4  # Chcemy, żeby miał 4 znaki
  special = false  # Bez znaków specjalnych (np. !, @, #)
  upper   = false  # Bez wielkich liter
}

# --- Lokalne zmienne (ułatwiające życie) ---
# 'locals' to takie nasze wewnętrzne prywatne predefiniowane wartości, których możemy używać w reszcie pliku
locals {  # Używamy ich, żeby nie powtarzać tych samych wartości w wielu miejscach
  project_name_prefix = "projekt-chmury-v2"  # Główny przedrostek nazwy naszego projektu
  project_name        = "${local.project_name_prefix}-${random_string.suffix.result}"  # Pełna, unikalna nazwa projektu (przedrostek + losowa końcówka)

  common_tags = {                                 # Zestaw wspólnych tagów (etykiet) dla wszystkich zasobów w AWS. Są widoczne w konsoli AWS
    Project     = local.project_name_prefix       # Tag "Project" z wartością naszego przedrostka.
    Environment = "dev"                           # Tag "Environment" ustawiony na "dev" (deweloperskie).
    Suffix      = random_string.suffix.result     # Tag "Suffix" z wartością losowej końcówki.
  }
  # Nazwy naszych serwisów (żeby nie pisać ich ciągle od nowa)
  auth_service_name         = "auth-service"
  chat_service_name         = "chat-service"
  file_service_name         = "file-service"
  notification_service_name = "notification-service"
  frontend_name             = "frontend"

  # --- Konfiguracja dla każdego serwisu Fargate ---
  # To jest "mapa" (słownik), gdzie kluczem jest nazwa serwisu, a wartością jest jego konfiguracja.
  # Dzięki temu możemy łatwo zarządzać wszystkimi serwisami backendowymi w jednym miejscu.
  fargate_services = {
    (local.auth_service_name) = {  # Konfiguracja dla serwisu autoryzacji
      port               = 8081    # Na jakim porcie działa ten serwis w kontenerze.
      ecr_repo_base_url  = aws_ecr_repository.auth_service_repo.repository_url   # Adres URL repozytorium ECR (gdzie trzymamy obraz Docker) dla tego serwisu
      image_tag          = var.auth_service_image_tag  # Wersja (tag) obrazu Docker dla tego serwisu (pobrana ze zmiennej)
      log_group_name     = aws_cloudwatch_log_group.auth_service_logs.name  # Nazwa grupy logów w CloudWatch dla tego serwisu
      # ARN (Amazon Resource Name) to unikalny identyfikator DOWOLNEGO zasobu w AWS, to jak numer PESEL dla każdego zasobu w AWS
      target_group_arn   = aws_lb_target_group.auth_tg.arn  # ARN (unikalny identyfikator) grupy docelowej w Load Balancerze dla tego serwisu
      environment_vars   = [   # Lista zmiennych środowiskowych przekazywanych do kontenera
        { name = "SPRING_PROFILES_ACTIVE", value = "aws" },   # Ustawia aktywny profil Spring na "aws": mówi aplikacji Spring Boot: "Hej, teraz działasz w środowisku 'aws', więc załaduj odpowiednią konfigurację
        { name = "AWS_REGION", value = data.aws_region.current.name },  # Przekazuje aktualny region AWS.
        { name = "AWS_COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.chat_pool.id }, # ID puli użytkowników Cognito.
        { name = "AWS_COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.chat_pool_client.id }, # ID klienta aplikacji Cognito.
        { name = "SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI", value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.chat_pool.id}" }, # Adres URL wystawcy tokenów JWT Cognito.
        { name = "AWS_DYNAMODB_TABLE_NAME_USER_PROFILES", value = aws_dynamodb_table.user_profiles_table.name }, # Nazwa tabeli DynamoDB dla profili użytkowników.
        { name = "APP_CORS_ALLOWED_ORIGIN_FRONTEND", value = "http://${aws_elastic_beanstalk_environment.frontend_env.cname}" } # Adres URL frontendu, który może wysyłać żądania (ważne dla CORS).
        # CORS (Cross-Origin Resource Sharing): To jest mechanizm bezpieczeństwa w przeglądarkach internetowych.
        # Domyślnie przeglądarka nie pozwala stronie internetowej załadowanej z jednego adresu (np. moj-frontend.com) wysyłać żądań (np. pobierać danych) do serwera na zupełnie innym adresie (np. moj-backend-api.com). To ochrona przed złośliwymi stronami.
        # Moje aplikacje Spring Boot (w SecurityConfig.java) używają tej zmiennej, aby powiedzieć przeglądarce: "Spokojnie, żądania przychodzące z tego konkretnego adresu frontendu są dozwolone. Możesz je przepuścić.
      ]
      depends_on_db      = false # Czy ten serwis zależy od bazy danych RDS? Nie.
      depends_on_s3_ddb  = false # Czy ten serwis zależy od S3 lub DynamoDB (innych niż user_profiles)? Nie.
      depends_on_sns_ddb = false # Czy ten serwis zależy od SNS lub DynamoDB (innych niż user_profiles)? Nie.
    },
    (local.chat_service_name) = { # Konfiguracja dla serwisu czatu.
      port               = 8082
      ecr_repo_base_url  = aws_ecr_repository.chat_service_repo.repository_url
      image_tag          = var.chat_service_image_tag
      log_group_name     = aws_cloudwatch_log_group.chat_service_logs.name
      target_group_arn   = aws_lb_target_group.chat_tg.arn
      environment_vars   = [
        { name = "SPRING_PROFILES_ACTIVE", value = "aws" },
        { name = "AWS_REGION", value = data.aws_region.current.name },
        { name = "AWS_COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.chat_pool.id },
        { name = "AWS_COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.chat_pool_client.id },
        { name = "SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI", value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.chat_pool.id}" },
        { name = "SPRING_DATASOURCE_URL", value = "jdbc:postgresql://${aws_db_instance.chat_db.address}:${aws_db_instance.chat_db.port}/${aws_db_instance.chat_db.db_name}" }, # Adres URL do bazy danych PostgreSQL.
        { name = "SPRING_DATASOURCE_USERNAME", value = aws_db_instance.chat_db.username }, # Nazwa użytkownika bazy danych.
        { name = "SPRING_DATASOURCE_PASSWORD", value = aws_db_instance.chat_db.password }, # Hasło do bazy danych.
        { name = "APP_SERVICES_NOTIFICATION_URL", value = "http://${aws_lb.main_alb.dns_name}/api/notifications" }, # Adres URL serwisu notyfikacji (przez Load Balancer), bo to chat-service jest tym, który inicjuje wysłanie powiadomienia, gdy pojawia się nowa wiadomość
        { name = "APP_CORS_ALLOWED_ORIGIN_FRONTEND", value = "http://${aws_elastic_beanstalk_environment.frontend_env.cname}" }
      ]
      depends_on_db      = true  # Tak, ten serwis zależy od bazy danych RDS.
      depends_on_s3_ddb  = false
      depends_on_sns_ddb = false
    },
    (local.file_service_name) = { # Konfiguracja dla serwisu plików.
      port               = 8083
      ecr_repo_base_url  = aws_ecr_repository.file_service_repo.repository_url
      image_tag          = var.file_service_image_tag
      log_group_name     = aws_cloudwatch_log_group.file_service_logs.name
      target_group_arn   = aws_lb_target_group.file_tg.arn
      environment_vars   = [
        { name = "SPRING_PROFILES_ACTIVE", value = "aws" },
        { name = "AWS_REGION", value = data.aws_region.current.name },
        { name = "AWS_COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.chat_pool.id },
        { name = "AWS_COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.chat_pool_client.id },
        { name = "SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI", value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.chat_pool.id}" },
        { name = "AWS_S3_BUCKET_NAME", value = aws_s3_bucket.upload_bucket.bucket },  # Nazwa bucketu S3 do przechowywania samych plików
        { name = "AWS_DYNAMODB_TABLE_NAME_FILE_METADATA", value = aws_dynamodb_table.file_metadata_table.name }, # Nazwa tabeli DynamoDB dla metadanych plików czyli informacje: Oryginalna nazwa pliku, Kto go wrzucił, Kiedy go wrzucił, Typ pliku (np. image/jpeg), Rozmiar pliku, Klucz S3 (czyli "ścieżka" do tego pliku w buckecie S3).
        { name = "APP_CORS_ALLOWED_ORIGIN_FRONTEND", value = "http://${aws_elastic_beanstalk_environment.frontend_env.cname}" }
      ]
      depends_on_db      = false # to jest zwykły RDS, więc nie
      depends_on_s3_ddb  = true  # Tak, ten serwis zależy od S3 i DynamoDB (dla metadanych plików).
      depends_on_sns_ddb = false
    },
    (local.notification_service_name) = { # Konfiguracja dla serwisu notyfikacji.
      port               = 8084
      ecr_repo_base_url  = aws_ecr_repository.notification_service_repo.repository_url
      image_tag          = var.notification_service_image_tag
      log_group_name     = aws_cloudwatch_log_group.notification_service_logs.name
      target_group_arn   = aws_lb_target_group.notification_tg.arn
      environment_vars   = [
        { name = "SPRING_PROFILES_ACTIVE", value = "aws" },
        { name = "AWS_REGION", value = data.aws_region.current.name },
        { name = "AWS_COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.chat_pool.id },
        { name = "AWS_COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.chat_pool_client.id },
        { name = "SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI", value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.chat_pool.id}" },
        { name = "AWS_SNS_TOPIC_ARN", value = aws_sns_topic.notifications_topic.arn },                   # ARN tematu SNS do wysyłania notyfikacji.
        { name = "AWS_DYNAMODB_TABLE_NAME_NOTIFICATION_HISTORY", value = aws_dynamodb_table.notifications_history_table.name }, # Nazwa tabeli DynamoDB dla historii notyfikacji.
        { name = "APP_CORS_ALLOWED_ORIGIN_FRONTEND", value = "http://${aws_elastic_beanstalk_environment.frontend_env.cname}" }
      ]
      depends_on_db      = false
      depends_on_s3_ddb  = false
      depends_on_sns_ddb = true # Tak, ten serwis zależy od SNS i DynamoDB (dla historii notyfikacji), tylko notification-service jest odpowiedzialny za wysyłanie (publikowanie) wiadomości do tematu SNS
      # Inne serwisy (np. chat-service) jeśli chcą wysłać powiadomienie, to nie robią tego bezpośrednio do SNS. Zamiast tego, wywołują API notification-service (mówią mu: "hej, wyślij takie powiadomienie"). Dopiero notification-service bierze tę informację i publikuje ją do tematu SNS.
    }
  }
}

# --- Pobieranie informacji o domyślnych zasobach AWS ---
# 'data' pozwala Terraformowi odczytać informacje o istniejących zasobach lub konfiguracji AWS.
data "aws_vpc" "default" { # Pobieramy informacje o domyślnej sieci VPC w naszym regionie.
  default = true           # Chcemy tę, która jest oznaczona jako domyślna.
}

data "aws_subnets" "default" { # Pobieramy informacje o domyślnych podsieciach w tej VPC.
  filter {                     # Filtrujemy podsieci.
    name   = "vpc-id"          # Chcemy te, które należą do VPC...
    values = [data.aws_vpc.default.id] # ...o ID pobranym powyżej (ID domyślnej VPC).
  }
}

data "aws_region" "current" {} # Pobieramy informacje o aktualnym regionie AWS, w którym działamy.
data "aws_caller_identity" "current" {} # Pobieramy informacje o tożsamości (np. ID konta), z którą Terraform się uwierzytelnił.

# --- Zmienne dla istniejących ról IAM ---
# Te role IAM (uprawnienia) już istnieją w środowisku AWS dostarczone przez laboratorium
variable "lab_role_arn" {
  description = "ARN of the existing LabRole" # Opis
  type        = string                         # Typ: tekst
  default     = "arn:aws:iam::044902896603:role/LabRole" # ARN roli IAM, której będą używać nasze serwisy Fargate i Lambda.
}

variable "lab_instance_profile_name" {
  description = "Name of the existing LabInstanceProfile for Elastic Beanstalk"
  type        = string
  default     = "LabInstanceProfile" # Nazwa profilu, nie ARN
}

# --- Grupy bezpieczeństwa (Firewalle) ---
resource "aws_security_group" "alb_sg" { # Tworzymy grupę bezpieczeństwa dla naszego Load Balancera (ALB)
  name        = "${local.project_name}-alb-sg"      # Nazwa grupy
  description = "Security group for ALB"            # Opis
  vpc_id      = data.aws_vpc.default.id             # Ta grupa należy do naszej domyślnej VPC

  ingress {                          # Reguły ruchu przychodzącego (kto może się łączyć DO ALB)
    from_port   = 80                 # Od portu 80...
    to_port     = 80                 # ...do portu 80
    # Port 80 to standardowy, dobrze znany port dla protokołu HTTP (czyli dla "zwykłego", nieszyfrowanego ruchu webowego)
    # Mój Load Balancer (ALB) ma ustawiony "nasłuchiwacz" (listener) na porcie 80, żeby odbierać te przychodzące żądania HTTP od użytkowników
    protocol    = "tcp"              # Protokół TCP (dla HTTP)
    cidr_blocks = ["0.0.0.0/0"]      # Zezwalamy na ruch z dowolnego adresu IP (cały internet)
  }
  #Gdybyśmy chcieli używać HTTPS, czyli szyfrowanego ruchu
  # egress {
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
  egress {                             #  Reguły ruchu wyychodzącego
    from_port   = 0                    # Od dowolnego portu...
    to_port     = 0                    # ...do dowolnego portu
    protocol    = "-1"                 # Dowolny protokół
    cidr_blocks = ["0.0.0.0/0"]        # Do dowolnego adresu IP (ALB musi móc łączyć się z serwisami Fargate na ich portach)
  }
  tags = local.common_tags     # Dodajemy nasze wspólne tagi.
}

resource "aws_security_group" "fargate_sg" { # Tworzymy grupę bezpieczeństwa dla naszych serwisów Fargate.
  name        = "${local.project_name}-fargate-sg"  # Nazwa.
  description = "Security group for Fargate services" # Opis.
  vpc_id      = data.aws_vpc.default.id             # Należy do domyślnej VPC.

  # Reguły ruchu przychodzącego dla każdego serwisu Fargate.
  ingress { # Dla auth-service
    from_port       = 8081                            # Od portu 8081...
    to_port         = 8081                            # ...do portu 8081.
    protocol        = "tcp"                           # Protokół TCP.
    security_groups = [aws_security_group.alb_sg.id]  # Zezwalamy na ruch TYLKO z naszej grupy bezpieczeństwa ALB.
  }
  ingress { // Dla chat-service
    from_port       = 8082
    to_port         = 8082
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress { // Dla file-service
    from_port       = 8083
    to_port         = 8083
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress { // Dla notification-service
    from_port       = 8084
    to_port         = 8084
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {                            # Reguły ruchu wychodzącego dla serwisów Fargate.
    from_port   = 0                   # Od dowolnego portu...
    to_port     = 0                   # ...do dowolnego portu.
    protocol    = "-1"                # Dowolny protokół.
    cidr_blocks = ["0.0.0.0/0"]       # Do dowolnego adresu IP (np. żeby mogły łączyć się z innymi usługami AWS jak S3, DynamoDB, RDS, Cognito, SNS).
  }
  tags = local.common_tags
}

# --- Repozytoria ECR (Elastic Container Registry) ---
# Tutaj będziemy przechowywać nasze obrazy Docker.
resource "aws_ecr_repository" "auth_service_repo" { # Tworzymy repozytorium ECR dla serwisu autoryzacji.
  name         = "${local.project_name_prefix}/${local.auth_service_name}" # Nazwa repozytorium.
  tags         = local.common_tags                                       # Nasze tagi.
  force_delete = true                                                    # Jeśli usuwamy repozytorium Terraformem, usuń je nawet jeśli zawiera obrazy
}
resource "aws_ecr_repository" "chat_service_repo" { # Dla serwisu czatu.
  name         = "${local.project_name_prefix}/${local.chat_service_name}"
  tags         = local.common_tags
  force_delete = true
}
resource "aws_ecr_repository" "file_service_repo" { # Dla serwisu plików.
  name         = "${local.project_name_prefix}/${local.file_service_name}"
  tags         = local.common_tags
  force_delete = true
}
resource "aws_ecr_repository" "notification_service_repo" { # Dla serwisu notyfikacji.
  name         = "${local.project_name_prefix}/${local.notification_service_name}"
  tags         = local.common_tags
  force_delete = true
}
resource "aws_ecr_repository" "frontend_repo" { # Dla frontendu.
  name         = "${local.project_name_prefix}/${local.frontend_name}"
  tags         = local.common_tags
  force_delete = true
}

# --- Klaster ECS (Elastic Container Service) ---
resource "aws_ecs_cluster" "main_cluster" { # Tworzymy klaster ECS, który będzie zarządzał naszymi kontenerami Fargate.
  name = "${local.project_name}-cluster"   # Nazwa klastra
  tags = local.common_tags
}

# --- Application Load Balancer (ALB) ---
resource "aws_lb" "main_alb" { # Tworzymy Application Load Balancer.
  name               = "${local.project_name}-alb" # Nazwa ALB.
  internal           = false                       # Czy ALB ma być wewnętrzny (tylko w VPC) czy publiczny? `false` = publiczny.
  load_balancer_type = "application"              # Typ: Application Load Balancer (warstwa 7).
  security_groups    = [aws_security_group.alb_sg.id] # Przypisujemy grupę bezpieczeństwa stworzoną dla ALB.
  subnets            = data.aws_subnets.default.ids   # ALB będzie działał w naszych domyślnych podsieciach.
  tags               = local.common_tags
  idle_timeout       = 60                            # Czas bezczynności połączenia w sekundach (po tym czasie ALB zamknie połączenie).
  enable_http2       = true                          # Włączamy obsługę HTTP/2.
  drop_invalid_header_fields = false                 # Czy ALB ma odrzucać żądania z niepoprawnymi nagłówkami? `false` = nie odrzucaj.
}

# --- Listener dla ALB ---
resource "aws_lb_listener" "http_listener" { # Tworzymy listener dla ALB, który będzie nasłuchiwał na ruch HTTP.
  load_balancer_arn = aws_lb.main_alb.arn   # Do którego ALB należy ten listener.
  port              = "80"                  # Nasłuchuje na porcie 80 (HTTP).
  protocol          = "HTTP"                # Protokół HTTP.
  default_action {                          # Domyślna akcja, jeśli żadna reguła nie pasuje.
    type = "fixed-response"                 # Zwróć stałą odpowiedź.
    fixed_response {
      content_type = "text/plain"           # Typ treści odpowiedzi.
      message_body = "Service not found - Check ALB Rules" # Treść odpowiedzi.
      status_code  = "404"                  # Kod statusu HTTP (Not Found).
    }
  }
}

# --- Grupy Docelowe (Target Groups) dla ALB ---
# Każdy mikroserwis będzie miał swoją grupę docelową. ALB kieruje ruch do tych grup.
resource "aws_lb_target_group" "auth_tg" { # Grupa docelowa dla serwisu autoryzacji.
  name        = "${local.project_name}-auth-tg" # Nazwa grupy.
  port        = 8081                            # Port, na którym nasłuchują kontenery tego serwisu.
  protocol    = "HTTP"                          # Protokół komunikacji między ALB a kontenerami.
  vpc_id      = data.aws_vpc.default.id         # W której VPC znajduje się ta grupa.
  target_type = "ip"                            # Typ celu: adresy IP (dla Fargate).
  health_check {                                # Konfiguracja sprawdzania stanu zdrowia kontenerów.
    enabled             = true                  # Włączone sprawdzanie.
    healthy_threshold   = 5                     # Ile kolejnych udanych sprawdzeń, by uznać kontener za zdrowy.
    interval            = 60                    # Co ile sekund wysyłać zapytanie sprawdzające.
    matcher             = "200-299"             # Jakie kody statusu HTTP oznaczają zdrowy kontener.
    path                = "/actuator/health"    # Ścieżka URL do sprawdzania (endpoint Spring Boot Actuator).
    port                = "traffic-port"        # Użyj portu, na który kierowany jest ruch.
    protocol            = "HTTP"                # Protokół sprawdzania.
    timeout             = 20                    # Ile sekund czekać na odpowiedź.
    unhealthy_threshold = 5                   # Ile kolejnych nieudanych sprawdzeń, by uznać kontener za niezdrowy.
  }
  tags = local.common_tags
  lifecycle {                                   # Konfiguracja cyklu życia tego zasobu.
    create_before_destroy = true                # Najpierw stwórz nową grupę, potem usuń starą (minimalizuje przestoje przy aktualizacjach).
    # Zapewnia to płynne przejście i minimalizuje ryzyko, że mój serwis autoryzacji przestanie na chwilę odpowiadać podczas aktualizacji jego konfiguracji w Load Balancerze.
  }
}

resource "aws_lb_target_group" "chat_tg" { # Grupa docelowa dla serwisu czatu.
  name        = "${local.project_name}-chat-tg"
  port        = 8082
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"
  health_check {
    path     = "/actuator/health"
    protocol = "HTTP"
    matcher  = "200" # Uproszczony matcher, tylko kod 200 oznacza zdrowy.
  }
  tags = local.common_tags
}

resource "aws_lb_target_group" "file_tg" { # Grupa docelowa dla serwisu plików.
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

resource "aws_lb_target_group" "notification_tg" {  # Grupa docelowa dla serwisu notyfikacji.
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
# Te reguły mówią ALB, jak kierować ruch na podstawie ścieżki URL.
resource "aws_lb_listener_rule" "auth_rule" { # Reguła dla serwisu autoryzacji.
  listener_arn = aws_lb_listener.http_listener.arn # Do którego listenera należy ta reguła.
  priority     = 100                               # Priorytet reguły (niższa liczba = wyższy priorytet).
  action {                                          # Co zrobić, gdy warunek jest spełniony.
    type             = "forward"                    # Przekaż ruch dalej.
    target_group_arn = aws_lb_target_group.auth_tg.arn # Do grupy docelowej serwisu autoryzacji.
  }
  condition {                                       # Warunek, który musi być spełniony.
    path_pattern {                                  # Dopasowanie na podstawie ścieżki URL.
      values = ["/api/auth/*"]                      # Jeśli ścieżka zaczyna się od "/api/auth/".
    }
  }
}

resource "aws_lb_listener_rule" "chat_rule" { # Reguła dla serwisu czatu.
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 110
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.chat_tg.arn
  }
  condition {
    path_pattern {
      values = ["/api/messages", "/api/messages/*"] # Jeśli ścieżka to "/api/messages" LUB zaczyna się od "/api/messages/".
    }
  }
}

resource "aws_lb_listener_rule" "file_rule" { # Reguła dla serwisu plików.
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 120
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.file_tg.arn
  }
  condition {
    path_pattern {
      values = ["/api/files/*"]
    }
  }
}

resource "aws_lb_listener_rule" "notification_rule" { # Reguła dla serwisu notyfikacji.
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 130
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.notification_tg.arn
  }
  condition {
    path_pattern {
      values = ["/api/notifications/*"]
    }
  }
}

# --- Baza Danych RDS (Relational Database Service) dla serwisu czatu ---
resource "aws_db_subnet_group" "rds_subnet_group" { # Tworzymy grupę podsieci dla naszej bazy danych RDS.
  name       = "${local.project_name}-rds-subnet-group" # Nazwa grupy podsieci.
  subnet_ids = data.aws_subnets.default.ids             # Baza danych będzie mogła działać w naszych domyślnych podsieciach.
  tags       = local.common_tags
}

resource "aws_security_group" "rds_sg" { # Tworzymy grupę bezpieczeństwa dla naszej bazy danych RDS.
  name        = "${local.project_name}-rds-sg"      # Nazwa
  description = "Security group for RDS instance"   # Opis
  vpc_id      = data.aws_vpc.default.id             # Należy do domyślnej VPC

  ingress {                                         # Reguły ruchu przychodzącego (kto może łączyć się DO bazy).
    from_port       = 5432                            # Od portu 5432 (standardowy port PostgreSQL)...
    to_port         = 5432                            # ...do portu 5432.
    protocol        = "tcp"                           # Protokół TCP.
    security_groups = [aws_security_group.fargate_sg.id] # Zezwalamy na ruch TYLKO z naszej grupy bezpieczeństwa serwisów Fargate (czyli tylko chat-service będzie mógł się połączyć)
  }

  egress {                                          # Reguły ruchu wychodzącego (gdzie baza może się łączyć).
    from_port   = 0                                 # Zazwyczaj bazy danych nie muszą inicjować wielu połączeń wychodzących,
    to_port     = 0                                 # ale ta reguła pozwala na dowolny ruch wychodzący (np. po aktualizacje).
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
}

resource "aws_db_instance" "chat_db" { # Tworzymy instancję bazy danych PostgreSQL
  identifier           = "${local.project_name}-chat-db" # Unikalny identyfikator instancji.
  allocated_storage    = 20                               # Rozmiar dysku w GB.
  engine               = "postgres"                       # Silnik bazy danych: PostgreSQL.
  engine_version       = "14.15"                          # Wersja silnika PostgreSQL. <--- POWRÓT DO ORYGINAŁU
  instance_class       = "db.t3.micro"                    # Typ instancji (wielkość serwera). "t3.micro" jest mały i tani, dobry na start.
  db_name              = "chat_service_db"                # Nazwa samej bazy danych, która zostanie utworzona wewnątrz instancji.
  username             = "chatadmin"                      # Nazwa użytkownika-administratora bazy.
  password             = "admin1234"                      # Hasło użytkownika. UWAGA: W produkcji użyj czegoś bezpieczniejszego i zarządzaj tym np. przez AWS Secrets Manager!
  parameter_group_name = "default.postgres14"            # Grupa parametrów konfiguracyjnych dla PostgreSQL 14. <--- POWRÓT DO ORYGINAŁU
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name # Grupa podsieci, w której baza będzie działać.
  vpc_security_group_ids = [aws_security_group.rds_sg.id]  # Grupa bezpieczeństwa dla bazy.
  skip_final_snapshot  = true      # Czy pominąć tworzenie ostatecznej migawki (backupu) przy usuwaniu bazy? `true` = tak, pomiń (szybsze usuwanie, ale tracisz backup).
  tags = local.common_tags
}

# --- Tabele DynamoDB ---
# DynamoDB to baza NoSQL, dobra do przechowywania prostych danych klucz-wartość lub dokumentów.
resource "aws_dynamodb_table" "user_profiles_table" { # Tabela dla profili użytkowników (może być używana przez auth-service).
  name         = "${local.project_name}-user-profiles" # Nazwa tabeli.
  billing_mode = "PAY_PER_REQUEST"                    # Model rozliczeń: płacisz za faktyczne odczyty/zapisy (dobry na start).
  hash_key     = "userId"                              # Klucz główny (partycji) tabeli. Każdy profil będzie identyfikowany przez "userId".
  attribute {                                          # Definicja atrybutu klucza głównego.
    name = "userId"                                    # Nazwa atrybutu.
    type = "S"                                         # Typ atrybutu: String (tekst).
  }
  tags = local.common_tags
}

resource "aws_dynamodb_table" "file_metadata_table" { # Tabela dla metadanych plików (używana przez file-service).
  name         = "${local.project_name}-file-metadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "fileId" # Klucz główny: "fileId".
  attribute {
    name = "fileId"
    type = "S"
  }
  tags = local.common_tags
}

resource "aws_dynamodb_table" "notifications_history_table" { # Tabela dla historii notyfikacji (używana przez notification-service).
  name         = "${local.project_name}-notifications-history"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "notificationId" # Klucz główny: "notificationId".
  attribute {
    name = "notificationId"
    type = "S"
  }
  attribute { # Dodatkowy atrybut, który będzie używany w indeksie.
    name = "timestamp"
    type = "N" # Typ: Number (liczba).
  }
  attribute { # Dodatkowy atrybut, który będzie używany w indeksie.
    name = "userId"
    type = "S"
  }
  global_secondary_index {                            # Definicja globalnego indeksu wtórnego (GSI).
    name            = "userId-timestamp-index"        # Nazwa indeksu. Pozwoli szybko wyszukiwać notyfikacje po "userId" i sortować po "timestamp".
    hash_key        = "userId"                        # Klucz partycji dla tego indeksu.
    range_key       = "timestamp"                     # Klucz sortowania dla tego indeksu.
    projection_type = "ALL"                           # Jakie atrybuty mają być kopiowane do indeksu? "ALL" = wszystkie.
  }
  tags = local.common_tags
}

# --- Bucket S3 (Simple Storage Service) ---
# S3 to usługa do przechowywania obiektów (plików).
resource "aws_s3_bucket" "upload_bucket" { # Tworzymy bucket S3 do przechowywania przesyłanych plików.
  bucket        = "${local.project_name_prefix}-uploads-${random_string.suffix.result}" # Unikalna nazwa bucketu (musi być globalnie unikalna).
  tags          = local.common_tags
  force_destroy = true # Jeśli usuwamy bucket Terraformem, usuń go nawet jeśli zawiera pliki
}

resource "aws_s3_bucket_public_access_block" "upload_bucket_access_block" { # Konfiguracja blokady publicznego dostępu do bucketu.
  bucket = aws_s3_bucket.upload_bucket.id # Do którego bucketu stosujemy te ustawienia.

  block_public_acls       = true # Blokuj publiczne listy ACL (Access Control Lists).
  block_public_policy     = true # Blokuj publiczne polityki bucketu.
  ignore_public_acls      = true # Ignoruj publiczne listy ACL.
  restrict_public_buckets = true # Ograniczaj publiczne buckety.
  # Generalnie: chcemy, żeby nasz bucket był prywatny. Dostęp do plików będzie np. przez presigned URL.
}

# --- AWS Cognito (Zarządzanie użytkownikami) ---
resource "aws_cognito_user_pool" "chat_pool" { # Tworzymy pulę użytkowników Cognito.
  name = "${local.project_name}-user-pool"    # Nazwa puli.
  lambda_config {                             # Konfiguracja triggerów Lambda.
    pre_sign_up = aws_lambda_function.auto_confirm_user.arn # Przed rejestracją użytkownika, wywołaj funkcję Lambda "auto_confirm_user".
  }
  password_policy {                           # Polityka haseł.
    minimum_length    = 6                     # Minimalna długość hasła.
    require_lowercase = true                  # Wymagaj małych liter.
    require_numbers   = false                 # Nie Wymagaj cyfr.
    require_symbols   = false                 # Nie wymagaj symboli.
    require_uppercase = false                  # Nie wymagaj wielkich liter.
  }
  tags = local.common_tags
}

resource "aws_cognito_user_pool_client" "chat_pool_client" { # Tworzymy klienta aplikacji dla naszej puli użytkowników.
  name                = "${local.project_name}-client"    # Nazwa klienta.
  user_pool_id        = aws_cognito_user_pool.chat_pool.id # Do której puli należy ten klient.
  generate_secret     = false                             # Czy generować sekret klienta? `false` = nie (dla aplikacji webowych/mobilnych).
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"] # Jakie przepływy autoryzacji są dozwolone.
  # ALLOW_USER_PASSWORD_AUTH: logowanie loginem i hasłem.
  # ALLOW_REFRESH_TOKEN_AUTH: odświeżanie tokenu.
  # tags = local.common_tags # Tagi dla tego zasobu nie są bezpośrednio wspierane w ten sposób, można je dodać na poziomie puli.
}

# --- AWS SNS (Simple Notification Service) ---
resource "aws_sns_topic" "notifications_topic" { # Tworzymy temat SNS do wysyłania notyfikacji.
  name = "${local.project_name}-notifications-topic" # Nazwa tematu.
  tags = local.common_tags
}

# --- Grupy Logów CloudWatch ---
# Tutaj będą przechowywane logi z naszych kontenerów Fargate.
resource "aws_cloudwatch_log_group" "auth_service_logs" { # Grupa logów dla serwisu autoryzacji.
  name              = "/ecs/${local.project_name}/${local.auth_service_name}" # Nazwa grupy logów (standardowa konwencja dla ECS).
  retention_in_days = 7                                                     # Jak długo przechowywać logi (7 dni).
  tags              = local.common_tags
}
resource "aws_cloudwatch_log_group" "chat_service_logs" { # Dla serwisu czatu.
  name              = "/ecs/${local.project_name}/${local.chat_service_name}"
  retention_in_days = 7
  tags              = local.common_tags
}
resource "aws_cloudwatch_log_group" "file_service_logs" { # Dla serwisu plików.
  name              = "/ecs/${local.project_name}/${local.file_service_name}"
  retention_in_days = 7
  tags              = local.common_tags
}
resource "aws_cloudwatch_log_group" "notification_service_logs" { # Dla serwisu notyfikacji.
  name              = "/ecs/${local.project_name}/${local.notification_service_name}"
  retention_in_days = 7
  tags              = local.common_tags
}

# --- Definicje Zadań ECS (Task Definitions) ---
# Definicja zadania mówi ECS, jaki obraz Docker uruchomić, ile CPU/pamięci przydzielić, jakie zmienne środowiskowe ustawić itp.
# Używamy pętli `for_each`, żeby stworzyć definicję zadania dla każdego serwisu z naszej mapy `local.fargate_services`.
resource "aws_ecs_task_definition" "app_fargate_task_definitions" {
  for_each = local.fargate_services # Dla każdego elementu w mapie `local.fargate_services`...

  family                   = "${local.project_name}-${each.key}-task" # Nazwa rodziny definicji zadania (each.key to nazwa serwisu, np. "auth-service").
  network_mode             = "awsvpc"                                 # Tryb sieciowy: "awsvpc" (wymagany dla Fargate, daje każdemu zadaniu własny interfejs sieciowy).
  requires_compatibilities = ["FARGATE"]                              # Wymaga kompatybilności z Fargate.
  cpu                      = "1024"                                   # Ile jednostek CPU przydzielić (1024 = 1 vCPU).
  memory                   = "2048"                                   # Ile pamięci RAM w MiB przydzielić (2048 MiB = 2 GB).
  execution_role_arn       = var.lab_role_arn                         # Rola IAM, której ECS użyje do pobrania obrazu Docker i wysyłania logów do CloudWatch.
  task_role_arn            = var.lab_role_arn                         # Rola IAM, której użyje sam kontener (aplikacja wewnątrz) do dostępu do innych usług AWS (np. S3, DynamoDB).
  container_definitions = jsonencode([ # Definicja kontenera (lub kontenerów) w zadaniu, w formacie JSON.
    {
      name      = "${each.key}-container"                               # Nazwa kontenera.
      image     = "${each.value.ecr_repo_base_url}:${each.value.image_tag}" # Pełny adres obrazu Docker w ECR (each.value odnosi się do wartości z mapy `local.fargate_services`).
      essential = true                                                  # Czy ten kontener jest niezbędny do działania zadania? `true` = tak (jeśli padnie, całe zadanie padnie).
      portMappings = [                                                  # Mapowanie portów.
        { containerPort = each.value.port, hostPort = each.value.port, protocol = "tcp" } # Mapuj port kontenera (np. 8081) na ten sam port hosta
      ]
      environment = each.value.environment_vars                         # Zmienne środowiskowe dla kontenera (pobrane z `local.fargate_services`).
      logConfiguration = {                                              # Konfiguracja loggowania.
        logDriver = "awslogs"                                           # Sterownik logów: "awslogs" (do CloudWatch).
        options = {
          "awslogs-group"         = each.value.log_group_name           # Do której grupy logów wysyłać.
          "awslogs-region"        = data.aws_region.current.name        # W jakim regionie jest grupa logów.
          "awslogs-stream-prefix" = "ecs-${each.key}"                   # Przedrostek dla strumieni logów w grupie.
        }
      }
    }
  ])
  tags = local.common_tags
}

# --- Usługi ECS (ECS Services) ---
# Usługa ECS dba o to, żeby odpowiednia liczba kopii (zadań) naszej aplikacji działała i była zarejestrowana w Load Balancerze.
# Również używamy pętli `for_each`.
resource "aws_ecs_service" "app_fargate_services" {
  for_each = local.fargate_services # Dla każdego serwisu...

  name            = "${local.project_name}-${each.key}-service" # Nazwa usługi ECS.
  cluster         = aws_ecs_cluster.main_cluster.id             # Do którego klastra ECS należy ta usługa.
  task_definition = aws_ecs_task_definition.app_fargate_task_definitions[each.key].arn # Której definicji zadania ma używać ta usługa.
  launch_type     = "FARGATE"                                   # Typ uruchomienia: Fargate.
  desired_count   = 2                                           # Ile kopii (zadań) tej aplikacji ma działać jednocześnie (minimum 2 dla redundancji).
  health_check_grace_period_seconds = 120                       # Czas (w sekundach) po uruchomieniu zadania, przez który ECS będzie ignorował nieudane health checki z Load Balancera (daje czas aplikacji na start).

  network_configuration {                                       # Konfiguracja sieciowa dla zadań.
    subnets          = data.aws_subnets.default.ids             # W których podsieciach mają być uruchamiane zadania.
    security_groups  = [aws_security_group.fargate_sg.id]       # Jaką grupę bezpieczeństwa mają mieć zadania.
    assign_public_ip = true                                     # Czy przydzielać publiczny adres IP zadaniom? `true` = tak (potrzebne, żeby mogły pobrać obraz Docker z ECR i komunikować się z niektórymi usługami AWS, jeśli nie ma NAT Gateway).
  }

  load_balancer {                                               # Konfiguracja integracji z Load Balancerem.
    target_group_arn = each.value.target_group_arn              # Do której grupy docelowej ALB mają być rejestrowane zadania tej usługi.
    container_name   = "${each.key}-container"                  # Nazwa kontenera w definicji zadania, który obsługuje ruch.
    container_port   = each.value.port                          # Port tego kontenera.
  }

  deployment_circuit_breaker { # Mechanizm "bezpiecznika" przy wdrożeniach.
    enable   = true            # Włączony.
    rollback = true            # Jeśli wdrożenie się nie uda, automatycznie wróć do poprzedniej stabilnej wersji.
  }
  deployment_controller { type = "ECS" } # Kto zarządza wdrożeniami? ECS.

  depends_on = [ # Ta usługa zależy od (musi być stworzona PO) tych zasobach:
    aws_lb_listener_rule.auth_rule,
    aws_lb_listener_rule.chat_rule,
    aws_lb_listener_rule.file_rule,
    aws_lb_listener_rule.notification_rule,
    aws_db_instance.chat_db,
    aws_s3_bucket.upload_bucket,
    aws_dynamodb_table.file_metadata_table,
    aws_sns_topic.notifications_topic,
    aws_dynamodb_table.notifications_history_table,
    aws_dynamodb_table.user_profiles_table
  ]
  # `depends_on` pomaga Terraformowi ustalić prawidłową kolejność tworzenia zasobów.
  # Chociaż Terraform często sam to wykrywa, jawne `depends_on` może być potrzebne w bardziej złożonych przypadkach
  # lub gdy zależności nie są oczywiste (np. serwis Fargate potrzebuje, żeby baza danych była już gotowa).

  tags = local.common_tags
}

# --- Automatyczne Skalowanie Usług ECS ---
resource "aws_appautoscaling_target" "app_fargate_scaling_targets" { # Definiujemy cel skalowania dla każdej usługi ECS.
  for_each = local.fargate_services

  max_capacity       = 4                             # Maksymalna liczba zadań, do której usługa może się wyskalować.
  min_capacity       = 2                             # Minimalna liczba zadań, która zawsze musi działać.
  resource_id        = "service/${aws_ecs_cluster.main_cluster.name}/${aws_ecs_service.app_fargate_services[each.key].name}" # ID zasobu, który skalujemy (nasza usługa ECS).
  scalable_dimension = "ecs:service:DesiredCount"    # Co skalujemy? Liczbę pożądanych zadań w usłudze ECS.
  service_namespace  = "ecs"                         # Przestrzeń nazw usługi: ECS.
}

resource "aws_appautoscaling_policy" "app_fargate_cpu_scaling_policies" { # Definiujemy politykę skalowania (kiedy skalować).
  for_each = local.fargate_services

  name               = "${local.project_name}-${each.key}-cpu-scaling" # Nazwa polityki.
  policy_type        = "TargetTrackingScaling"                         # Typ polityki: śledzenie celu (np. utrzymuj średnie CPU na poziomie X%).
  resource_id        = aws_appautoscaling_target.app_fargate_scaling_targets[each.key].resource_id # Do którego celu skalowania stosujemy tę politykę.
  scalable_dimension = aws_appautoscaling_target.app_fargate_scaling_targets[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.app_fargate_scaling_targets[each.key].service_namespace

  target_tracking_scaling_policy_configuration { # Konfiguracja śledzenia celu.
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization" # Metryka, którą śledzimy: średnie wykorzystanie CPU przez usługę ECS.
    }
    target_value       = 75.0  # Cel: utrzymuj średnie wykorzystanie CPU na poziomie 75%. Jeśli przekroczy, dodaj zadania. Jeśli spadnie, usuń.
    scale_in_cooldown  = 300   # Czas (w sekundach) oczekiwania po skalowaniu w dół, zanim znowu można skalować w dół (zapobiega zbyt częstym zmianom).
    scale_out_cooldown = 60    # Czas (w sekundach) oczekiwania po skalowaniu w górę, zanim znowu można skalować w górę.
  }
}

# --- Funkcja Lambda do automatycznego potwierdzania użytkowników Cognito ---
resource "aws_lambda_function" "auto_confirm_user" { # Tworzymy funkcję Lambda.
  function_name = "${local.project_name}-auto-confirm-user" # Nazwa funkcji.
  runtime       = "python3.9"                               # Środowisko uruchomieniowe: Python 3.9.
  handler       = "auto_confirm_user.lambda_handler"        # Nazwa pliku i funkcji w kodzie Lambda, która ma być wywołana (plik: auto_confirm_user.py, funkcja: lambda_handler).
  role          = var.lab_role_arn                          # Rola IAM, której użyje funkcja Lambda (musi mieć uprawnienia np. do zapisu logów).

  filename         = "${path.module}/lambda/auto_confirm_user.zip" # Ścieżka do spakowanego kodu funkcji Lambda. path.module to katalog, gdzie jest ten plik main.tf.
  source_code_hash = filebase64sha256("${path.module}/lambda/auto_confirm_user.zip") # Skrót (hash) kodu. Jeśli kod się zmieni, Terraform zaktualizuje funkcję.
  tags             = local.common_tags
}

resource "aws_lambda_permission" "allow_cognito" { # Dajemy Cognito uprawnienia do wywoływania naszej funkcji Lambda.
  statement_id  = "AllowCognitoToCallLambda"    # ID tego uprawnienia.
  action        = "lambda:InvokeFunction"       # Akcja: wywołanie funkcji Lambda.
  function_name = aws_lambda_function.auto_confirm_user.function_name # Której funkcji dotyczy to uprawnienie.
  principal     = "cognito-idp.amazonaws.com"   # Kto może wywołać? Usługa Cognito.
  source_arn    = aws_cognito_user_pool.chat_pool.arn # Z której puli użytkowników Cognito może przyjść wywołanie.
}

# --- Aplikacja Elastic Beanstalk dla frontendu ---
resource "aws_elastic_beanstalk_application" "frontend_app" { # Tworzymy aplikację Elastic Beanstalk (kontener na środowiska).
  name        = "${local.project_name}-frontend-app"       # Nazwa aplikacji.
  description = "Frontend for Projekt Chmury V2"           # Opis.
  tags        = local.common_tags
}

# nie korzystałem z tego (zostało z poprzedniego main.tf)
# V
locals { # Lokalna zmienna do przechowywania zawartości pliku Dockerrun.aws.json.
  frontend_dockerrun_content = jsonencode({ # Konwertujemy mapę na string JSON.
    AWSEBDockerrunVersion = "1",            # Wersja formatu Dockerrun.
    Image = {
      Name   = "${aws_ecr_repository.frontend_repo.repository_url}:${var.frontend_image_tag}", # Adres obrazu Docker frontendu w ECR.
      Update = "true"                       # Czy Elastic Beanstalk ma próbować aktualizować obraz przy wdrożeniu?
    },
    Ports = [                               # Mapowanie portów dla kontenera frontendu.
      {
        ContainerPort = 3000                # Kontener frontendu nasłuchuje na porcie 3000.
      }
    ]
  })
}

resource "aws_s3_object" "frontend_dockerrun" { # Wrzucamy plik Dockerrun.aws.json do bucketu S3. Elastic Beanstalk go stamtąd pobierze.
  bucket  = aws_s3_bucket.upload_bucket.bucket # Do którego bucketu.
  key     = "Dockerrun.aws.json.${random_string.suffix.result}" # Nazwa pliku w buckecie (z losową końcówką, żeby był unikalny).
  content = local.frontend_dockerrun_content   # Zawartość pliku (nasz JSON zdefiniowany powyżej).
  etag    = md5(local.frontend_dockerrun_content) # Skrót MD5 zawartości, żeby Terraform wiedział, czy plik się zmienił.
}

resource "aws_elastic_beanstalk_application_version" "frontend_app_version" { # Tworzymy wersję aplikacji Elastic Beanstalk.
  name        = "${local.project_name}-frontend-v1-${random_string.suffix.result}" # Nazwa wersji.
  application = aws_elastic_beanstalk_application.frontend_app.name             # Do której aplikacji należy ta wersja.
  bucket      = aws_s3_bucket.upload_bucket.bucket                              # Bucket S3, gdzie jest plik Dockerrun.aws.json.
  key         = aws_s3_object.frontend_dockerrun.key                            # Klucz (nazwa) pliku Dockerrun.aws.json w buckecie.
  description = "Frontend application version from ECR"                         # Opis wersji.
}
# ^ #####

resource "aws_elastic_beanstalk_environment" "frontend_env" { # Tworzymy środowisko Elastic Beanstalk, które uruchomi nasz frontend.
  name                = "${local.project_name}-frontend-env"       # Nazwa środowiska.
  application         = aws_elastic_beanstalk_application.frontend_app.name # Do której aplikacji należy to środowisko.
  solution_stack_name = "64bit Amazon Linux 2023 v4.5.1 running Docker" # Platforma, na której uruchomimy aplikację (Docker na Amazon Linux 2023).
  version_label       = aws_elastic_beanstalk_application_version.frontend_app_version.name # Którą wersję aplikacji wdrożyć.

  # Ustawienia (zmienne środowiskowe) dla aplikacji frontendowej.
  setting {
    namespace = "aws:elasticbeanstalk:application:environment" # Przestrzeń nazw dla zmiennych środowiskowych aplikacji.
    name      = "VITE_AUTH_API_URL"                            # Nazwa zmiennej.
    value     = "http://${aws_lb.main_alb.dns_name}/api/auth"  # Wartość: adres URL serwisu autoryzacji (przez Load Balancer).
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_CHAT_API_URL"
    value     = "http://${aws_lb.main_alb.dns_name}/api/messages"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_FILE_API_URL"
    value     = "http://${aws_lb.main_alb.dns_name}/api/files"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_NOTIFICATION_API_URL"
    value     = "http://${aws_lb.main_alb.dns_name}/api/notifications"
  }
  setting { # Ustawienie profilu instancji IAM dla instancji EC2 w Elastic Beanstalk.
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = var.lab_instance_profile_name # Używamy profilu z laboratorium.
  }
  setting { # Konfiguracja logów CloudWatch dla Elastic Beanstalk.
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs" # Czy przesyłać logi do CloudWatch?
    value     = "true"       # Tak.
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "DeleteOnTerminate" # Czy usuwać logi przy zakończeniu środowiska?
    value     = "true"              # Tak.
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "RetentionInDays" # Jak długo przechowywać logi?
    value     = "7"               # 7 dni.
  }
  wait_for_ready_timeout = "30m" # Jak długo Terraform ma czekać, aż środowisko będzie gotowe (30 minut).
  tags                   = local.common_tags
}

# --- Wyjścia (Outputs) ---
# Te wartości będą wyświetlane po zakończeniu działania `terraform apply`. Są przydatne do uzyskania informacji o stworzonych zasobach.
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer" # Opis.
  value       = aws_lb.main_alb.dns_name                   # Wartość: adres DNS naszego Load Balancera.
}

output "frontend_url" {
  description = "URL of the deployed frontend application (Elastic Beanstalk)" # Opis.
  value       = "http://${aws_elastic_beanstalk_environment.frontend_env.cname}" # Wartość: adres URL naszego frontendu.
}

output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool" # Opis.
  value       = aws_cognito_user_pool.chat_pool.id # Wartość: ID puli użytkowników Cognito.
}

output "cognito_client_id" {
  description = "Client ID of the Cognito User Pool Client" # Opis.
  value       = aws_cognito_user_pool_client.chat_pool_client.id # Wartość: ID klienta aplikacji Cognito.
}

output "s3_upload_bucket_name" {
  description = "Name of the S3 bucket for file uploads" # Opis.
  value       = aws_s3_bucket.upload_bucket.bucket     # Wartość: nazwa naszego bucketu S3.
}

output "rds_chat_db_endpoint" {
  description = "Endpoint address of the RDS database for chat service" # Opis.
  value       = aws_db_instance.chat_db.address                       # Wartość: adres endpointu bazy danych RDS.
}

output "rds_chat_db_name" {
  description = "Name of the RDS database for chat service" # Opis.
  value       = aws_db_instance.chat_db.db_name           # Wartość: nazwa bazy danych w instancji RDS.
}

output "sns_notifications_topic_arn" {
  description = "ARN of the SNS topic for notifications" # Opis.
  value       = aws_sns_topic.notifications_topic.arn  # Wartość: ARN tematu SNS.
}

# Wyjścia dla adresów URL repozytoriów ECR (przydatne przy budowaniu i wypychaniu obrazów Docker w skrypcie deploy.sh).
output "ecr_auth_service_repo_url" {
  value = aws_ecr_repository.auth_service_repo.repository_url
}
output "ecr_chat_service_repo_url" {
  value = aws_ecr_repository.chat_service_repo.repository_url
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
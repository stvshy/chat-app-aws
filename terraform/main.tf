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
  region = "us-east-1"    # Ważne, aby wszystkie zasoby były w tym samym regionie.
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
} # Terraform, zanim cokolwiek stworzy w AWS, musi dokładnie wiedzieć, jaki kod ma wrzucić do Lambdy i obliczyć jego "odcisk palca" (hash)
# Jednak mój prawdziwy kod Lambdy (plik JAR) jest kompilowany i tworzony (w skrypcie deploy.sh) na komputerze dopiero po tym,
# jak Terraform zacznie stawiać infrastrukturę.
# Więc w momencie, gdy Terraform potrzebował tego "odcisku palca" prawdziwego JARa, ten plik jeszcze nie istniał.
# Żeby Terraform się nie buntował i mógł w ogóle stworzyć funkcję Lambda w AWS, pusty "dummy" plik ZIP.
# On z tego pliku obliczył "odcisk palca" i stworzył pustą "powłokę" funkcji Lambda w chmurze.
# Dopiero później, po tym jak mój program Java zbudował prawdziwy plik JAR, użyłem innego narzędzia (AWS CLI),
# żeby podmienić ten pusty kod na mój właściwy JAR w już istniejącej funkcji Lambda w AWS




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
} # Głównie pod s3, ale też dla innych zasobów, żeby mieć unikalne nazwy.

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
      # ARN (Amazon Resource Name) to taki unikalny identyfikator dla praktycznie każdego zasobu, który chcemy stworzyć w AWS
      environment_vars   = [  # Lista zmiennych środowiskowych, które zostaną wstrzyknięte do kontenera.
        { name = "SPRING_PROFILES_ACTIVE", value = "aws" },  # Ustawia profil Springa na 'aws'.
        { name = "AWS_REGION", value = data.aws_region.current.name },  # Przekazuje aktualny region AWS.
        { name = "AWS_COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.chat_pool.id },  # ID puli użytkowników Cognito.
        { name = "AWS_COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.chat_pool_client.id },  # ID klienta aplikacji w Cognito.
        { name = "SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI", value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.chat_pool.id}" }, # Adres do walidacji tokenów JWT.
        # ^ To mówi naszym aplikacjom Spring Boot, gdzie mają pytać Cognito, czy tokeny (bilety wstępu) od użytkowników są prawdziwe i ważne.
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
        # ^ To mówi naszym aplikacjom Spring Boot, gdzie mają pytać Cognito, czy tokeny (bilety wstępu) od użytkowników są prawdziwe i ważne.
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
      ] # jeśli chcemy wysłać wiadomość na czat, pobrać wysłane wiadomości, czy zaznaczyć wiadomość jako przeczytaną, to wszystkie te operacje są pod tym adresem
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
    # jeśli adres nie pasuje do żadnego z API
    # (np. /api/auth), to ruch trafia do frontendu. Bez tego strona
    # główna (logowania i rejestracji) by się nie załadowała.
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
#    Ta reguła ("route") jest kluczowa: mówi, że cały ruch do internetu ("0.0.0.0/0") ma iść przez naszą
#    Bramę Internetową. Bez tego, serwisy w VPC nie miałyby dostępu do świata.
resource "aws_default_route_table" "main_rt" {
  # Wskazujemy Terraformowi, że chcemy zarządzać GŁÓWNĄ tablicą routingu dla naszej domyślnej sieci VPC.
  default_route_table_id = data.aws_vpc.default.main_route_table_id

  # Tutaj definiujemy samą regułę routingu
  route {
    # Cel: każdy adres spoza naszej sieci VPC, czyli w praktyce cały internet.
    cidr_block = "0.0.0.0/0"

    # Kierunek: cały ten ruch ma być kierowany do Bramy Internetowej (nasze wyjście do świata).
    gateway_id = data.aws_internet_gateway.default.id
  }

  # Standardowe etykiety (tagi), aby łatwiej było znaleźć ten zasób w konsoli AWS.
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-default-rt"
  })
}


# --- Grupy bezpieczeństwa ---
# Grupy bezpieczeństwa działają jak wirtualny firewall dla zasobów, kontrolując ruch przychodzący i wychodzący.

# Grupa bezpieczeństwa dla Application Load Balancera (ALB).
# Działa jak firewall: określa, jaki ruch może wejść do ALB i z niego wyjść.
resource "aws_security_group" "alb_sg" {
  name        = "${local.project_name}-alb-sg"  # Unikalna nazwa grupy.
  description = "Security group for ALB"
  vpc_id      = data.aws_vpc.default.id   # Przypisujemy do naszej VPC.

  # Definiujemy, jaki ruch może WEJŚĆ do Load Balancera.
  ingress {
    # Port 80 to standardowy port dla ruchu webowego (HTTP).
    # Otwieramy go, aby użytkownicy mogli w ogóle połączyć się z naszą stroną.
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"

    # Zezwalamy na ruch z każdego adresu IP na świecie ("0.0.0.0/0"),
    # bo ALB jest publicznie dostępny.
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Definiujemy, jaki ruch może WYJŚĆ z Load Balancera.
  egress {
    # Porty 0 i protokół "-1" to specjalne wartości oznaczające "cały ruch".
    # Pozwalamy ALB swobodnie wysyłać ruch dalej - do naszych wewnętrznych
    # serwisów (Fargate) oraz z powrotem do użytkowników.
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags  # Wspólne tagi dla łatwiejszej identyfikacji.
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
    self      = true # oznacza, że źródłem ruchu może być inny zasób w tej samej grupie.
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
# ECR (Elastic Container Registry) to usługa AWS do przechowywania obrazów Docker. Tworzymy osobne repozytorium dla każdego mikroserwisu.
# Repozytorium dla auth-service.
resource "aws_ecr_repository" "auth_service_repo" {
  name         = "${local.project_name_prefix}/${local.auth_service_name}" # Nazwa repozytorium, zgodna z konwencją projektu.
  tags         = local.common_tags
  force_delete = true  # Jeśli usuniemy repozytorium przez Terraform, to zostanie ono usunięte nawet jeśli zawiera obrazy. Użyteczne w środowiskach deweloperskich.
}
# Repozytorium dla file-service.
resource "aws_ecr_repository" "file_service_repo" {
  name         = "${local.project_name_prefix}/${local.file_service_name}"
  tags         = local.common_tags
  force_delete = true
}
# Repozytorium dla notification-service.
resource "aws_ecr_repository" "notification_service_repo" {
  name         = "${local.project_name_prefix}/${local.notification_service_name}"
  tags         = local.common_tags
  force_delete = true
}
# Repozytorium dla frontendu.
resource "aws_ecr_repository" "frontend_repo" {
  name         = "${local.project_name_prefix}/${local.frontend_name}"
  tags         = local.common_tags
  force_delete = true
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
  # Utrzymuje połączenie otwarte przez 60s, nawet gdy nic się nie dzieje,
  # co przyspiesza kolejne akcje użytkownika.
  idle_timeout       = 60

  # Włącza obsługę nowoczesnego i szybszego protokołu HTTP/2,
  # co przyspiesza ładowanie strony.
  enable_http2       = true

  # Pozwala na przekazywanie zapytań z niestandardowymi nagłówkami HTTP.
  # Zwiększa to kompatybilność, np. z niestandardowymi klientami API.
  drop_invalid_header_fields = false
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
# Jest to zbiór kontenerów Fargate dla 'auth-service', do których ALB kieruje ruch.
resource "aws_lb_target_group" "auth_tg" {
  # Nazwa grupy docelowej, unikalna w regionie.
  name        = "${local.project_name}-auth-tg"
  # Port, na którym aplikacja Spring Boot w kontenerze Fargate nasłuchuje na żądania.
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  # 'ip' jest wymagane dla usług Fargate, bo ALB kieruje ruch bezpośrednio do adresu IP kontenera.
  target_type = "ip"

  # Konfiguracja sprawdzania stanu zdrowia (Health Check).
  # ALB regularnie odpytuje nasze kontenery, aby sprawdzić, czy działają poprawnie.
  # Jeśli kontener nie odpowiada poprawnie, ALB przestaje wysyłać do niego ruch.
  health_check {
    enabled             = true
    # Kontener musi odpowiedzieć poprawnie 5 razy z rzędu, aby ALB uznał go za "zdrowy"
    # i zaczął kierować do niego ruch.
    healthy_threshold   = 5
    # ALB wysyła zapytanie sprawdzające stan zdrowia co 60 sekund.
    interval            = 60
    # ALB oczekuje odpowiedzi z kodem HTTP pomiędzy 200 a 299, co oznacza sukces.
    matcher             = "200-299"
    # Ścieżka, pod którą ALB wysyła zapytanie. /actuator/health to standardowy endpoint
    # dodawany przez Spring Boot Actuator, który zwraca status "UP" (kod 200), gdy aplikacja działa.
    path                = "/actuator/health"
    # Używa tego samego portu, na który kierowany jest normalny ruch (tutaj 8081).
    port                = "traffic-port"
    protocol            = "HTTP"
    # ALB czeka maksymalnie 20 sekund na odpowiedź od aplikacji. Jeśli jej nie otrzyma,
    # uznaje próbę za nieudaną.
    timeout             = 20
    # Jeśli kontener 5 razy z rzędu nie odpowie poprawnie, ALB oznacza go jako "niezdrowy"
    # i przestaje do niego kierować ruch.
    unhealthy_threshold = 5
  }
  tags = local.common_tags

  # Konfiguracja cyklu życia zasobu. 'create_before_destroy = true' jest kluczowe dla
  # wdrożeń bez przestojów. Terraform najpierw stworzy
  # nową grupę docelową, a dopiero potem usunie starą, co zapewnia ciągłość działania.
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
  allocated_storage    = 2
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
  # Nie twórz końcowego snapshotu przy usuwaniu instancji
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
  # Definicja Globalnego Indeksu Wtórnego (GSI).
  # To jest jakby "alternatywna tabela" z tymi samymi danymi, ale ułożonymi
  # inaczej, co pozwala nam na wykonywanie zupełnie nowych, wydajnych zapytań.
  global_secondary_index {
    # Nazwa naszego nowego indeksu. Musi być unikalna dla tej tabeli.
    name            = "userId-timestamp-index"

    # Definiujemy nowy klucz główny dla tego indeksu.
    # Dzięki temu możemy teraz wyszukiwać dane po 'userId', a nie tylko po 'notificationId'.
    hash_key        = "userId"

    # Definiujemy klucz sortujący dla tego indeksu. Dzięki temu, gdy zapytamy o wszystkie
    # powiadomienia dla danego 'userId', DynamoDB zwróci je już posortowane po 'timestamp'.
    range_key       = "timestamp"

    # Określamy, jakie dane z oryginalnego rekordu mają być skopiowane do tego indeksu.
    # 'ALL' oznacza, że kopiujemy cały rekord. Dzięki temu, gdy odpytamy indeks,
    # dostaniemy od razu wszystkie dane i nie musimy dodatkowo odpytywać głównej tabeli.
    projection_type = "ALL"
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
  # Wymuś usunięcie bucketa (kiedy niszczymy infrastrukture) nawet, jeśli nie jest pusty
  force_destroy = true
}
# Blokada publicznego dostępu do bucketa. Ważne ze względów bezpieczeństwa.
# Ten blok to nasz "strażnik bezpieczeństwa" dla bucketu S3.
# Jego jedynym zadaniem jest upewnienie się, że nikt przez pomyłkę
# nie udostępni tego bucketu (i jego zawartości) publicznie w internecie.
resource "aws_s3_bucket_public_access_block" "upload_bucket_access_block" {
  # Wskazujemy, którego bucketu ma pilnować ten "strażnik".
  bucket = aws_s3_bucket.upload_bucket.id

  # Mówimy: "Nie pozwól NIKOMU ustawić publicznych uprawnień dla pojedynczych plików."
  # To blokuje stare, mniej bezpieczne metody nadawania dostępu.
  block_public_acls       = true

  # Mówimy: "Nie pozwól NIKOMU przypisać do tego bucketu polityki,
  # która udostępniałaby go publicznie." To jest najważniejsza blokada.
  block_public_policy     = true

  # Mówimy: "Jeśli ktoś spróbuje ustawić publiczne uprawnienia dla pojedynczych plików,
  # po prostu to zignoruj i nie rób nic." To dodatkowe zabezpieczenie.
  ignore_public_acls      = true

  # Mówimy: "Jeśli jakakolwiek polityka przypisana do tego bucketu jest publiczna,
  # zablokuj dostęp." To ostateczna blokada, która działa na poziomie całego konta.
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
    require_numbers   = false
    require_symbols   = false
    require_uppercase = false
  }
  tags = local.common_tags
}
# Klient puli użytkowników (User Pool Client) to jakby "reprezentant" naszej aplikacji (frontendu) w systemie Cognito.
# To przez niego nasza aplikacja będzie się komunikować z pulą użytkowników, aby np. logować użytkowników.
resource "aws_cognito_user_pool_client" "chat_pool_client" {
  # Nazwa naszego klienta aplikacji.
  name                = "${local.project_name}-client"

  # Wskazujemy, do której puli użytkowników ten klient ma dostęp.
  user_pool_id        = aws_cognito_user_pool.chat_pool.id

  # Nie generujemy "sekretu klienta" (client secret), co jest kluczowe.
  # Nasz frontend działa w przeglądarce, więc nie ma bezpiecznego miejsca,
  # żeby przechowywać taki sekret. Wyłączenie tego jest wymagane dla publicznych klientów.
  generate_secret     = false

  # Tutaj jawnie określamy, jakie metody logowania są dozwolone dla tego klienta.
  # Nasza aplikacja będzie mogła:
  # 1. "ALLOW_USER_PASSWORD_AUTH": Logować użytkowników za pomocą ich loginu i hasła.
  # 2. "ALLOW_REFRESH_TOKEN_AUTH": Używać "tokenu odświeżającego", aby automatycznie
  #    przedłużać sesję zalogowanego użytkownika bez ponownego pytania go o hasło.
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

# Do kolejki SQS wysyłany jest JSON payload zawierający dane powiadomienia
# Funkcja Lambda SendMessageLambda (ta odpowiedzialna za wysyłanie wiadomości czatu) po pomyślnym zapisaniu wiadomości w bazie danych,
# publikuje odpowiedni komunikat do kolejki SQS (aws_sqs_queue.chat_notifications_queue).
# Komunikat SQS zawiera wszystkie niezbędne informacje do wygenerowania powiadomienia,
# takie jak ID odbiorcy (targetUserId), typ powiadomienia (type), treść wiadomości (message) i ID powiązanej encji (np. ID wiadomości czatu, relatedEntityId).
# Moduł notyfikacji (notification-service), wdrożony nadal jako mikroserwis na AWS Fargate, jest skonfigurowany do nasłuchiwania na wiadomości z tej samej kolejki SQS.
# Wykorzystuje do tego Spring Cloud AWS SQS i adnotację @SqsListener w klasie SqsNotificationListener.
# Po odebraniu wiadomości z SQS, serwis notyfikacji przetwarza ją, zapisując rekord powiadomienia w bazie danych DynamoDB (notifications_history_table)
# i wysyłając je do tematu SNS (notifications_topic) w celu dalszej dystrybucji do subskrybentów.
# Ta zmiana wprowadza decoupling (rozprzężenie) między serwisami. SendMessageLambda nie musi wiedzieć nic o wewnętrznym działaniu serwisu notyfikacji; wystarczy, że wyśle zdarzenie.
# Zwiększa to odporność systemu (jeśli serwis notyfikacji jest chwilowo niedostępny, wiadomości czekają w kolejce) oraz skalowalność.
resource "aws_sqs_queue" "chat_notifications_queue" {
  name                        = "${local.project_name}-chat-notifications-queue"
  # Opóźnienie dostarczenia wiadomości (w sekundach).
  delay_seconds               = 0
  # Jak długo wiadomość ma być przechowywana w kolejce (w sekundach).
  message_retention_seconds   = 345600 # 4 dni

  # Gdy nasz serwis pobierze wiadomość, staje się ona "niewidzialna" dla innych
  # na 60 sekund. Daje to czas na jej przetworzenie i zapobiega sytuacji,
  # w której dwa serwisy próbują przetworzyć tę samą wiadomość jednocześnie.
  visibility_timeout_seconds  = 60
  # ZAKOŃCZENIE:
  #    - PO SUKCESIE: Serwis pomyślnie przetworzył wiadomość i wysyła do SQS
  #      polecenie "DeleteMessage". Wiadomość jest TRWALE usuwana z kolejki.
  #      Nie jest nigdzie archiwizowana przez SQS. Służyła jako zadanie do
  #      wykonania i to zadanie zostało zakończone.
  #
  #    - PO AWARII: Serwis uległ awarii lub nie zdążył w 60 sekund. Polecenie
  #      "DeleteMessage" nie zostało wysłane. Po upływie timeoutu, SQS
  #      przywraca widoczność wiadomości, aby mogła zostać podjęta ponownie.

  # Włącza "long polling": jeśli kolejka jest pusta, AWS nie odpowiada od razu,
  # ale czeka do 10 sekund, czy pojawi się nowa wiadomość. Zmniejsza to liczbę
  # pustych zapytań i redukuje koszty.
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
# Rola IAM to zbiór uprawnień. Używamy istniejącej roli 'LabRole'
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
  # Typ uruchomienia - Fargate
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

# Definiujemy politykę automatycznego skalowania. To jest "mózg", który decyduje,
# KIEDY i DLACZEGO mamy dodawać lub usuwać kontenery Fargate dla naszych usług.
resource "aws_appautoscaling_policy" "app_fargate_cpu_scaling_policies" {
  for_each = local.fargate_services
  name     = "${local.project_name}-${each.key}-cpu-scaling"

  # "TargetTrackingScaling" to najprostszy i najczęstszy typ polityki. Mówimy AWS:
  # "Pilnuj za mnie jednej metryki (np. użycia CPU) i utrzymuj ją na stałym poziomie".
  policy_type        = "TargetTrackingScaling"

  # Te trzy linijki łączą tę politykę z wcześniej zdefiniowanym "celem skalowania"
  # (zasobem aws_appautoscaling_target), mówiąc jej, CO ma skalować.
  resource_id        = aws_appautoscaling_target.app_fargate_scaling_targets[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.app_fargate_scaling_targets[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.app_fargate_scaling_targets[each.key].service_namespace

  # Szczegółowa konfiguracja naszej polityki śledzenia celu.
  target_tracking_scaling_policy_configuration {

    # Określamy, jaką metrykę AWS ma obserwować.
    predefined_metric_specification {
      # Wybieramy standardową metrykę: "Średnie zużycie CPU przez wszystkie
      # kontenery w danej usłudze ECS".
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    # To jest nasz cel: "Staraj się utrzymywać średnie użycie CPU na poziomie 75%".
    # Jeśli użycie CPU wzrośnie powyżej 75%, AWS automatycznie doda nowy kontener (scale-out).
    # Jeśli spadnie znacznie poniżej 75%, AWS usunie jeden z kontenerów (scale-in).
    target_value       = 75.0

    # Po usunięciu kontenera (scale-in), poczekaj 300 sekund (5 minut) zanim
    # podejmiesz kolejną decyzję o usunięciu. Zapobiega to zbyt gwałtownemu
    # usuwaniu kontenerów, jeśli obciążenie jest niestabilne.
    scale_in_cooldown  = 300

    # Po dodaniu nowego kontenera (scale-out), poczekaj 60 sekund zanim podejmiesz
    # kolejną decyzję o dodaniu. Daje to nowemu kontenerowi czas na uruchomienie się
    # i przejęcie części ruchu, co ustabilizuje metrykę CPU.
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
  # Kto może wywoływać - usługa Cognito.
  principal     = "cognito-idp.amazonaws.com"
  # Z jakiego źródła (ARN naszej puli użytkowników).
  source_arn    = aws_cognito_user_pool.chat_pool.arn
}


# --- Definicje funkcji Lambda dla logiki czatu ---
# Tworzymy funkcje Lambda, które będą obsługiwać logikę biznesową czatu.
# WAŻNE: Początkowo wdrażamy je z "zaślepką" (dummy zip), a prawdziwy kod .jar jest wgrywany przez skrypt deploy.sh.

# Definiujemy funkcję Lambda odpowiedzialną za logikę wysyłania wiadomości.
resource "aws_lambda_function" "send_message_lambda" {
  # Unikalna nazwa funkcji w AWS, generowana na podstawie nazwy projektu.
  function_name = "${local.project_name}-SendMessageLambda"

  # "Punkt wejścia" do naszego kodu. AWS wie, że ma uruchomić metodę 'handleRequest'
  # w klasie 'pl.projektchmury.chatapp.lambda.SendMessageLambda' w naszym pliku JAR.
  handler       = "pl.projektchmury.chatapp.lambda.SendMessageLambda::handleRequest"

  # Rola IAM, która nadaje tej funkcji uprawnienia, np. do zapisu logów w CloudWatch
  # i połączenia z bazą danych RDS.
  role          = var.lab_role_arn

  # Środowisko wykonawcze dla naszego kodu. Wybieramy Javę w wersji 17.
  runtime       = "java17"

  # Ilość pamięci RAM przydzielona dla funkcji (w MB). Więcej pamięci to też więcej mocy CPU.
  memory_size   = 512

  # Maksymalny czas (w sekundach), przez jaki funkcja może działać. Jeśli przekroczy 30s,
  # zostanie przymusowo zatrzymana. Zapobiega to "wiecznym pętlom" i niekontrolowanym kosztom.
  timeout       = 30

  # Na etapie tworzenia infrastruktury przez Terraform, wgrywamy mały, pusty plik "dummy".
  # Prawdziwy kod JAR zostanie wgrany później przez skrypt deploy.sh.
  filename         = data.archive_file.dummy_lambda_zip.output_path
  source_code_hash = data.archive_file.dummy_lambda_zip.output_base64sha256

  # Przekazujemy do funkcji zmienne środowiskowe, takie jak adres bazy danych i hasła
  environment { variables = local.chat_lambda_common_environment_variables }

  # Umieszczamy tę funkcję w naszej sieci VPC. Jest to KONIECZNE, aby mogła
  # połączyć się z naszą bazą danych RDS, która nie jest publicznie dostępna.
  vpc_config {
    # Wskazujemy podsieci, w których funkcja może działać.
    subnet_ids         = data.aws_subnets.default.ids
    # Przypisujemy grupę bezpieczeństwa, która zezwala na ruch do bazy danych.
    security_group_ids = [aws_security_group.internal_sg.id]
  }

  tags = local.common_tags

  # To jest kluczowy blok: mówimy Terraformowi, żeby po stworzeniu funkcji
  # IGNOROWAŁ przyszłe zmiany w pliku z kodem i jego hashu. Robimy to, ponieważ
  # kod będzie aktualizowany przez skrypt deploy.sh, a nie przez Terraform.
  # Bez tego, Terraform przy każdym uruchomieniu próbowałby przywrócić "dummy" kod.
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}

# Definiujemy funkcję Lambda odpowiedzialną za pobieranie wiadomości WYSŁANYCH przez użytkownika.
resource "aws_lambda_function" "get_sent_messages_lambda" {
  # Unikalna nazwa funkcji w AWS, generowana na podstawie nazwy projektu.
  function_name = "${local.project_name}-GetSentMessagesLambda"

  # "Punkt wejścia" do naszego kodu. AWS wie, że ma uruchomić metodę 'handleRequest'
  # w klasie 'pl.projektchmury.chatapp.lambda.GetSentMessagesLambda' w naszym pliku JAR.
  handler       = "pl.projektchmury.chatapp.lambda.GetSentMessagesLambda::handleRequest"

  # Rola IAM, która nadaje tej funkcji uprawnienia, np. do zapisu logów w CloudWatch
  # i połączenia z bazą danych RDS.
  role          = var.lab_role_arn

  # Środowisko wykonawcze dla naszego kodu. Wybieramy Javę w wersji 17.
  runtime       = "java17"

  # Ilość pamięci RAM przydzielona dla funkcji (w MB). Mniej niż dla 'send_message',
  # bo odczyt z bazy jest zazwyczaj mniej zasobożerny niż zapis i wysyłka do SQS.
  memory_size   = 256

  # Maksymalny czas (w sekundach), przez jaki funkcja może działać, zanim zostanie zatrzymana.
  timeout       = 20

  # Na etapie tworzenia infrastruktury przez Terraform, wgrywamy mały, pusty plik "dummy".
  # Prawdziwy kod JAR zostanie wgrany później przez skrypt deploy.sh.
  filename         = data.archive_file.dummy_lambda_zip.output_path
  source_code_hash = data.archive_file.dummy_lambda_zip.output_base64sha256

  # Przekazujemy do funkcji zmienne środowiskowe, takie jak adres bazy danych i hasła,
  # aby nie musieć ich "hardkodować" w kodzie.
  environment { variables = local.chat_lambda_common_environment_variables }

  # Umieszczamy tę funkcję w naszej sieci VPC. Jest to KONIECZNE, aby mogła
  # połączyć się z naszą bazą danych RDS, która nie jest publicznie dostępna.
  vpc_config {
    # Wskazujemy podsieci, w których funkcja może działać.
    subnet_ids         = data.aws_subnets.default.ids
    # Przypisujemy grupę bezpieczeństwa, która zezwala na ruch do bazy danych.
    security_group_ids = [aws_security_group.internal_sg.id]
  }

  tags = local.common_tags

  # To jest kluczowy blok: mówimy Terraformowi, żeby po stworzeniu funkcji
  # IGNOROWAŁ przyszłe zmiany w pliku z kodem i jego hashu. Robimy to, ponieważ
  # kod będzie aktualizowany przez skrypt deploy.sh, a nie przez Terraform.
  # Bez tego, Terraform przy każdym uruchomieniu próbowałby przywrócić "dummy" kod.
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}
# Definiujemy funkcję Lambda odpowiedzialną za pobieranie wiadomości OTRZYMANYCH przez użytkownika.
resource "aws_lambda_function" "get_received_messages_lambda" {
  # Unikalna nazwa funkcji w AWS, generowana na podstawie nazwy projektu.
  function_name = "${local.project_name}-GetReceivedMessagesLambda"

  # "Punkt wejścia" do naszego kodu. AWS wie, że ma uruchomić metodę 'handleRequest'
  # w klasie 'pl.projektchmury.chatapp.lambda.GetReceivedMessagesLambda' w naszym pliku JAR.
  handler       = "pl.projektchmury.chatapp.lambda.GetReceivedMessagesLambda::handleRequest"

  # Rola IAM, która nadaje tej funkcji uprawnienia, np. do zapisu logów w CloudWatch
  # i połączenia z bazą danych RDS.
  role          = var.lab_role_arn

  # Środowisko wykonawcze dla naszego kodu. Wybieramy Javę w wersji 17.
  runtime       = "java17"

  # Ilość pamięci RAM przydzielona dla funkcji (w MB).
  memory_size   = 256

  # Maksymalny czas (w sekundach), przez jaki funkcja może działać, zanim zostanie zatrzymana.
  timeout       = 20

  # Na etapie tworzenia infrastruktury przez Terraform, wgrywamy mały, pusty plik "dummy".
  # Prawdziwy kod JAR zostanie wgrany później przez skrypt deploy.sh.
  filename         = data.archive_file.dummy_lambda_zip.output_path
  source_code_hash = data.archive_file.dummy_lambda_zip.output_base64sha256

  # Przekazujemy do funkcji zmienne środowiskowe, takie jak adres bazy danych i hasła.
  environment { variables = local.chat_lambda_common_environment_variables }

  # Umieszczamy tę funkcję w naszej sieci VPC. Jest to KONIECZNE, aby mogła
  # połączyć się z naszą bazą danych RDS, która nie jest publicznie dostępna.
  vpc_config {
    # Wskazujemy podsieci, w których funkcja może działać.
    subnet_ids         = data.aws_subnets.default.ids
    # Przypisujemy grupę bezpieczeństwa, która zezwala na ruch do bazy danych.
    security_group_ids = [aws_security_group.internal_sg.id]
  }

  tags = local.common_tags

  # To jest kluczowy blok: mówimy Terraformowi, żeby po stworzeniu funkcji
  # IGNOROWAŁ przyszłe zmiany w pliku z kodem i jego hashu. Robimy to, ponieważ
  # kod będzie aktualizowany przez skrypt deploy.sh, a nie przez Terraform.
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}

# Definiujemy funkcję Lambda odpowiedzialną za oznaczanie wiadomości jako przeczytanej.
resource "aws_lambda_function" "mark_message_as_read_lambda" {
  # Unikalna nazwa funkcji w AWS, generowana na podstawie nazwy projektu.
  function_name = "${local.project_name}-MarkMessageAsReadLambda"

  # "Punkt wejścia" do naszego kodu. AWS wie, że ma uruchomić metodę 'handleRequest'
  # w klasie 'pl.projektchmury.chatapp.lambda.MarkMessageAsReadLambda' w naszym pliku JAR.
  handler       = "pl.projektchmury.chatapp.lambda.MarkMessageAsReadLambda::handleRequest"

  # Rola IAM, która nadaje tej funkcji uprawnienia, np. do zapisu logów w CloudWatch
  # i połączenia z bazą danych RDS.
  role          = var.lab_role_arn

  # Środowisko wykonawcze dla naszego kodu. Wybieramy Javę w wersji 17.
  runtime       = "java17"

  # Ilość pamięci RAM przydzielona dla funkcji (w MB).
  memory_size   = 256

  # Maksymalny czas (w sekundach), przez jaki funkcja może działać, zanim zostanie zatrzymana.
  timeout       = 20

  # Na etapie tworzenia infrastruktury przez Terraform, wgrywamy mały, pusty plik "dummy".
  # Prawdziwy kod JAR zostanie wgrany później przez skrypt deploy.sh.
  filename         = data.archive_file.dummy_lambda_zip.output_path
  source_code_hash = data.archive_file.dummy_lambda_zip.output_base64sha256

  # Przekazujemy do funkcji zmienne środowiskowe, takie jak adres bazy danych i hasła.
  environment { variables = local.chat_lambda_common_environment_variables }

  # Umieszczamy tę funkcję w naszej sieci VPC. Jest to KONIECZNE, aby mogła
  # połączyć się z naszą bazą danych RDS, która nie jest publicznie dostępna.
  vpc_config {
    # Wskazujemy podsieci, w których funkcja może działać.
    subnet_ids         = data.aws_subnets.default.ids
    # Przypisujemy grupę bezpieczeństwa, która zezwala na ruch do bazy danych.
    security_group_ids = [aws_security_group.internal_sg.id]
  }

  tags = local.common_tags

  # To jest kluczowy blok: mówimy Terraformowi, żeby po stworzeniu funkcji
  # IGNOROWAŁ przyszłe zmiany w pliku z kodem i jego hashu. Robimy to, ponieważ
  # kod będzie aktualizowany przez skrypt deploy.sh, a nie przez Terraform.
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}


# --- API Gateway dla funkcji Lambda czatu ---
# Jego zadaniem jest wystawianie na świat endpointów HTTP, które bezpośrednio uruchamiają nasze funkcje Lambda.
# •	Natywna Integracja z Serverless: To standardowy i najbardziej wydajny sposób na wywoływanie funkcji Lambda przez internet.
# •	Bezpieczeństwo: API Gateway ma wbudowany mechanizm autoryzacji. W naszym projekcie integruje się z AWS Cognito.
# Oznacza to, że zanim żądanie w ogóle dotrze do naszej funkcji Lambda, API Gateway sprawdza, czy użytkownik jest zalogowany i ma ważny token.
# To zdejmuje z nas ciężar implementacji tej logiki w kodzie Lambdy.
# •	Zarządzanie API: API Gateway ułatwia zarządzanie takimi aspektami jak CORS, ograniczanie liczby zapytań (throttling) czy transformacje żądań
# •	Efektywność Kosztowa: Za API Gateway płacimy tylko za faktyczne wywołania API, co idealnie pasuje do modelu serverless.
# ALB ma stały, choć niski, koszt godzinowy, co jest akceptowalne dla stale działających usług.
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

# Tworzymy zasób (resource) - ścieżkę w naszym API, np. /messages.
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
# Czyli mówimy API Gateway, żeby po otrzymaniu zapytania POST na /messages wywołał naszą Lambdę.
resource "aws_api_gateway_integration" "send_message_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.chat_api.id
  resource_id             = aws_api_gateway_resource.messages_resource.id
  http_method             = aws_api_gateway_method.send_message_post_method.http_method

  integration_http_method = "POST" # Metoda HTTP używana do wywołania backendu (Lambdy).
  type                    = "AWS_PROXY" # Typ integracji 'AWS_PROXY' przekazuje całe zapytanie do Lambdy i zwraca jej odpowiedź. To najprostszy i najczęstszy sposób.
  uri                     = aws_lambda_function.send_message_lambda.invoke_arn # ARN funkcji Lambda, którą chcemy wywołać.
}
# Uprawnienie dla API Gateway do wywoływania tej konkretnej funkcji Lambda.
resource "aws_lambda_permission" "apigw_lambda_send_message" {
  statement_id  = "AllowAPIGatewayInvokeSendMessageLambda" # Unikalny identyfikator uprawnienia.
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_message_lambda.function_name
  principal     = "apigateway.amazonaws.com" # To oznacza, że API Gateway może wywołać tę Lambdę.

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
# Ten cały blok jest potrzebny, aby przeglądarka internetowa (w której działa nasz frontend)
# mogła bezpiecznie komunikować się z naszym API, które jest na innej domenie.
# Przeglądarka, ze względów bezpieczeństwa, najpierw wysyła zapytanie "sprawdzające" (preflight)
# metodą OPTIONS, aby zapytać serwer API, czy zgadza się na komunikację.
# Poniższy kod buduje odpowiedź "Tak, zgadzam się" na to zapytanie.

# Krok 1: Tworzymy w API Gateway endpoint, który nasłuchuje na metodę OPTIONS.
resource "aws_api_gateway_method" "messages_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id # ID naszego API Gateway.
  resource_id   = aws_api_gateway_resource.messages_resource.id # ID zasobu, czyli ścieżki /messages.
  http_method   = "OPTIONS" # Metoda HTTP, którą chcemy obsłużyć.
  # To zapytanie nie wymaga autoryzacji, bo przeglądarka wysyła je "anonimowo"
  # zanim jeszcze wyśle token użytkownika.
  authorization = "NONE"
}

# Krok 2: Definiujemy, co ma się stać, gdy przyjdzie zapytanie OPTIONS.
# Używamy typu 'MOCK', co oznacza, że API Gateway odpowie od razu, bez wywoływania
# żadnej funkcji Lambda. Jest to bardzo szybkie i tanie.
resource "aws_api_gateway_integration" "messages_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.messages_resource.id
  http_method = aws_api_gateway_method.messages_options_method.http_method
  type        = "MOCK"

  # Sztucznie generujemy odpowiedź dla integracji MOCK.
  # To jest wewnętrzny status dla API Gateway, mówiący "ta integracja zakończyła się sukcesem",
  # co pozwala mu przejść do następnego kroku (method_response).
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Krok 3: Deklarujemy, JAK BĘDZIE wyglądać odpowiedź wysyłana do klienta.
resource "aws_api_gateway_method_response" "messages_options_200" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.messages_resource.id
  http_method   = aws_api_gateway_method.messages_options_method.http_method

  # Definiujemy, że faktyczny kod statusu HTTP, który zobaczy przeglądarka, to "200 OK".
  status_code   = "200"

  response_models = {
    "application/json" = "Empty"
  }
  # "Odblokowujemy" możliwość wysyłania tych nagłówków CORS w odpowiedzi.
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

  # Ustawiamy na "NONE", ponieważ zapytanie OPTIONS jest wysyłane przez przeglądarkę
  # automatycznie i bez tokenu autoryzacyjnego. Wymaganie tu autoryzacji
  # zablokowałoby całą komunikację z API. Bezpieczeństwo jest zachowane,
  # bo faktyczne dane (np. z metody GET) nadal wymagają autoryzacji.
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
  depends_on = [aws_db_instance.chat_db] # Upewniamy się, że ta funkcja jest tworzona dopiero po utworzeniu bazy danych.

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
  rest_api_id = aws_api_gateway_rest_api.chat_api.id # ID naszego API Gateway, które chcemy wdrożyć.
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
      aws_api_gateway_integration_response.messages_options_integration_response_200.id,
      aws_api_gateway_method.messages_sent_options_method.id,
      aws_api_gateway_integration.messages_sent_options_integration.id,
      aws_api_gateway_integration_response.messages_sent_options_integration_response_200.id,
      aws_api_gateway_method.messages_received_options_method.id,
      aws_api_gateway_integration.messages_received_options_integration.id,
      aws_api_gateway_integration_response.messages_received_options_integration_response_200.id,
      aws_api_gateway_method.mark_as_read_options_method.id,
      aws_api_gateway_integration.mark_as_read_options_integration.id,
      aws_api_gateway_integration_response.mark_as_read_options_integration_response_200.id
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
  deployment_id = aws_api_gateway_deployment.chat_api_deployment.id # ID wdrożenia, które chcemy opublikować.
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id # ID naszego API Gateway.
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
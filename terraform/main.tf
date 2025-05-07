provider "aws" {
  region = "us-east-1"
}

#########################
# Losowy sufiks do nazw #
#########################
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  # Używamy prefixu i losowego sufiksu dla unikalności
  project_name_prefix = "projekt-chmury-v2"
  project_name        = "${local.project_name_prefix}-${random_string.suffix.result}"

  common_tags = {
    Project     = local.project_name_prefix
    Environment = "dev"
    Suffix      = random_string.suffix.result
  }

  # Nazwy serwisów
  auth_service_name         = "auth-service"
  chat_service_name         = "chat-service"
  file_service_name         = "file-service"
  notification_service_name = "notification-service"
  frontend_name             = "frontend" # Nazwa dla zasobów frontendu
}

#################################
# VPC, Subnets, Security Groups #
#################################
# Tworzymy dedykowaną VPC dla aplikacji

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-vpc"
  })
}

# Dwie publiczne podsieci w różnych Availability Zones dla wysokiej dostępności ALB
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${data.aws_region.current.name}a" # Użyj pierwszej AZ w regionie
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-public-subnet-a"
  })
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${data.aws_region.current.name}b" # Użyj drugiej AZ w regionie
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-public-subnet-b"
  })
}

# Dwie prywatne podsieci w różnych Availability Zones dla Fargate i RDS
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${data.aws_region.current.name}a"
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-private-subnet-a"
  })
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${data.aws_region.current.name}b"
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-private-subnet-b"
  })
}

# Internet Gateway dla ruchu wychodzącego z publicznych podsieci
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-igw"
  })
}

# Tablica routingu dla publicznych podsieci
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway dla ruchu wychodzącego z prywatnych podsieci (np. do AWS API)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-nat-eip"
  })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id # Umieszczamy NAT Gateway w publicznej podsieci
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-nat-gw"
  })
  depends_on = [aws_internet_gateway.gw]
}

# Tablica routingu dla prywatnych podsieci
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-private-rt"
  })
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# Grupa bezpieczeństwa dla Application Load Balancer (ruch przychodzący z internetu na HTTP/HTTPS)
resource "aws_security_group" "alb_sg" {
  name        = "${local.project_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # ingress { # Odkomentuj, jeśli używasz HTTPS
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
}

# Grupa bezpieczeństwa dla serwisów Fargate (ruch przychodzący tylko z ALB)
resource "aws_security_group" "fargate_sg" {
  name        = "${local.project_name}-fargate-sg"
  description = "Security group for Fargate services"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 0 # Dowolny port
    to_port         = 0
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Tylko ruch z ALB
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Pozwól na ruch wychodzący do AWS API (S3, DynamoDB, etc.) przez NAT Gateway
  }
  tags = local.common_tags
}

# Grupa bezpieczeństwa dla bazy danych RDS (ruch przychodzący tylko z Fargate)
resource "aws_security_group" "rds_sg" {
  name        = "${local.project_name}-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432 # Port PostgreSQL
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.fargate_sg.id] # Tylko ruch z Fargate
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
}

#######################
# ECR Repositories    #
#######################
# Tworzymy repozytoria dla obrazów Docker każdego mikroserwisu i frontendu

resource "aws_ecr_repository" "auth_service_repo" {
  name = "${local.project_name_prefix}/${local.auth_service_name}" # Używamy prefixu dla organizacji
  tags = local.common_tags
}
resource "aws_ecr_repository" "chat_service_repo" {
  name = "${local.project_name_prefix}/${local.chat_service_name}"
  tags = local.common_tags
}
resource "aws_ecr_repository" "file_service_repo" {
  name = "${local.project_name_prefix}/${local.file_service_name}"
  tags = local.common_tags
}
resource "aws_ecr_repository" "notification_service_repo" {
  name = "${local.project_name_prefix}/${local.notification_service_name}"
  tags = local.common_tags
}
resource "aws_ecr_repository" "frontend_repo" {
  name = "${local.project_name_prefix}/${local.frontend_name}"
  tags = local.common_tags
}

#################################
# ECS Cluster                   #
#################################
resource "aws_ecs_cluster" "main_cluster" {
  name = "${local.project_name}-cluster"
  tags = local.common_tags
}

#################################
# Application Load Balancer     #
#################################
resource "aws_lb" "main_alb" {
  name               = "${local.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id] # ALB w publicznych podsieciach
  tags               = local.common_tags
}

# Domyślny listener HTTP (można dodać HTTPS z certyfikatem ACM)
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Service not found - Check ALB Rules"
      status_code  = "404"
    }
  }
}

# --- Target Groups dla każdego serwisu ---
resource "aws_lb_target_group" "auth_tg" {
  name        = "${local.project_name}-auth-tg"
  port        = 8081 # Port kontenera auth-service
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # Dla Fargate
  health_check {
    path                = "/actuator/health" # Endpoint Spring Boot Actuator
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = local.common_tags
}

resource "aws_lb_target_group" "chat_tg" {
  name        = "${local.project_name}-chat-tg"
  port        = 8082 # Port kontenera chat-service
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path     = "/actuator/health"
    protocol = "HTTP"
    matcher  = "200"
  }
  tags = local.common_tags
}

resource "aws_lb_target_group" "file_tg" {
  name        = "${local.project_name}-file-tg"
  port        = 8083 # Port kontenera file-service
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path     = "/actuator/health"
    protocol = "HTTP"
    matcher  = "200"
  }
  tags = local.common_tags
}

resource "aws_lb_target_group" "notification_tg" {
  name        = "${local.project_name}-notification-tg"
  port        = 8084 # Port kontenera notification-service
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path     = "/actuator/health"
    protocol = "HTTP"
    matcher  = "200"
  }
  tags = local.common_tags
}

# --- Listener Rules do routingu ---
resource "aws_lb_listener_rule" "auth_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 100 # Priorytety muszą być unikalne

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth_tg.arn
  }
  condition {
    path_pattern {
      values = ["/api/auth/*"] # Ścieżka dla Auth Service
    }
  }
}

resource "aws_lb_listener_rule" "chat_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 110

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.chat_tg.arn
  }
  condition {
    path_pattern {
      values = ["/api/messages/*"] # Ścieżka dla Chat Service
    }
  }
}

resource "aws_lb_listener_rule" "file_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 120

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.file_tg.arn
  }
  condition {
    path_pattern {
      values = ["/api/files/*"] # Ścieżka dla File Service
    }
  }
}

resource "aws_lb_listener_rule" "notification_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 130

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.notification_tg.arn
  }
  condition {
    path_pattern {
      values = ["/api/notifications/*"] # Ścieżka dla Notification Service
    }
  }
}

# TODO: Dodać regułę dla frontendu, jeśli jest serwowany przez ALB/Fargate
# np. z niższym priorytetem i path_pattern "/*"

#################################
# IAM Roles for Fargate Tasks   #
#################################
data "aws_iam_policy_document" "ecs_tasks_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Rola wykonawcza dla zadań ECS (pobieranie obrazów, logi)
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${local.project_name}-ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role_policy.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Rola dla aplikacji w zadaniach ECS (dostęp do S3, DynamoDB, SNS, Cognito, etc.)
resource "aws_iam_role" "app_task_role" {
  name               = "${local.project_name}-app-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role_policy.json
  tags               = local.common_tags
}

# Polityka dla roli aplikacji - DOSTOSUJ UPRAWNIENIA!
data "aws_iam_policy_document" "app_task_policy_doc" {
  # Dostęp do S3 dla file-service
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject"
      # "s3:ListBucket" # Jeśli potrzebne
    ]
    resources = [
      aws_s3_bucket.upload_bucket.arn,
      "${aws_s3_bucket.upload_bucket.arn}/*" # Dostęp do obiektów w buckecie
    ]
  }
  # Dostęp do DynamoDB dla file-service, notification-service, auth-service
  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Query", # Potrzebne dla GSI w notification-service
      "dynamodb:Scan",  # Unikaj, jeśli możliwe
      # "dynamodb:UpdateItem",
      # "dynamodb:DeleteItem",
      "dynamodb:DescribeTable"
    ]
    resources = [
      aws_dynamodb_table.file_metadata_table.arn,
      aws_dynamodb_table.notifications_history_table.arn,
      "${aws_dynamodb_table.notifications_history_table.arn}/index/*", # Dostęp do indeksów GSI
      aws_dynamodb_table.user_profiles_table.arn,
    ]
  }
  # Dostęp do SNS dla notification-service
  statement {
    actions = [
      "sns:Publish"
    ]
    resources = [aws_sns_topic.notifications_topic.arn]
  }
  # Dostęp do Cognito dla auth-service (i potencjalnie innych)
  statement {
    actions = [
      "cognito-idp:SignUp",
      "cognito-idp:AdminInitiateAuth", # Lub InitiateAuth, jeśli nie używasz admin flow
      "cognito-idp:GetUser",
      "cognito-idp:ListUsers"
      # Dodaj inne potrzebne akcje
    ]
    resources = [aws_cognito_user_pool.chat_pool.arn]
  }
}

resource "aws_iam_policy" "app_task_policy" {
  name   = "${local.project_name}-app-task-policy"
  policy = data.aws_iam_policy_document.app_task_policy_doc.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "app_task_role_policy_attach" {
  role       = aws_iam_role.app_task_role.name
  policy_arn = aws_iam_policy.app_task_policy.arn
}

#################################
# Databases                     #
#################################

# --- RDS dla Chat Service ---
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${local.project_name}-rds-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id] # RDS w prywatnych podsieciach
  tags       = local.common_tags
}

resource "aws_db_instance" "chat_db" {
  identifier             = "${local.project_name}-chat-db"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "14.15" # Użyj wersji z Twojego oryginalnego pliku
  instance_class         = "db.t3.micro"
  db_name                = "chat_service_db" # Zmieniona nazwa bazy
  username               = "chatadmin"       # Zmień na bezpieczniejsze
  password               = "TwojeSuperTajneHaslo123!" # Zmień i użyj Secrets Manager!
  parameter_group_name   = "default.postgres14"
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false # Ważne - niedostępna publicznie
  tags                   = local.common_tags
}

# --- DynamoDB Tables ---

# Tabela dla Auth Service (User Profiles)
resource "aws_dynamodb_table" "user_profiles_table" {
  name           = "${local.project_name}-user-profiles"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId" # Cognito SUB

  attribute {
    name = "userId"
    type = "S"
  }
  tags = local.common_tags
}

# Tabela dla File Service (File Metadata)
resource "aws_dynamodb_table" "file_metadata_table" {
  name           = "${local.project_name}-file-metadata"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "fileId" # UUID

  attribute {
    name = "fileId"
    type = "S"
  }
  tags = local.common_tags
}

# Tabela dla Notification Service (Notifications History)
resource "aws_dynamodb_table" "notifications_history_table" {
  name           = "${local.project_name}-notifications-history"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "notificationId" # UUID
  range_key      = "timestamp"      # Klucz sortowania

  attribute {
    name = "notificationId"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "N" # Timestamp jako Number (epoch millis)
  }
  attribute {
    name = "userId" # Atrybut dla klucza partycji GSI
    type = "S"
  }

  # Global Secondary Index do wyszukiwania po userId
  global_secondary_index {
    name            = "userId-timestamp-index"
    hash_key        = "userId"
    range_key       = "timestamp"
    projection_type = "ALL" # Kopiuj wszystkie atrybuty do indeksu
  }
  tags = local.common_tags
}

#################################
# S3 Bucket for File Uploads    #
#################################
resource "aws_s3_bucket" "upload_bucket" {
  bucket = "${local.project_name_prefix}-uploads-${random_string.suffix.result}" # Unikalna nazwa
  tags   = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "upload_bucket_access_block" {
  bucket = aws_s3_bucket.upload_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#################################
# Cognito User Pool & Client    #
#################################
resource "aws_cognito_user_pool" "chat_pool" {
  name = "${local.project_name}-user-pool"

  # Podłączamy Lambdę (jeśli istnieje i jest potrzebna)
  lambda_config {
    pre_sign_up = aws_lambda_function.auto_confirm_user.arn
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }
  # auto_verified_attributes = ["email"] # Wymaga konfiguracji weryfikacji email
  tags = local.common_tags
}

resource "aws_cognito_user_pool_client" "chat_pool_client" {
  name                = "${local.project_name}-client"
  user_pool_id        = aws_cognito_user_pool.chat_pool.id
  generate_secret     = false # Dla aplikacji SPA/web
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  # Dodaj inne konfiguracje klienta, jeśli potrzebne
  tags = local.common_tags
}

#################################
# SNS Topic for Notifications   #
#################################
resource "aws_sns_topic" "notifications_topic" {
  name = "${local.project_name}-notifications-topic"
  tags = local.common_tags
}

#################################
# CloudWatch Log Groups         #
#################################
# Tworzymy log groupy dla każdego serwisu Fargate

resource "aws_cloudwatch_log_group" "auth_service_logs" {
  name              = "/ecs/${local.project_name}/${local.auth_service_name}"
  retention_in_days = 7
  tags              = local.common_tags
}
resource "aws_cloudwatch_log_group" "chat_service_logs" {
  name              = "/ecs/${local.project_name}/${local.chat_service_name}"
  retention_in_days = 7
  tags              = local.common_tags
}
resource "aws_cloudwatch_log_group" "file_service_logs" {
  name              = "/ecs/${local.project_name}/${local.file_service_name}"
  retention_in_days = 7
  tags              = local.common_tags
}
resource "aws_cloudwatch_log_group" "notification_service_logs" {
  name              = "/ecs/${local.project_name}/${local.notification_service_name}"
  retention_in_days = 7
  tags              = local.common_tags
}

###################################################
# Fargate Service Definition - Auth Service       #
###################################################
resource "aws_ecs_task_definition" "auth_service_task_def" {
  family                   = "${local.project_name}-${local.auth_service_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # MB
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.app_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "${local.auth_service_name}-container"
      # WAŻNE: Zmień ':latest' na konkretny tag obrazu po wypchnięciu do ECR!
      image     = "${aws_ecr_repository.auth_service_repo.repository_url}:latest"
      essential = true
      portMappings = [
        { containerPort = 8081, hostPort = 8081, protocol = "tcp" }
      ]
      environment = [
        { name = "SPRING_PROFILES_ACTIVE", value = "aws" },
        { name = "AWS_REGION", value = data.aws_region.current.name },
        { name = "AWS_COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.chat_pool.id },
        { name = "AWS_COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.chat_pool_client.id },
        # Zmienna dla issuer-uri używana w SecurityConfig
        { name = "SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI", value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.chat_pool.id}" },
        # Opcjonalna tabela profili użytkownika
        { name = "AWS_DYNAMODB_TABLE_NAME_USER_PROFILES", value = aws_dynamodb_table.user_profiles_table.name }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.auth_service_logs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs-${local.auth_service_name}" # Lepszy prefix logów
        }
      }
    }
  ])
  tags = local.common_tags
}

resource "aws_ecs_service" "auth_fargate_service" {
  name            = "${local.project_name}-${local.auth_service_name}-service"
  cluster         = aws_ecs_cluster.main_cluster.id
  task_definition = aws_ecs_task_definition.auth_service_task_def.arn
  launch_type     = "FARGATE"
  desired_count   = 2 # Minimalna liczba zadań

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.fargate_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.auth_tg.arn
    container_name   = "${local.auth_service_name}-container"
    container_port   = 8081
  }

  # Zapewnia płynne wdrożenia
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  deployment_controller { type = "ECS" }

  # Upewnij się, że reguła ALB istnieje przed utworzeniem serwisu
  depends_on = [aws_lb_listener_rule.auth_rule]
  tags       = local.common_tags
}

# --- Auto Scaling dla Auth Service ---
resource "aws_appautoscaling_target" "auth_service_scaling_target" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main_cluster.name}/${aws_ecs_service.auth_fargate_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "auth_service_cpu_scaling_policy" {
  name               = "${local.project_name}-auth-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.auth_service_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.auth_service_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.auth_service_scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 75.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

###################################################
# Fargate Service Definition - Chat Service       #
###################################################
resource "aws_ecs_task_definition" "chat_service_task_def" {
  family                   = "${local.project_name}-${local.chat_service_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.app_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "${local.chat_service_name}-container"
      image     = "${aws_ecr_repository.chat_service_repo.repository_url}:latest" # Zmień tag!
      essential = true
      portMappings = [
        { containerPort = 8082, hostPort = 8082, protocol = "tcp" }
      ]
      environment = [
        { name = "SPRING_PROFILES_ACTIVE", value = "aws" },
        { name = "AWS_REGION", value = data.aws_region.current.name },
        { name = "AWS_COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.chat_pool.id },
        { name = "AWS_COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.chat_pool_client.id },
        { name = "SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI", value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.chat_pool.id}" },
        # Zmienne dla RDS
        { name = "SPRING_DATASOURCE_URL", value = "jdbc:postgresql://${aws_db_instance.chat_db.address}:${aws_db_instance.chat_db.port}/${aws_db_instance.chat_db.db_name}" },
        { name = "SPRING_DATASOURCE_USERNAME", value = aws_db_instance.chat_db.username },
        { name = "SPRING_DATASOURCE_PASSWORD", value = aws_db_instance.chat_db.password } # W produkcji użyj Secrets Manager!
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.chat_service_logs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs-${local.chat_service_name}"
        }
      }
    }
  ])
  tags = local.common_tags
}

resource "aws_ecs_service" "chat_fargate_service" {
  name            = "${local.project_name}-${local.chat_service_name}-service"
  cluster         = aws_ecs_cluster.main_cluster.id
  task_definition = aws_ecs_task_definition.chat_service_task_def.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.fargate_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.chat_tg.arn
    container_name   = "${local.chat_service_name}-container"
    container_port   = 8082
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  deployment_controller { type = "ECS" }
  depends_on = [aws_lb_listener_rule.chat_rule, aws_db_instance.chat_db] # Zależy też od bazy danych
  tags       = local.common_tags
}

# --- Auto Scaling dla Chat Service ---
resource "aws_appautoscaling_target" "chat_service_scaling_target" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main_cluster.name}/${aws_ecs_service.chat_fargate_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "chat_service_cpu_scaling_policy" {
  name               = "${local.project_name}-chat-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.chat_service_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.chat_service_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.chat_service_scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 75.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

###################################################
# Fargate Service Definition - File Service       #
###################################################
resource "aws_ecs_task_definition" "file_service_task_def" {
  family                   = "${local.project_name}-${local.file_service_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.app_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "${local.file_service_name}-container"
      image     = "${aws_ecr_repository.file_service_repo.repository_url}:latest" # Zmień tag!
      essential = true
      portMappings = [
        { containerPort = 8083, hostPort = 8083, protocol = "tcp" }
      ]
      environment = [
        { name = "SPRING_PROFILES_ACTIVE", value = "aws" },
        { name = "AWS_REGION", value = data.aws_region.current.name },
        { name = "AWS_COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.chat_pool.id },
        { name = "AWS_COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.chat_pool_client.id },
        { name = "SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI", value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.chat_pool.id}" },
        # Zmienne dla S3 i DynamoDB
        { name = "AWS_S3_BUCKET_NAME", value = aws_s3_bucket.upload_bucket.bucket },
        { name = "AWS_DYNAMODB_TABLE_NAME_FILE_METADATA", value = aws_dynamodb_table.file_metadata_table.name }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.file_service_logs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs-${local.file_service_name}"
        }
      }
    }
  ])
  tags = local.common_tags
}

resource "aws_ecs_service" "file_fargate_service" {
  name            = "${local.project_name}-${local.file_service_name}-service"
  cluster         = aws_ecs_cluster.main_cluster.id
  task_definition = aws_ecs_task_definition.file_service_task_def.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.fargate_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.file_tg.arn
    container_name   = "${local.file_service_name}-container"
    container_port   = 8083
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  deployment_controller { type = "ECS" }
  depends_on = [aws_lb_listener_rule.file_rule, aws_s3_bucket.upload_bucket, aws_dynamodb_table.file_metadata_table] # Zależności
  tags       = local.common_tags
}

# --- Auto Scaling dla File Service ---
resource "aws_appautoscaling_target" "file_service_scaling_target" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main_cluster.name}/${aws_ecs_service.file_fargate_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "file_service_cpu_scaling_policy" {
  name               = "${local.project_name}-file-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.file_service_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.file_service_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.file_service_scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 75.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

###################################################
# Fargate Service Definition - Notification Service #
###################################################
resource "aws_ecs_task_definition" "notification_service_task_def" {
  family                   = "${local.project_name}-${local.notification_service_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.app_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "${local.notification_service_name}-container"
      image     = "${aws_ecr_repository.notification_service_repo.repository_url}:latest" # Zmień tag!
      essential = true
      portMappings = [
        { containerPort = 8084, hostPort = 8084, protocol = "tcp" }
      ]
      environment = [
        { name = "SPRING_PROFILES_ACTIVE", value = "aws" },
        { name = "AWS_REGION", value = data.aws_region.current.name },
        { name = "AWS_COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.chat_pool.id },
        { name = "AWS_COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.chat_pool_client.id },
        { name = "SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI", value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.chat_pool.id}" },
        # Zmienne dla SNS i DynamoDB
        { name = "AWS_SNS_TOPIC_ARN", value = aws_sns_topic.notifications_topic.arn },
        { name = "AWS_DYNAMODB_TABLE_NAME_NOTIFICATION_HISTORY", value = aws_dynamodb_table.notifications_history_table.name }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.notification_service_logs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs-${local.notification_service_name}"
        }
      }
    }
  ])
  tags = local.common_tags
}

resource "aws_ecs_service" "notification_fargate_service" {
  name            = "${local.project_name}-${local.notification_service_name}-service"
  cluster         = aws_ecs_cluster.main_cluster.id
  task_definition = aws_ecs_task_definition.notification_service_task_def.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.fargate_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.notification_tg.arn
    container_name   = "${local.notification_service_name}-container"
    container_port   = 8084
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  deployment_controller { type = "ECS" }
  depends_on = [aws_lb_listener_rule.notification_rule, aws_sns_topic.notifications_topic, aws_dynamodb_table.notifications_history_table] # Zależności
  tags       = local.common_tags
}

# --- Auto Scaling dla Notification Service ---
resource "aws_appautoscaling_target" "notification_service_scaling_target" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main_cluster.name}/${aws_ecs_service.notification_fargate_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "notification_service_cpu_scaling_policy" {
  name               = "${local.project_name}-notification-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.notification_service_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.notification_service_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.notification_service_scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 75.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}


#########################################
# Lambda function for Cognito triggers  #
#########################################
resource "aws_lambda_function" "auto_confirm_user" {
  function_name = "${local.project_name}-auto-confirm-user"
  runtime       = "python3.9" # Upewnij się, że masz odpowiedni runtime
  handler       = "auto_confirm_user.lambda_handler"
  role          = aws_iam_role.lambda_cognito_triggers.arn

  # Zakładamy, że plik zip jest w podkatalogu 'lambda' względem katalogu terraform
  filename         = "${path.module}/lambda/auto_confirm_user.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/auto_confirm_user.zip")
  tags             = local.common_tags

  # Potrzebne, jeśli Lambda ma być wywoływana przez Cognito
  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}

resource "aws_iam_role" "lambda_cognito_triggers" {
  name               = "${local.project_name}-lambda-cognito-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_cognito_triggers.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Uprawnienie dla Cognito do wywołania Lambdy
resource "aws_lambda_permission" "allow_cognito" {
  statement_id  = "AllowCognitoToCallLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_confirm_user.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.chat_pool.arn
}


#########################################
# Elastic Beanstalk — Frontend Application #
# (Z Twojego oryginalnego pliku, dostosowane) #
#########################################
resource "aws_elastic_beanstalk_application" "frontend_app" {
  name        = "${local.project_name}-frontend-app"
  description = "Frontend for Projekt Chmury V2"
  tags        = local.common_tags
}

# Uwaga: Wdrożenie na EB wymaga przygotowania Application Version,
# co zwykle robi się poza Terraformem (np. przez AWS CLI po zbudowaniu frontendu)
# lub przez bardziej zaawansowane techniki Terraform (np. null_resource).
# Poniższa definicja środowiska zakłada, że wersja aplikacji istnieje
# lub zostanie dostarczona ręcznie/przez CI/CD.

resource "aws_elastic_beanstalk_environment" "frontend_env" {
  name                = "${local.project_name}-frontend-env"
  application         = aws_elastic_beanstalk_application.frontend_app.name
  solution_stack_name = "64bit Amazon Linux 2 v5.8.0 running Docker" # Użyj nowszej wersji Docker platform

  # Przekazanie URL do ALB jako głównego API endpoint dla frontendu
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_API_URL" # Frontend będzie używał tego jako bazowego URL
    value     = "http://${aws_lb.main_alb.dns_name}" # DNS Name Load Balancera
  }
  # Można też przekazać osobne ścieżki, jeśli frontend tego wymaga
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_AUTH_SERVICE_PATH"
    value     = "/api/auth"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_CHAT_SERVICE_PATH"
    value     = "/api/messages"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_FILE_SERVICE_PATH"
    value     = "/api/files"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_NOTIFICATION_SERVICE_PATH"
    value     = "/api/notifications"
  }

  # Konfiguracja, aby EB używał obrazu z ECR (jeśli platforma to wspiera)
  # Sprawdź dokumentację dla konkretnej wersji platformy Docker na EB.
  # Może wymagać Dockerrun.aws.json v2 lub nowszego.
  # setting {
  #   namespace = "aws:elasticbeanstalk:container:docker"
  #   name      = "Image"
  #   value     = "${aws_ecr_repository.frontend_repo.repository_url}:latest" # Użyj konkretnego tagu!
  # }
  # setting {
  #   namespace = "aws:elasticbeanstalk:environment:process:default"
  #   name = "Port"
  #   value = "3000" # Port, na którym działa frontend w kontenerze (zgodnie z Dockerfile frontendu)
  # }

  # IAM Instance Profile dla EC2 instancji w EB
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    # Użyj roli z odpowiednimi uprawnieniami (np. do pobierania z ECR, jeśli używasz obrazu z ECR)
    # "LabInstanceProfile" z Twojego pliku - upewnij się, że istnieje i ma uprawnienia
    value     = "LabInstanceProfile"
  }

  # Ustawienia log streamingu do CloudWatch
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "true"
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "DeleteOnTerminate"
    value     = "true"
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "RetentionInDays"
    value     = "7"
  }
  wait_for_ready_timeout = "30m"
  tags = local.common_tags
}


###########################
# Outputs                 #
###########################

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main_alb.dns_name
}

output "frontend_url" {
  description = "URL of the deployed frontend application (Elastic Beanstalk)"
  value       = "http://${aws_elastic_beanstalk_environment.frontend_env.cname}"
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

# Potrzebne do konfiguracji VPC
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}


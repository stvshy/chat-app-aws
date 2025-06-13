terraform {
  required_providers {
    # Używamy dostawcy AWS do tworzenia zasobów AWS
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Używamy dostawcy random do generowania losowych ciągów znaków
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# --- Konfiguracja dostawcy AWS ---
provider "aws" {
  region = "us-east-1"
}
data "archive_file" "dummy_lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/dummy_lambda_code.zip" # Gdzie zapisać plik tymczasowo

  # Wkładamy do ZIP-a jeden plik z byle jaką treścią, żeby nie był pusty.
  source {
    content  = "dummy content"
    filename = "placeholder.txt"
  }
}
# --- Zmienne wejściowe dla tagów obrazów Docker ---
variable "auth_service_image_tag" {
  description = "Docker image tag for auth-service"
  type        = string
  default     = "v1.0.1"
}
variable "file_service_image_tag" {
  description = "Docker image tag for file-service"
  type        = string
  default     = "v1.0.0"
}
variable "notification_service_image_tag" {
  description = "Docker image tag for notification-service"
  type        = string
  default     = "v1.0.0"
}
variable "frontend_image_tag" {
  description = "Docker image tag for frontend"
  type        = string
  default     = "v1.0.1"
}
variable "lambda_chat_handlers_jar_key" {
  description = "S3 key for the chat Lambda handlers JAR file"
  type        = string
  default     = "chat-lambda-handlers.jar"
}

# --- Generowanie losowego ciągu znaków ---
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}
resource "time_static" "timestamp" {}

# --- Lokalne zmienne ---
locals {
  project_name_prefix = "projekt-chmury-v2"
  project_name        = "${local.project_name_prefix}-${random_string.suffix.result}"

  common_tags = {
    Project     = local.project_name_prefix
    Environment = "dev"
    Suffix      = random_string.suffix.result
  }

  auth_service_name         = "auth-service"
  file_service_name         = "file-service"
  notification_service_name = "notification-service"
  frontend_name             = "frontend"

  fargate_services = {
    (local.auth_service_name) = {
      port               = 8081
      ecr_repo_base_url  = aws_ecr_repository.auth_service_repo.repository_url
      image_tag          = var.auth_service_image_tag
      log_group_name     = aws_cloudwatch_log_group.auth_service_logs.name
      target_group_arn   = aws_lb_target_group.auth_tg.arn
      environment_vars   = [
        { name = "SPRING_PROFILES_ACTIVE", value = "aws" },
        { name = "AWS_REGION", value = data.aws_region.current.name },
        { name = "AWS_COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.chat_pool.id },
        { name = "AWS_COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.chat_pool_client.id },
        { name = "SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI", value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.chat_pool.id}" },
        { name = "AWS_DYNAMODB_TABLE_NAME_USER_PROFILES", value = aws_dynamodb_table.user_profiles_table.name },
        { name = "APP_CORS_ALLOWED_ORIGIN_FRONTEND", value = "http://${aws_elastic_beanstalk_environment.frontend_env.cname}" }
      ]
    },
    (local.file_service_name) = {
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
        { name = "AWS_S3_BUCKET_NAME", value = aws_s3_bucket.upload_bucket.bucket },
        { name = "AWS_DYNAMODB_TABLE_NAME_FILE_METADATA", value = aws_dynamodb_table.file_metadata_table.name },
        { name = "APP_CORS_ALLOWED_ORIGIN_FRONTEND", value = "http://${aws_elastic_beanstalk_environment.frontend_env.cname}" }
      ]
    },
    (local.notification_service_name) = {
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
        { name = "AWS_SNS_TOPIC_ARN", value = aws_sns_topic.notifications_topic.arn },
        { name = "AWS_DYNAMODB_TABLE_NAME_NOTIFICATION_HISTORY", value = aws_dynamodb_table.notifications_history_table.name },
        { name = "APP_SQS_QUEUE_URL", value = aws_sqs_queue.chat_notifications_queue.id },
        { name = "APP_CORS_ALLOWED_ORIGIN_FRONTEND", value = "http://${aws_elastic_beanstalk_environment.frontend_env.cname}" }
      ]
    }
  }

  chat_lambda_common_environment_variables = {
    DB_URL         = "jdbc:postgresql://${aws_db_instance.chat_db.address}:${aws_db_instance.chat_db.port}/${aws_db_instance.chat_db.db_name}"
    DB_USER        = aws_db_instance.chat_db.username
    DB_PASSWORD    = aws_db_instance.chat_db.password
    SQS_QUEUE_URL  = aws_sqs_queue.chat_notifications_queue.id
    AWS_REGION_ENV = data.aws_region.current.name
  }
}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}


# --- ODPORNA KONFIGURACJA SIECI ---

# 1. Znajdź domyślną VPC i jej podsieci
data "aws_vpc" "default" {
  default = true
}
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 2. Spróbuj znaleźć istniejącą bramę internetową (IGW)
data "aws_internet_gateway" "existing" {
  # Używamy `count`, aby uniknąć błędu, gdyby IGW nie istniała.
  # Jeśli data.aws_vpc.default.id istnieje, count = 1 (szukaj).
  count = data.aws_vpc.default.id != "" ? 1 : 0

  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 3. Stwórz nową IGW TYLKO WTEDY, gdy żadna nie została znaleziona
resource "aws_internet_gateway" "new" {
  # Jeśli `data.aws_internet_gateway.existing` nic nie znalazło (jego lista jest pusta), stwórz.
  count = length(data.aws_internet_gateway.existing) == 0 ? 1 : 0

  vpc_id = data.aws_vpc.default.id
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-igw-new"
  })
}

# 4. Ustal, którego ID bramy użyć (istniejącego lub nowo utworzonego)
locals {
  internet_gateway_id = one(concat(data.aws_internet_gateway.existing[*].id, aws_internet_gateway.new[*].id))
}

# 5. Znajdź główną tabelę routingu
data "aws_route_table" "main_rt" {
  vpc_id = data.aws_vpc.default.id
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

# 6. Sprawdź, czy domyślna trasa (0.0.0.0/0) już istnieje
data "aws_route" "existing_default" {
  # Jeśli tabela routingu została znaleziona, count = 1 (szukaj trasy).
  count = data.aws_route_table.main_rt.id != "" ? 1 : 0

  route_table_id         = data.aws_route_table.main_rt.id
  destination_cidr_block = "0.0.0.0/0"
}

# 7. Stwórz nową trasę TYLKO WTEDY, gdy nie została znaleziona
resource "aws_route" "new_default" {
  # Jeśli `data.aws_route.existing_default` nic nie znalazło (jego lista jest pusta), stwórz.
  count = length(data.aws_route.existing_default) == 0 ? 1 : 0

  route_table_id         = data.aws_route_table.main_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = local.internet_gateway_id
}
# --- Grupy bezpieczeństwa ---
resource "aws_security_group" "alb_sg" {
  name        = "${local.project_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
}

resource "aws_security_group" "fargate_sg" {
  name        = "${local.project_name}-fargate-sg"
  description = "Security group for Fargate services"
  vpc_id      = data.aws_vpc.default.id
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
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
}

resource "aws_security_group" "lambda_vpc_sg" {
  name        = "${local.project_name}-lambda-vpc-sg"
  description = "Security group for Lambda functions in VPC"
  vpc_id      = data.aws_vpc.default.id
  tags        = local.common_tags
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Repozytoria ECR ---
resource "aws_ecr_repository" "auth_service_repo" {
  name         = "${local.project_name_prefix}/${local.auth_service_name}" # POPRAWIONA NAZWA
  tags         = local.common_tags
  force_delete = true
}
resource "aws_ecr_repository" "file_service_repo" {
  name         = "${local.project_name_prefix}/${local.file_service_name}" # POPRAWIONA NAZWA
  tags         = local.common_tags
  force_delete = true
}
resource "aws_ecr_repository" "notification_service_repo" {
  name         = "${local.project_name_prefix}/${local.notification_service_name}" # POPRAWIONA NAZWA
  tags         = local.common_tags
  force_delete = true
}
resource "aws_ecr_repository" "frontend_repo" {
  name         = "${local.project_name_prefix}/${local.frontend_name}" # POPRAWIONA NAZWA
  tags         = local.common_tags
  force_delete = true
}

# --- Klaster ECS ---
resource "aws_ecs_cluster" "main_cluster" {
  name = "${local.project_name}-cluster"
  tags = local.common_tags
}

# --- Application Load Balancer (ALB) ---
resource "aws_lb" "main_alb" {
  name               = "${local.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids
  tags               = local.common_tags
  idle_timeout       = 60
  enable_http2       = true
  drop_invalid_header_fields = false
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Service not found - Check ALB Rules or API Gateway for Chat"
      status_code  = "404"
    }
  }
}

# --- Grupy Docelowe (Target Groups) dla ALB ---
resource "aws_lb_target_group" "auth_tg" {
  name        = "${local.project_name}-auth-tg"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"
  health_check {
    enabled             = true
    healthy_threshold   = 5
    interval            = 60
    matcher             = "200-299"
    path                = "/actuator/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 20
    unhealthy_threshold = 5
  }
  tags = local.common_tags
  lifecycle {
    create_before_destroy = true
  }
}
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
resource "aws_lb_listener_rule" "auth_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth_tg.arn
  }
  condition {
    path_pattern {
      values = ["/api/auth/*"]
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
      values = ["/api/files/*"]
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
      values = ["/api/notifications/*"]
    }
  }
}

# --- Baza Danych RDS ---
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${local.project_name}-rds-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
  tags       = local.common_tags
}
resource "aws_security_group" "rds_sg" {
  name        = "${local.project_name}-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    description     = "Allow Lambda to connect to RDS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_vpc_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
}
resource "aws_db_instance" "chat_db" {
  identifier           = "${local.project_name}-chat-db"
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "14.15"
  instance_class       = "db.t3.micro"
  db_name              = "chat_service_db"
  username             = "chatadmin"
  password             = "admin1234"
  parameter_group_name = "default.postgres14"
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot  = true
  tags = local.common_tags
}

# --- Tabele DynamoDB ---
resource "aws_dynamodb_table" "user_profiles_table" {
  name         = "${local.project_name}-user-profiles"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  attribute {
    name = "userId"
    type = "S"
  }
  tags = local.common_tags
}

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

resource "aws_dynamodb_table" "notifications_history_table" {
  name         = "${local.project_name}-notifications-history"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "notificationId"
  attribute {
    name = "notificationId"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "N"
  }
  attribute {
    name = "userId"
    type = "S"
  }
  global_secondary_index {
    name            = "userId-timestamp-index"
    hash_key        = "userId"
    range_key       = "timestamp"
    projection_type = "ALL"
  }
  tags = local.common_tags
}
# --- Bucket S3 ---
resource "aws_s3_bucket" "upload_bucket" {
  bucket        = "${local.project_name_prefix}-uploads-${random_string.suffix.result}" # POPRAWIONA NAZWA
  tags          = local.common_tags
  force_destroy = true
}
resource "aws_s3_bucket_public_access_block" "upload_bucket_access_block" {
  bucket = aws_s3_bucket.upload_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket        = "${local.project_name_prefix}-lambda-code-${random_string.suffix.result}" # POPRAWIONA NAZWA
  tags          = local.common_tags
  force_destroy = true
}


# --- AWS Cognito ---
resource "aws_cognito_user_pool" "chat_pool" {
  name = "${local.project_name}-user-pool"
  lambda_config {
    pre_sign_up = aws_lambda_function.auto_confirm_user.arn
  }
  password_policy {
    minimum_length    = 6
    require_lowercase = true
    require_numbers   = false
    require_symbols   = false
    require_uppercase = false
  }
  tags = local.common_tags
}
resource "aws_cognito_user_pool_client" "chat_pool_client" {
  name                = "${local.project_name}-client"
  user_pool_id        = aws_cognito_user_pool.chat_pool.id
  generate_secret     = false
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
}

# --- AWS SNS ---
resource "aws_sns_topic" "notifications_topic" {
  name = "${local.project_name}-notifications-topic"
  tags = local.common_tags
}

# --- Kolejka SQS ---
resource "aws_sqs_queue" "chat_notifications_queue" {
  name                        = "${local.project_name}-chat-notifications-queue"
  delay_seconds               = 0
  message_retention_seconds   = 345600
  visibility_timeout_seconds  = 60
  receive_wait_time_seconds   = 10
  tags                        = local.common_tags
}

# --- Grupy Logów CloudWatch ---
resource "aws_cloudwatch_log_group" "auth_service_logs" {
  name              = "/ecs/${local.project_name}/${local.auth_service_name}"
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
# --- Zmienne dla istniejących ról IAM ---
variable "lab_role_arn" {
  description = "ARN of the existing LabRole"
  type        = string
  default     = "arn:aws:iam::044902896603:role/LabRole"
}

variable "lab_instance_profile_name" {
  description = "Name of the existing LabInstanceProfile for Elastic Beanstalk"
  type        = string
  default     = "LabInstanceProfile"
}
# --- Definicje Zadań i Usługi ECS dla Fargate ---
resource "aws_ecs_task_definition" "app_fargate_task_definitions" {
  for_each = local.fargate_services
  family                   = "${local.project_name}-${each.key}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = var.lab_role_arn
  task_role_arn            = var.lab_role_arn
  container_definitions = jsonencode([
    {
      name      = "${each.key}-container"
      image     = "${each.value.ecr_repo_base_url}:${each.value.image_tag}"
      essential = true
      portMappings = [{ containerPort = each.value.port, hostPort = each.value.port, protocol = "tcp" }]
      environment = each.value.environment_vars
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = each.value.log_group_name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs-${each.key}"
        }
      }
    }
  ])
  tags = local.common_tags
}
resource "aws_ecs_service" "app_fargate_services" {
  for_each = local.fargate_services
  name            = "${local.project_name}-${each.key}-service"
  cluster         = aws_ecs_cluster.main_cluster.id
  task_definition = aws_ecs_task_definition.app_fargate_task_definitions[each.key].arn
  launch_type     = "FARGATE"
  desired_count   = 1
  health_check_grace_period_seconds = 120
  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.fargate_sg.id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = each.value.target_group_arn
    container_name   = "${each.key}-container"
    container_port   = each.value.port
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  deployment_controller { type = "ECS" }
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
    aws_elastic_beanstalk_environment.frontend_env
  ]
  tags = local.common_tags
}

# --- Automatyczne Skalowanie Usług ECS ---
resource "aws_appautoscaling_target" "app_fargate_scaling_targets" {
  for_each = local.fargate_services
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main_cluster.name}/${aws_ecs_service.app_fargate_services[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
resource "aws_appautoscaling_policy" "app_fargate_cpu_scaling_policies" {
  for_each = local.fargate_services
  name               = "${local.project_name}-${each.key}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.app_fargate_scaling_targets[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.app_fargate_scaling_targets[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.app_fargate_scaling_targets[each.key].service_namespace
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 75.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# --- Funkcja Lambda do automatycznego potwierdzania użytkowników Cognito ---
resource "aws_lambda_function" "auto_confirm_user" {
  function_name = "${local.project_name}-auto-confirm-user"
  runtime       = "python3.9"
  handler       = "auto_confirm_user.lambda_handler"
  role          = var.lab_role_arn
  filename         = "${path.module}/lambda/auto_confirm_user.zip"
  source_code_hash = filebase64sha256(length(fileset(path.module, "lambda/auto_confirm_user.zip")) > 0 ? "${path.module}/lambda/auto_confirm_user.zip" : "dummy")
  tags             = local.common_tags
}
resource "aws_lambda_permission" "allow_cognito" {
  statement_id  = "AllowCognitoToCallLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_confirm_user.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.chat_pool.arn
}

# --- Polityki IAM dla Lambd i Notification Service ---
# --- Polityki IAM dla Lambd i Notification Service (jako Inline Policies) ---

# Osadza politykę dla Lambd bezpośrednio w LabRole
# resource "aws_iam_role_policy" "lambda_chat_inline_policy" {
#   name = "${local.project_name}-lambda-chat-inline-policy"
#
#   # `aws_iam_role_policy` wymaga nazwy roli, a nie pełnego ARN.
#   # Funkcja split dzieli ARN (np. "arn:aws:iam::ACCOUNT:role/LabRole") po znaku "/"
#   # i bierze drugi element ([1]), czyli samą nazwę "LabRole".
#   role = split("/", var.lab_role_arn)[1]
#
#   # Definicja polityki w formacie JSON
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" },
#       { Effect = "Allow", Action = "sqs:SendMessage", Resource = aws_sqs_queue.chat_notifications_queue.arn },
#       { Effect = "Allow", Action = ["ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DeleteNetworkInterface", "ec2:AssignPrivateIpAddresses", "ec2:UnassignPrivateIpAddresses"], Resource = "*" }
#     ]
#   })
# }
#
# # Osadza politykę SQS dla serwisu notyfikacji bezpośrednio w LabRole
# resource "aws_iam_role_policy" "notification_service_sqs_inline_policy" {
#   name = "${local.project_name}-notification-service-sqs-inline-policy"
#   role = split("/", var.lab_role_arn)[1]
#
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{ Effect = "Allow", Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"], Resource = aws_sqs_queue.chat_notifications_queue.arn }]
#   })
# }
# --- Definicje funkcji Lambda dla logiki czatu ---
resource "aws_lambda_function" "send_message_lambda" {
  function_name = "${local.project_name}-SendMessageLambda"
  handler       = "pl.projektchmury.chatapp.lambda.SendMessageLambda::handleRequest"
  role          = var.lab_role_arn
  runtime       = "java17"
  memory_size   = 512
  timeout       = 30
  filename         = data.archive_file.dummy_lambda_zip.output_path
  source_code_hash = data.archive_file.dummy_lambda_zip.output_base64sha256  # s3_bucket     = aws_s3_bucket.lambda_code_bucket.id
  # s3_key        = var.lambda_chat_handlers_jar_key
  environment { variables = local.chat_lambda_common_environment_variables }
  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids # <<< POPRAWKA
    security_group_ids = [aws_security_group.lambda_vpc_sg.id]
  }
  tags = local.common_tags
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}
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
    subnet_ids         = data.aws_subnets.default.ids # <<< POPRAWKA
    security_group_ids = [aws_security_group.lambda_vpc_sg.id]
  }
  tags = local.common_tags
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}
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
    security_group_ids = [aws_security_group.lambda_vpc_sg.id]
  }
  tags = local.common_tags
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}
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
    security_group_ids = [aws_security_group.lambda_vpc_sg.id]
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
resource "aws_api_gateway_rest_api" "chat_api" {
  name        = "${local.project_name}-ChatApi"
  description = "API Gateway for Chat Lambdas"
  tags        = local.common_tags
  endpoint_configuration { types = ["REGIONAL"] }
}
resource "aws_api_gateway_authorizer" "cognito_authorizer_for_chat_api" {
  name                              = "${local.project_name}-CognitoChatAuthorizer"
  rest_api_id                       = aws_api_gateway_rest_api.chat_api.id
  type                              = "COGNITO_USER_POOLS"
  provider_arns                     = [aws_cognito_user_pool.chat_pool.arn]
  identity_source                   = "method.request.header.Authorization"
  authorizer_result_ttl_in_seconds  = 300
}

# Zasoby i Metody API Gateway
resource "aws_api_gateway_resource" "messages_resource" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  parent_id   = aws_api_gateway_rest_api.chat_api.root_resource_id
  path_part   = "messages"
}
resource "aws_api_gateway_method" "send_message_post_method" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.messages_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer_for_chat_api.id
}
resource "aws_api_gateway_integration" "send_message_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.chat_api.id
  resource_id             = aws_api_gateway_resource.messages_resource.id
  http_method             = aws_api_gateway_method.send_message_post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.send_message_lambda.invoke_arn
}
resource "aws_lambda_permission" "apigw_lambda_send_message" {
  statement_id  = "AllowAPIGatewayInvokeSendMessageLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_message_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chat_api.execution_arn}/*/${aws_api_gateway_method.send_message_post_method.http_method}${aws_api_gateway_resource.messages_resource.path}"
}
resource "aws_api_gateway_resource" "messages_sent_resource" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  parent_id   = aws_api_gateway_resource.messages_resource.id
  path_part   = "sent"
}
resource "aws_api_gateway_method" "get_sent_messages_method" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.messages_sent_resource.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer_for_chat_api.id
  request_parameters = { "method.request.querystring.username" = true }
}
resource "aws_api_gateway_integration" "get_sent_messages_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.chat_api.id
  resource_id             = aws_api_gateway_resource.messages_sent_resource.id
  http_method             = aws_api_gateway_method.get_sent_messages_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_sent_messages_lambda.invoke_arn
}
resource "aws_lambda_permission" "apigw_lambda_get_sent_messages" {
  statement_id  = "AllowAPIGatewayInvokeGetSentMessagesLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_sent_messages_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chat_api.execution_arn}/*/${aws_api_gateway_method.get_sent_messages_method.http_method}${aws_api_gateway_resource.messages_sent_resource.path}"
}
resource "aws_api_gateway_resource" "messages_received_resource" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  parent_id   = aws_api_gateway_resource.messages_resource.id
  path_part   = "received"
}
resource "aws_api_gateway_method" "get_received_messages_method" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.messages_received_resource.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer_for_chat_api.id
  request_parameters = { "method.request.querystring.username" = true }
}
resource "aws_api_gateway_integration" "get_received_messages_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.chat_api.id
  resource_id             = aws_api_gateway_resource.messages_received_resource.id
  http_method             = aws_api_gateway_method.get_received_messages_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_received_messages_lambda.invoke_arn
}
resource "aws_lambda_permission" "apigw_lambda_get_received_messages" {
  statement_id  = "AllowAPIGatewayInvokeGetReceivedMessagesLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_received_messages_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chat_api.execution_arn}/*/${aws_api_gateway_method.get_received_messages_method.http_method}${aws_api_gateway_resource.messages_received_resource.path}"
}
resource "aws_api_gateway_resource" "message_id_resource" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  parent_id   = aws_api_gateway_resource.messages_resource.id
  path_part   = "{messageId}"
}
resource "aws_api_gateway_resource" "mark_as_read_resource" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  parent_id   = aws_api_gateway_resource.message_id_resource.id
  path_part   = "mark-as-read"
}
resource "aws_api_gateway_method" "mark_as_read_method" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.mark_as_read_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer_for_chat_api.id
  request_parameters = { "method.request.path.messageId" = true }
}
resource "aws_api_gateway_integration" "mark_as_read_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.chat_api.id
  resource_id             = aws_api_gateway_resource.mark_as_read_resource.id
  http_method             = aws_api_gateway_method.mark_as_read_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.mark_message_as_read_lambda.invoke_arn
}
resource "aws_lambda_permission" "apigw_lambda_mark_as_read" {
  statement_id  = "AllowAPIGatewayInvokeMarkAsReadLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mark_message_as_read_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chat_api.execution_arn}/*/${aws_api_gateway_method.mark_as_read_method.http_method}${aws_api_gateway_resource.mark_as_read_resource.path}"
}

# Metody OPTIONS dla CORS
resource "aws_api_gateway_method" "messages_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.messages_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "messages_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.messages_resource.id
  http_method = aws_api_gateway_method.messages_options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}
resource "aws_api_gateway_method_response" "messages_options_200" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.messages_resource.id
  http_method   = aws_api_gateway_method.messages_options_method.http_method
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
resource "aws_api_gateway_integration_response" "messages_options_integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.messages_resource.id
  http_method = aws_api_gateway_method.messages_options_method.http_method
  status_code = aws_api_gateway_method_response.messages_options_200.status_code # Powinno być "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'" # Metody dozwolone na /messages i jego podzasobach
    # "method.response.header.Access-Control-Allow-Origin"  = "'http://${aws_elastic_beanstalk_environment.frontend_env.cname}'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  response_templates = {
    "application/json" = "" # Dla MOCK, może być puste
  }
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
    # "method.response.header.Access-Control-Allow-Origin"  = "'http://${aws_elastic_beanstalk_environment.frontend_env.cname}'"
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
    # "method.response.header.Access-Control-Allow-Origin"  = "'http://${aws_elastic_beanstalk_environment.frontend_env.cname}'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  response_templates = {
    "application/json" = ""
  }
  depends_on = [aws_api_gateway_integration.messages_received_options_integration]
}

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

# Zmienna dla klucza S3 dla JARa inicjalizatora
variable "db_initializer_jar_key" {
  description = "S3 key for the DB Initializer Lambda JAR file"
  type        = string
  default     = "db-initializer-lambda.jar"
}

# Definicja funkcji Lambda do inicjalizacji schematu DB
resource "aws_lambda_function" "db_initializer_lambda" {
  # Upewnij się, że ta funkcja jest tworzona dopiero po utworzeniu bazy danych
  depends_on = [aws_db_instance.chat_db]

  function_name = "${local.project_name}-DbSchemaInitializer"
  handler       = "pl.projektchmury.dbinitializer.SchemaInitializerLambda::handleRequest"
  role          = var.lab_role_arn
  runtime       = "java17"
  memory_size   = 1024
  timeout       = 300 # Dajemy więcej czasu na zimny start i połączenie z DB
  filename         = data.archive_file.dummy_lambda_zip.output_path
  source_code_hash = data.archive_file.dummy_lambda_zip.output_base64sha256

  # Używamy tych samych zmiennych środowiskowych co inne Lambdy czatu
  environment {
    variables = local.chat_lambda_common_environment_variables
  }

  # Ta funkcja również musi być w VPC, aby połączyć się z RDS
  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids # <<< POPRAWKA
    security_group_ids = [aws_security_group.lambda_vpc_sg.id]
  }

  tags = local.common_tags
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}

# --- VPC Endpoint dla SQS ---
# Pozwala zasobom wewnątrz VPC (jak nasze Lambdy) komunikować się z SQS
# bez potrzeby posiadania dostępu do publicznego internetu (przez NAT Gateway).
resource "aws_vpc_endpoint" "sqs_endpoint" {
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.sqs"
  vpc_endpoint_type = "Interface" # Typ 'Interface' tworzy interfejs sieciowy w podsieciach

  subnet_ids         = data.aws_subnets.default.ids # <<< POPRAWKA
  security_group_ids = [aws_security_group.lambda_vpc_sg.id]
  private_dns_enabled = true # Pozwala używać standardowych DNS (np. sqs.us-east-1.amazonaws.com) wewnątrz VPC

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-sqs-vpc-endpoint"
  })
}
resource "null_resource" "invoke_db_initializer" {
  # Ta sekcja będzie wykonana tylko wtedy, gdy zmieni się ARN bazy danych (czyli przy jej tworzeniu)
  triggers = {
    db_instance_arn = aws_db_instance.chat_db.arn
  }

  # Wywołaj funkcję Lambda
  provisioner "local-exec" {
    # Użycie podwójnych cudzysłowów jest bardziej kompatybilne z Windows/MINGW64
    command = "aws lambda invoke --function-name ${aws_lambda_function.db_initializer_lambda.function_name} --payload \"{}\" --cli-binary-format raw-in-base64-out out.json"
  }
  # Upewnij się, że provisioner jest uruchamiany po utworzeniu funkcji Lambda
  depends_on = [aws_lambda_function.db_initializer_lambda]
}
# --- Grupa Bezpieczeństwa dla instancji Elastic Beanstalk ---
resource "aws_security_group" "eb_sg" {
  name        = "${local.project_name}-eb-sg"
  description = "Security group for Elastic Beanstalk environment instances"
  vpc_id      = data.aws_vpc.default.id

  # Zezwól na ruch przychodzący na porcie 3000 (port kontenera frontendu)
  # z dowolnego miejsca. To pozwoli health checkerowi EB i użytkownikom
  # dotrzeć do aplikacji (chociaż ruch i tak będzie szedł przez CNAME).
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow traffic to Frontend container"
  }

  # Zezwól na cały ruch wychodzący (np. po aktualizacje, pobranie obrazu Docker z ECR)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
}
# Deployment i Stage API Gateway
resource "aws_api_gateway_deployment" "chat_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
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
  lifecycle { create_before_destroy = true }
  depends_on = [
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
resource "aws_api_gateway_stage" "chat_api_stage_v1" {
  deployment_id = aws_api_gateway_deployment.chat_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  stage_name    = "v1"
  tags          = local.common_tags
  # Zakomentowane logowanie, aby uniknąć błędu konfiguracji na koncie
  # access_log_settings {
  #   destination_arn = aws_cloudwatch_log_group.api_gateway_chat_logs.arn
  #   format          = jsonencode({ /* ... format ... */ })
  # }
}
# Zakomentowane, aby uniknąć błędu, jeśli nie można skonfigurować roli dla logów API GW
# resource "aws_cloudwatch_log_group" "api_gateway_chat_logs" {
#   name              = "/aws/api-gateway/${local.project_name}-ChatApi-v1"
#   retention_in_days = 7
#   tags              = local.common_tags
# }

# --- Aplikacja Elastic Beanstalk dla frontendu ---
resource "aws_elastic_beanstalk_application" "frontend_app" {
  name        = "${local.project_name}-frontend-app"
  description = "Frontend for Projekt Chmury V2"
  tags        = local.common_tags
}
locals {
  frontend_dockerrun_content = jsonencode({
    AWSEBDockerrunVersion = "1",
    Image = { Name = "${aws_ecr_repository.frontend_repo.repository_url}:${var.frontend_image_tag}", Update = "true" },
    Ports = [{ ContainerPort = 3000 }]
  })
}
resource "aws_s3_object" "frontend_dockerrun" {
  bucket  = aws_s3_bucket.upload_bucket.id
  key     = "Dockerrun.aws.json.${random_string.suffix.result}"
  content = local.frontend_dockerrun_content
  etag    = md5(local.frontend_dockerrun_content)
}
resource "aws_elastic_beanstalk_application_version" "frontend_app_version" {
  name        = "${local.project_name}-frontend-v1-${random_string.suffix.result}"
  application = aws_elastic_beanstalk_application.frontend_app.name
  bucket      = aws_s3_bucket.upload_bucket.id
  key         = aws_s3_object.frontend_dockerrun.key
  description = "Frontend application version from ECR"
}
resource "aws_elastic_beanstalk_environment" "frontend_env" {
  name                = "${local.project_name}-frontend-env"
  application         = aws_elastic_beanstalk_application.frontend_app.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.5.1 running Docker"
  version_label       = aws_elastic_beanstalk_application_version.frontend_app_version.name

  # Zmienne środowiskowe zostają bez zmian

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_AUTH_API_URL"
    value     = "http://${aws_lb.main_alb.dns_name}/api/auth"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_CHAT_API_URL" # POPRAWNA NAZWA
    value     = "${aws_api_gateway_stage.chat_api_stage_v1.invoke_url}/messages"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_FILE_API_URL" # POPRAWNA NAZWA
    value     = "http://${aws_lb.main_alb.dns_name}/api/files"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_NOTIFICATION_API_URL" # POPRAWNA NAZWA
    value     = "http://${aws_lb.main_alb.dns_name}/api/notifications"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "TF_DEPENDENCIES_READY"
    value     = "ALB: ${aws_lb.main_alb.id}, APIGW: ${aws_api_gateway_rest_api.chat_api.id}, SG: ${aws_security_group.eb_sg.id}"
  }
  # --- DODAJ TE BLOKI ---
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = data.aws_vpc.default.id
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    # Używamy join, ponieważ EB oczekuje stringa z podsieciami po przecinku
    value     = join(",", data.aws_subnets.default.ids)
  }
  setting {
    # Upewnij się, że instancje w EB dostają publiczne IP, aby mogły np. pobrać obraz z ECR
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "true"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.eb_sg.id # Przypisujemy ID naszej nowej grupy
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = var.lab_instance_profile_name
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = var.lab_role_arn # Używamy pełnego ARN roli LabRole
  }
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
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "HealthCheckPath"
    value     = "/" # Upewnij się, że health check sprawdza ścieżkę główną
  }

  setting {
    namespace = "aws:elasticbeanstalk:application"
    name      = "Application Healthcheck URL"
    value     = "/" # To jest to samo, ale dla innej warstwy konfiguracji
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.micro" # <--- ZMIANA NA BARDZIEJ DOSTĘPNY TYP
  }

  wait_for_ready_timeout = "40m"
  tags                   = local.common_tags
  # Zależność jest teraz od ZAKOŃCZENIA opóźnienia, które czeka na regułę.
  depends_on = [time_sleep.wait_for_propagation]
}
# Ten zasób wstrzymuje wykonanie Terraformu, aby dać AWS czas
# na pełną propagację informacji o nowej grupie bezpieczeństwa.
# Ten zasób wstrzymuje wykonanie Terraformu, aby dać AWS czas
# na pełną propagację informacji o nowo stworzonych zasobach sieciowych.
resource "time_sleep" "wait_for_propagation" {
  # Czekamy 30 sekund. To powinno wystarczyć.
  create_duration = "30s"

  # WAŻNE: Ta pauza uruchomi się dopiero PO pomyślnym utworzeniu
  # grupy bezpieczeństwa dla EB. W ten sposób tworzymy barierę.
  depends_on = [aws_security_group.eb_sg]
}

# --- Wyjścia (Outputs) ---
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

output "eb_environment_name" {
  description = "Name of the Elastic Beanstalk environment"
  value       = aws_elastic_beanstalk_environment.frontend_env.name
}
output "ecs_service_names" {
  description = "A map of ECS service names"
  value = {
    for name, service in aws_ecs_service.app_fargate_services :
    name => service.name
  }
}
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

// Zaktualizuj też nazwy usług w KROKU 4 w skrypcie, aby pasowały do tego, co generuje Terraform!
// Np. `aws ecs update-service --cluster "${CLUSTER_NAME}" --service "${local.project_name}-auth-service-service" --force-new-deployment`
// Możesz je też dodać do outputów dla pewności.
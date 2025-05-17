provider "aws" {
  region = "us-east-1"
}

variable "auth_service_image_tag" {
  description = "Docker image tag for auth-service"
  type        = string
  default     = "v1.0.1"
}
variable "chat_service_image_tag" {
  description = "Docker image tag for chat-service"
  type        = string
  default     = "v1.0.0"
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

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# W pliku: terraform/main.tf

locals {
  project_name_prefix = "projekt-chmury-v2"
  project_name        = "${local.project_name_prefix}-${random_string.suffix.result}"

  common_tags = {
    Project     = local.project_name_prefix
    Environment = "dev"
    Suffix      = random_string.suffix.result
  }

  auth_service_name         = "auth-service"
  chat_service_name         = "chat-service"
  file_service_name         = "file-service"
  notification_service_name = "notification-service"
  frontend_name             = "frontend"

  # =====================================================================================
  # SEKCJA, KTÓRĄ MODYFIKUJEMY: locals.fargate_services
  # Dodajemy nową zmienną środowiskową "APP_CORS_ALLOWED_ORIGIN_FRONTEND"
  # do każdego serwisu backendowego.
  # =====================================================================================
  fargate_services = {
    (local.auth_service_name) = {
      port               = 8081
      ecr_repo_base_url  = aws_ecr_repository.auth_service_repo.repository_url
      image_tag          = var.auth_service_image_tag
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
        # --- POCZĄTEK ZMIANY dla auth-service ---
        { name = "APP_CORS_ALLOWED_ORIGIN_FRONTEND", value = "http://${aws_elastic_beanstalk_environment.frontend_env.cname}" }
        # --- KONIEC ZMIANY dla auth-service ---
      ]
      depends_on_db      = false
      depends_on_s3_ddb  = false
      depends_on_sns_ddb = false
    },
    (local.chat_service_name) = {
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
        { name = "SPRING_DATASOURCE_URL", value = "jdbc:postgresql://${aws_db_instance.chat_db.address}:${aws_db_instance.chat_db.port}/${aws_db_instance.chat_db.db_name}" },
        { name = "SPRING_DATASOURCE_USERNAME", value = aws_db_instance.chat_db.username },
        { name = "SPRING_DATASOURCE_PASSWORD", value = aws_db_instance.chat_db.password },
        { name = "APP_SERVICES_NOTIFICATION_URL", value = "http://${aws_lb.main_alb.dns_name}/api/notifications" },
        # --- POCZĄTEK ZMIANY dla chat-service ---
        { name = "APP_CORS_ALLOWED_ORIGIN_FRONTEND", value = "http://${aws_elastic_beanstalk_environment.frontend_env.cname}" }
        # --- KONIEC ZMIANY dla chat-service ---
      ]
      depends_on_db      = true
      depends_on_s3_ddb  = false
      depends_on_sns_ddb = false
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
        # --- POCZĄTEK ZMIANY dla file-service ---
        { name = "APP_CORS_ALLOWED_ORIGIN_FRONTEND", value = "http://${aws_elastic_beanstalk_environment.frontend_env.cname}" }
        # --- KONIEC ZMIANY dla file-service ---
      ]
      depends_on_db      = false
      depends_on_s3_ddb  = true
      depends_on_sns_ddb = false
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
        # --- POCZĄTEK ZMIANY dla notification-service ---
        { name = "APP_CORS_ALLOWED_ORIGIN_FRONTEND", value = "http://${aws_elastic_beanstalk_environment.frontend_env.cname}" }
        # --- KONIEC ZMIANY dla notification-service ---
      ]
      depends_on_db      = false
      depends_on_s3_ddb  = false
      depends_on_sns_ddb = true
    }
  }
}


data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}


variable "lab_role_arn" {
  description = "ARN of the existing LabRole"
  type        = string
  default     = "arn:aws:iam::044902896603:role/LabRole" # ZAKTUALIZOWANE
}

variable "lab_instance_profile_name" {
  description = "Name of the existing LabInstanceProfile for Elastic Beanstalk"
  type        = string
  default     = "LabInstanceProfile" # Nazwa profilu, nie ARN
}

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
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress { // Dodaj tę regułę do testów
    from_port   = 0
    to_port     = 0
    protocol    = "-1" // All traffic
    cidr_blocks = ["0.0.0.0/0"] // Lub zawęź do VPC CIDR / Fargate SG
  }
  tags = local.common_tags
}

resource "aws_security_group" "fargate_sg" {
  name        = "${local.project_name}-fargate-sg"
  description = "Security group for Fargate services"
  vpc_id      = data.aws_vpc.default.id

  ingress { // Dla auth-service
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
}

resource "aws_ecr_repository" "auth_service_repo" {
  name = "${local.project_name_prefix}/${local.auth_service_name}"
  tags = local.common_tags
  force_delete = true
}
resource "aws_ecr_repository" "chat_service_repo" {
  name = "${local.project_name_prefix}/${local.chat_service_name}"
  tags = local.common_tags
  force_delete = true
}
resource "aws_ecr_repository" "file_service_repo" {
  name = "${local.project_name_prefix}/${local.file_service_name}"
  tags = local.common_tags
  force_delete = true
}
resource "aws_ecr_repository" "notification_service_repo" {
  name = "${local.project_name_prefix}/${local.notification_service_name}"
  tags = local.common_tags
  force_delete = true
}
resource "aws_ecr_repository" "frontend_repo" {
  name = "${local.project_name_prefix}/${local.frontend_name}"
  tags = local.common_tags
  force_delete = true
}

resource "aws_ecs_cluster" "main_cluster" {
  name = "${local.project_name}-cluster"
  tags = local.common_tags
}

resource "aws_lb" "main_alb" {
  name               = "${local.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids
  tags               = local.common_tags
  idle_timeout = 60
  enable_http2 = true
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
      message_body = "Service not found - Check ALB Rules"
      status_code  = "404"
    }
  }
}

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

resource "aws_lb_target_group" "chat_tg" {
  name        = "${local.project_name}-chat-tg"
  port        = 8082
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

resource "aws_lb_listener_rule" "chat_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 110
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.chat_tg.arn
  }
  condition {
    path_pattern {
      values = ["/api/messages", "/api/messages/*"]
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

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${local.project_name}-rds-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
  tags       = local.common_tags
}

resource "aws_security_group" "rds_sg" {
  name        = "${local.project_name}-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = data.aws_vpc.default.id // Upewnij się, że to poprawna VPC

  ingress {
    from_port       = 5432 // Port PostgreSQL
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.fargate_sg.id] // Zezwól na ruch z Fargate SG
  }

  // Reguły wychodzące zazwyczaj mogą być bardziej liberalne dla RDS,
  // np. aby umożliwić pobieranie patchy, chyba że masz specyficzne wymagania.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_db_instance" "chat_db" {
  identifier        = "${local.project_name}-chat-db"
  allocated_storage = 20
  engine            = "postgres"
  engine_version    = "14.15"
  instance_class    = "db.t3.micro"
  db_name           = "chat_service_db"
  username          = "chatadmin"
  ### DOSTOSUJ ### Zmień hasło i użyj Secrets Manager w produkcji!
  password               = "admin1234"
  parameter_group_name   = "default.postgres14"
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  # publicly_accessible  = false # W domyślnej VPC, jeśli podsieci są publiczne, to może być true
  # lub jeśli podsieci są prywatne, to false i dostęp przez SG
  tags = local.common_tags
}

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
  # range_key    = "timestamp"
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

resource "aws_s3_bucket" "upload_bucket" {
  bucket = "${local.project_name_prefix}-uploads-${random_string.suffix.result}"
  tags   = local.common_tags
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "upload_bucket_access_block" {
  bucket                  = aws_s3_bucket.upload_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cognito_user_pool" "chat_pool" {
  name = "${local.project_name}-user-pool"
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
  tags = local.common_tags
}

resource "aws_cognito_user_pool_client" "chat_pool_client" {
  name                = "${local.project_name}-client"
  user_pool_id        = aws_cognito_user_pool.chat_pool.id
  generate_secret     = false
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  # tags                = local.common_tags
}

resource "aws_sns_topic" "notifications_topic" {
  name = "${local.project_name}-notifications-topic"
  tags = local.common_tags
}

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
      # POPRAWKA: Używamy bezpośrednio each.value.ecr_repo_url, który już zawiera tag
      image     = "${each.value.ecr_repo_base_url}:${each.value.image_tag}"
      essential = true
      portMappings = [
        { containerPort = each.value.port, hostPort = each.value.port, protocol = "tcp" }
      ]
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
  desired_count   = 2
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
    aws_lb_listener_rule.chat_rule,
    aws_lb_listener_rule.file_rule,
    aws_lb_listener_rule.notification_rule,
    aws_db_instance.chat_db,                        # chat-service zależy od tego
    aws_s3_bucket.upload_bucket,                    # file-service zależy od tego
    aws_dynamodb_table.file_metadata_table,         # file-service zależy od tego
    aws_sns_topic.notifications_topic,              # notification-service zależy od tego
    aws_dynamodb_table.notifications_history_table, # notification-service zależy od tego
    aws_dynamodb_table.user_profiles_table          # auth-service może zależeć od tego
  ]

  tags = local.common_tags
}

resource "aws_appautoscaling_target" "app_fargate_scaling_targets" {
  for_each = local.fargate_services

  max_capacity       = 4
  min_capacity       = 2
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

resource "aws_lambda_function" "auto_confirm_user" {
  function_name = "${local.project_name}-auto-confirm-user"
  runtime       = "python3.9"
  handler       = "auto_confirm_user.lambda_handler"
  role          = var.lab_role_arn

  filename         = "${path.module}/lambda/auto_confirm_user.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/auto_confirm_user.zip")
  tags             = local.common_tags
  # depends_on       = [aws_iam_role_policy_attachment.lambda_basic_execution_lab]
}


# resource "aws_iam_role_policy_attachment" "lambda_basic_execution_lab" {
#   role       = split("/", var.lab_role_arn)[1] # Pobierz nazwę roli z ARN
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
# }

resource "aws_lambda_permission" "allow_cognito" {
  statement_id  = "AllowCognitoToCallLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_confirm_user.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.chat_pool.arn
}

resource "aws_elastic_beanstalk_application" "frontend_app" {
  name        = "${local.project_name}-frontend-app"
  description = "Frontend for Projekt Chmury V2"
  tags        = local.common_tags
}

locals {
  frontend_dockerrun_content = jsonencode({
    AWSEBDockerrunVersion = "1",
    Image = {
      Name   = "${aws_ecr_repository.frontend_repo.repository_url}:${var.frontend_image_tag}", // <-- DODAJ PRZECINEK
      Update = "true"
    },
    Ports = [
      {
        ContainerPort = 3000
      }
    ]
  })
}


resource "aws_s3_object" "frontend_dockerrun" {
  bucket  = aws_s3_bucket.upload_bucket.bucket
  key     = "Dockerrun.aws.json.${random_string.suffix.result}"
  content = local.frontend_dockerrun_content
  etag    = md5(local.frontend_dockerrun_content)
}

resource "aws_elastic_beanstalk_application_version" "frontend_app_version" {
  name        = "${local.project_name}-frontend-v1-${random_string.suffix.result}"
  application = aws_elastic_beanstalk_application.frontend_app.name
  bucket      = aws_s3_bucket.upload_bucket.bucket
  key         = aws_s3_object.frontend_dockerrun.key
  description = "Frontend application version from ECR"
}

resource "aws_elastic_beanstalk_environment" "frontend_env" {
  name                = "${local.project_name}-frontend-env"
  application         = aws_elastic_beanstalk_application.frontend_app.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.5.1 running Docker"
  version_label       = aws_elastic_beanstalk_application_version.frontend_app_version.name

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_AUTH_API_URL" # Poprawna nazwa
    value     = "http://${aws_lb.main_alb.dns_name}/api/auth"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_CHAT_API_URL" # Poprawna nazwa
    value     = "http://${aws_lb.main_alb.dns_name}/api/messages"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_FILE_API_URL" # Poprawna nazwa
    value     = "http://${aws_lb.main_alb.dns_name}/api/files"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_NOTIFICATION_API_URL" # Poprawna nazwa
    value     = "http://${aws_lb.main_alb.dns_name}/api/notifications"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = var.lab_instance_profile_name
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
  wait_for_ready_timeout = "30m"
  tags                   = local.common_tags
}

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

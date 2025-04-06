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

#############################
# RDS — PostgreSQL instance #
#############################
resource "aws_db_instance" "mydb" {
  identifier           = "terraform-mydb-${random_string.suffix.result}"
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "14.15"
  instance_class       = "db.t3.micro"
  db_name              = "mydatabase"
  username             = "postgres"
  password             = "admin1234"
  parameter_group_name = "default.postgres14"
  skip_final_snapshot  = true
  publicly_accessible = true
}

output "db_endpoint" {
  value = aws_db_instance.mydb.address
}

#####################
# S3 — File uploads & App Versions
#####################
resource "aws_s3_bucket" "upload_bucket" {
  bucket = "terraform-projekt-chmury-uploads-${random_string.suffix.result}"
}

# Przesyłanie plików do S3 (upewnij się, że ścieżki są poprawne)
resource "aws_s3_object" "backend_app_zip" {
  bucket = aws_s3_bucket.upload_bucket.bucket
  key    = "backend-app.zip"
  source = "../backend/backend-app.zip"  # Dopasuj ścieżkę do pliku
  etag   = filemd5("../backend/backend-app.zip")
}

resource "aws_s3_object" "frontend_app_zip" {
  bucket = aws_s3_bucket.upload_bucket.bucket
  key    = "frontend-app.zip"
  source = "../frontend/frontend-app.zip"  # Dopasuj ścieżkę do pliku
  etag   = filemd5("../frontend/frontend-app.zip")
}

###########################
# CloudWatch — Log Group  #
###########################
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/terraform/projekt-chmury/app-logs-${random_string.suffix.result}"
  retention_in_days = 30
}

###########################
# Cognito — User Pool and Client
###########################
resource "aws_cognito_user_pool" "chat_pool" {
  name = "terraform-projekt-chmury-user-pool-${random_string.suffix.result}"

  # Polityka haseł:
  password_policy {
    minimum_length    = 6
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
    temporary_password_validity_days = 7
  }

  # np. automatycznie weryfikuj email:
  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_client" "chat_pool_client" {
  name         = "terraform-projekt-chmury-client-${random_string.suffix.result}"
  user_pool_id = aws_cognito_user_pool.chat_pool.id
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
}

#######################
# ECR Repositories
#######################
resource "aws_ecr_repository" "backend_repo" {
  name = "terraform-projekt-chmury-backend-${random_string.suffix.result}"
}

resource "aws_ecr_repository" "frontend_repo" {
  name = "terraform-projekt-chmury-frontend-${random_string.suffix.result}"
}

#########################################
# Elastic Beanstalk — Backend Application
#########################################
resource "aws_elastic_beanstalk_application" "backend_app" {
  name        = "terraform-backend-app-${random_string.suffix.result}"
  description = "Backend for Projekt Chmury"
}

resource "aws_elastic_beanstalk_application_version" "backend_app_version" {
  name        = "terraform-backend-app-v1-${filemd5("../backend/backend-app.zip")}"
  application = aws_elastic_beanstalk_application.backend_app.name
  bucket      = aws_s3_bucket.upload_bucket.bucket
  key         = aws_s3_object.backend_app_zip.key
  description = "Backend application version 1"
}

resource "aws_elastic_beanstalk_environment" "backend_env" {
  name                = "terraform-backend-env-${random_string.suffix.result}"
  application         = aws_elastic_beanstalk_application.backend_app.name
  solution_stack_name = "64bit Amazon Linux 2 v4.0.8 running Docker"
  version_label       = aws_elastic_beanstalk_application_version.backend_app_version.name

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = "arn:aws:iam::107378568397:role/LabRole"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "LabInstanceProfile"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "SPRING_DATASOURCE_URL"
    value     = "jdbc:postgresql://${aws_db_instance.mydb.address}:5432/mydatabase"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "SPRING_DATASOURCE_USERNAME"
    value     = aws_db_instance.mydb.username
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "SPRING_DATASOURCE_PASSWORD"
    value     = aws_db_instance.mydb.password
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "S3_BUCKET_NAME"
    value     = aws_s3_bucket.upload_bucket.bucket
  }

  # Przekazanie konfiguracji Cognito do backendu
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "aws.cognito.userPoolId"
    value     = aws_cognito_user_pool.chat_pool.id
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "aws.cognito.clientId"
    value     = aws_cognito_user_pool_client.chat_pool_client.id
  }

  wait_for_ready_timeout = "30m"
}

#########################################
# Elastic Beanstalk — Frontend Application
#########################################
resource "aws_elastic_beanstalk_application" "frontend_app" {
  name        = "terraform-frontend-app-${random_string.suffix.result}"
  description = "Frontend for Projekt Chmury"
}

resource "aws_elastic_beanstalk_application_version" "frontend_app_version" {
  name        = "terraform-frontend-app-v1-${filemd5("../frontend/frontend-app.zip")}"
  application = aws_elastic_beanstalk_application.frontend_app.name
  bucket      = aws_s3_bucket.upload_bucket.bucket
  key         = aws_s3_object.frontend_app_zip.key
  description = "Frontend application version 1"
}


resource "aws_elastic_beanstalk_environment" "frontend_env" {
  name                = "terraform-frontend-env-${random_string.suffix.result}"
  application         = aws_elastic_beanstalk_application.frontend_app.name
  solution_stack_name = "64bit Amazon Linux 2 v4.0.8 running Docker"
  version_label       = aws_elastic_beanstalk_application_version.frontend_app_version.name

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_API_URL"
    value     = "http://${aws_elastic_beanstalk_environment.backend_env.cname}/api"
  }

  # Usuwamy blok "Image" – wersja aplikacji (zip) określa już obraz
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "LabInstanceProfile"
  }

  wait_for_ready_timeout = "30m"
}

resource "aws_lambda_function" "auto_confirm_user" {
  function_name = "auto-confirm-user"
  runtime       = "python3.9"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.lambda_cognito_triggers.arn

  # Plik zip z kodem Lambdy (np. w folderze lambda/)
  filename         = "${path.module}/lambda/auto_confirm_user.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/auto_confirm_user.zip")
}

resource "aws_iam_role" "lambda_cognito_triggers" {
  name               = "lambda_cognito_triggers"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
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

# Sam user pool:
resource "aws_cognito_user_pool" "chat_pool" {
  name = "terraform-projekt-chmury-user-pool-${random_string.suffix.result}"

  # Podłączamy naszą Lambdę w lambda_config
  lambda_config {
    pre_sign_up = aws_lambda_function.auto_confirm_user.arn
  }

  # Polityka haseł
  password_policy {
    minimum_length    = 6
    require_lowercase = true
    require_numbers   = false
    require_symbols   = false
    require_uppercase = false
    temporary_password_validity_days = 7
  }

  auto_verified_attributes = ["email"]
}


###########################
# Outputs
###########################
output "backend_url" {
  value = "http://${aws_elastic_beanstalk_environment.backend_env.cname}"
}

output "frontend_url" {
  value = "http://${aws_elastic_beanstalk_environment.frontend_env.cname}"
}

output "database_endpoint" {
  value = aws_db_instance.mydb.address
}

output "s3_bucket" {
  value = aws_s3_bucket.upload_bucket.bucket
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.chat_pool.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.chat_pool_client.id
}

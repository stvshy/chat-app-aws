provider "aws" {
  region = "us-east-1"
}

#############################
# RDS — PostgreSQL instance #
#############################

resource "aws_db_instance" "mydb" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "14.15"
  instance_class       = "db.t3.micro"
  db_name              = "mydatabase"
  username             = "postgres"
  password             = "admin1234"
  parameter_group_name = "default.postgres14"
  skip_final_snapshot  = true
}

output "db_endpoint" {
  value = aws_db_instance.mydb.address
}

#########################################
# Elastic Beanstalk — Backend Application
#########################################

resource "aws_elastic_beanstalk_application" "backend_app" {
  name        = "backend-app"
  description = "Backend for Projekt Chmury"
}

resource "aws_elastic_beanstalk_environment" "backend_env" {
  name                = "backend-env"
  application         = aws_elastic_beanstalk_application.backend_app.name
  solution_stack_name = "64bit Amazon Linux 2 v4.0.8 running Docker"


  # --- SERVICE ROLE ---
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = "arn:aws:iam::107378568397:role/LabRole"
  }

  # --- EC2 INSTANCE PROFILE ---
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



  wait_for_ready_timeout = "30m"
}

#########################################
# Elastic Beanstalk — Frontend Application
#########################################

resource "aws_elastic_beanstalk_application" "frontend_app" {
  name        = "frontend-app"
  description = "Frontend for Projekt Chmury"
}

resource "aws_elastic_beanstalk_environment" "frontend_env" {
  name                = "frontend-env"
  application         = aws_elastic_beanstalk_application.frontend_app.name
  # version_label       = aws_elastic_beanstalk_application_version.frontend_app_version.name
  solution_stack_name = "64bit Amazon Linux 2 v4.0.8 running Docker"

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "VITE_API_URL"
    value = "http://${aws_elastic_beanstalk_environment.backend_env.cname}/api"

  }

  setting {
    namespace = "aws:elasticbeanstalk:container:docker"
    name      = "Image"
    value     = "${aws_ecr_repository.frontend_repo.repository_url}:latest"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "aws-elasticbeanstalk-ec2-role"
  }

  wait_for_ready_timeout = "30m"
}

######################
# S3 — File uploads  #
######################

resource "aws_s3_bucket" "upload_bucket" {
 bucket = "projekt-chmury-uploads"
}

###########################
# CloudWatch — Log Group  #
###########################

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/projekt-chmury/app-logs"
  retention_in_days = 30
}

###########################
# Cognito — User Pool and Client
###########################

resource "aws_cognito_user_pool" "chat_pool" {
  name = "projekt-chmury-user-pool"
}

resource "aws_cognito_user_pool_client" "chat_pool_client" {
  name         = "projekt-chmury-client"
  user_pool_id = aws_cognito_user_pool.chat_pool.id
}

///////

resource "aws_ecr_repository" "backend_repo" {
  name = "projekt-chmury-backend"
}

resource "aws_ecr_repository" "frontend_repo" {
  name = "projekt-chmury-frontend"
}
resource "aws_elastic_beanstalk_application_version" "backend_app_version" {
  name        = "backend-app-v1"
  application = aws_elastic_beanstalk_application.backend_app.name
  bucket      = aws_s3_bucket.upload_bucket.bucket
  key         = "backend-app.zip"
  description = "Backend application version 1"
}
resource "aws_elastic_beanstalk_application_version" "frontend_app_version" {
  name        = "frontend-app-v1"
  application = aws_elastic_beanstalk_application.frontend_app.name
  bucket      = aws_s3_bucket.upload_bucket.bucket
  key         = "frontend-app.zip"
  description = "Frontend application version 1"
}

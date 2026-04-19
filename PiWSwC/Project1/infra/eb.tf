data "aws_elastic_beanstalk_solution_stack" "docker" {
  most_recent = true
  name_regex  = "^64bit Amazon Linux 2023 (.*) running Docker$"
}

resource "aws_elastic_beanstalk_application" "chat_app" {
  name        = "chatapp"
  description = "A chat application separated into frontend and backend."
}

resource "random_string" "django_secret_key" {
  length  = 50
  special = true
}

resource "random_id" "frontend_version_id" {
  byte_length = 4
}
resource "random_id" "backend_version_id" {
  byte_length = 4
}

resource "aws_elastic_beanstalk_application_version" "frontend_version" {
  name        = "frontend-${random_id.frontend_version_id.hex}"
  application = aws_elastic_beanstalk_application.chat_app.name
  bucket = aws_s3_bucket.media_bucket.id
  key    = aws_s3_object.frontend_zip.key
  depends_on = [aws_s3_object.frontend_zip]
}

resource "aws_elastic_beanstalk_application_version" "backend_version" {
  name        = "backend-${random_id.backend_version_id.hex}"
  application = aws_elastic_beanstalk_application.chat_app.name
  bucket = aws_s3_bucket.media_bucket.id
  key    = aws_s3_object.backend_zip.key
  depends_on = [aws_s3_object.backend_zip]
}

resource "aws_elastic_beanstalk_environment" "frontend_env" {
  name                = "chat-frontend-env"
  application         = aws_elastic_beanstalk_application.chat_app.name
  solution_stack_name = data.aws_elastic_beanstalk_solution_stack.docker.name

  dynamic "setting" {
    for_each = (var.use_existing_iam || var.create_iam_roles) ? [1] : []
    content {
      namespace = "aws:autoscaling:launchconfiguration"
      name      = "IamInstanceProfile"
      # Use the existing instance profile (from AWS) when requested, otherwise use the instance profile created by this module
      value     = var.use_existing_iam ? data.aws_iam_instance_profile.existing[0].name : aws_iam_instance_profile.LabInstanceProfile[0].name
    }
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t3.micro"
  }

  # Ustawienia VPC, żeby EB nie szukał default VPC
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.main.id
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", [aws_subnet.public_a.id, aws_subnet.public_b.id])
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = join(",", [aws_subnet.public_a.id, aws_subnet.public_b.id])
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "true"
  }

  # Security groups: przypisanie ELB i instancji
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "Subnets"
    value     = join(",", [aws_subnet.public_a.id, aws_subnet.public_b.id])
  }
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "SecurityGroups"
    value     = aws_security_group.eb_elb_sg.id
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.eb_instances_sg.id
  }

  # Podpinamy wersję aplikacji (z S3)
  version_label = aws_elastic_beanstalk_application_version.frontend_version.name

  depends_on = [
    aws_route_table_association.public_a_assoc,
    aws_route_table_association.public_b_assoc,
    aws_elastic_beanstalk_application_version.frontend_version,
    aws_vpc.main,
    aws_internet_gateway.igw,
    aws_subnet.public_a,
    aws_subnet.public_b,
    aws_security_group.eb_elb_sg,
    aws_security_group.eb_instances_sg
    # removed unconditional IAM dependencies (they may have count = 0)
  ]

  dynamic "setting" {
    for_each = (var.use_existing_iam || var.create_iam_roles) ? [1] : []
    content {
      namespace = "aws:elasticbeanstalk:environment"
      name      = "ServiceRole"
      # Use existing IAM role name when requested, otherwise the role created by this module
      value     = var.use_existing_iam ? data.aws_iam_role.existing_service_role[0].name : aws_iam_role.eb_service_role[0].name
    }
  }
}

# BACKEND ENVIRONMENT
resource "aws_elastic_beanstalk_environment" "backend_env" {
  name                = "chat-backend-env"
  application         = aws_elastic_beanstalk_application.chat_app.name
  solution_stack_name = data.aws_elastic_beanstalk_solution_stack.docker.name

  dynamic "setting" {
    for_each = (var.use_existing_iam || var.create_iam_roles) ? [1] : []
    content {
      namespace = "aws:autoscaling:launchconfiguration"
      name      = "IamInstanceProfile"
      # Use existing instance profile name when requested
      value     = var.use_existing_iam ? data.aws_iam_instance_profile.existing[0].name : aws_iam_instance_profile.LabInstanceProfile[0].name
    }
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t3.micro"
  }

  # Zmienne środowiskowe dla Backendu
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_HOST"
    value     = aws_db_instance.postgres_db.address
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_NAME"
    value     = "postgres"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_USER"
    value     = aws_db_instance.postgres_db.username
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_PASSWORD"
    value     = aws_db_instance.postgres_db.password
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_PORT"
    value     = tostring(aws_db_instance.postgres_db.port)
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "USE_AWS_S3"
    value     = "True"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "AWS_STORAGE_BUCKET_NAME"
    value     = aws_s3_bucket.media_bucket.bucket
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "COGNITO_USER_POOL_ID"
    value     = aws_cognito_user_pool.chat_user_pool.id
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "COGNITO_ISSUER"
    value     = "https://cognito-idp.${data.aws_caller_identity.current.account_id}.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.chat_user_pool.id}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "COGNITO_APP_CLIENT_ID"
    value     = aws_cognito_user_pool_client.chat_user_pool_client.id
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DJANGO_SECRET_KEY"
    value     = random_string.django_secret_key.result
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DJANGO_ALLOWED_HOSTS"
    value     = "localhost,127.0.0.1,*.elasticbeanstalk.com"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "CORS_ALLOWED_ORIGINS"
    value     = var.frontend_url != "" ? var.frontend_url : "https://*.elasticbeanstalk.com"
  }

  # Ustawienia VPC, żeby EB nie szukał default VPC
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.main.id
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", [aws_subnet.public_a.id, aws_subnet.public_b.id])
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = join(",", [aws_subnet.public_a.id, aws_subnet.public_b.id])
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "true"
  }

  # Security groups: przypisanie ELB i instancji
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "Subnets"
    value     = join(",", [aws_subnet.public_a.id, aws_subnet.public_b.id])
  }
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "SecurityGroups"
    value     = aws_security_group.eb_elb_sg.id
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.eb_instances_sg.id
  }

  # Podpinamy wersję aplikacji backend
  version_label = aws_elastic_beanstalk_application_version.backend_version.name

  depends_on = [
    aws_route_table_association.public_a_assoc,
    aws_route_table_association.public_b_assoc,
    aws_elastic_beanstalk_application_version.backend_version,
    aws_db_instance.postgres_db,
    aws_vpc.main,
    aws_internet_gateway.igw,
    aws_subnet.public_a,
    aws_subnet.public_b,
    aws_security_group.eb_elb_sg,
    aws_security_group.eb_instances_sg
    # removed unconditional IAM dependencies (they may have count = 0)
  ]

  dynamic "setting" {
    for_each = (var.use_existing_iam || var.create_iam_roles) ? [1] : []
    content {
      namespace = "aws:elasticbeanstalk:environment"
      name      = "ServiceRole"
      value     = var.use_existing_iam ? data.aws_iam_role.existing_service_role[0].name : aws_iam_role.eb_service_role[0].name
    }
  }

  # During debugging switch to single-instance to simplify troubleshooting (no LB/ASG)
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance"
  }
}


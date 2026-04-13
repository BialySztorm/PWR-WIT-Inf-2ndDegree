provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# Generowanie losowego Django Secret Key
resource "random_string" "django_secret_key" {
  length  = 50
  special = true
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "chatapp-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "chatapp-igw"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "chatapp-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "chatapp-public-b"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_db_subnet_group" "db_subnets" {
  name       = "chatapp-db-subnets"
  subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}


# ------------------------------------------------------------------------------
# ZAPYTANIE DO AWS O NAJNOWSZY DOCKER STACK (Rozwiązuje problem z wersją)
# ------------------------------------------------------------------------------
data "aws_elastic_beanstalk_solution_stack" "docker" {
  most_recent = true
  name_regex  = "^64bit Amazon Linux 2023 (.*) running Docker$"
}

# ------------------------------------------------------------------------------
# 2. S3 BUCKET (Media)
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "media_bucket" {
  bucket        = "chatapp-media-bucket-${random_id.bucket_id.hex}"
  force_destroy = true
}
resource "random_id" "bucket_id" {
  byte_length = 4
}
resource "aws_s3_bucket_public_access_block" "media_bucket_public_access" {
  bucket                  = aws_s3_bucket.media_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_policy" "media_bucket_policy" {
  bucket = aws_s3_bucket.media_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.media_bucket.arn}/*"
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.media_bucket_public_access]
}

# ------------------------------------------------------------------------------
# 3. RDS POSTGRESQL (Database)
# ------------------------------------------------------------------------------
resource "aws_db_instance" "postgres_db" {
  identifier           = "chatapp-db"
  allocated_storage    = 20
  storage_type         = "gp3"
  engine               = "postgres"
  engine_version       = "16"
  instance_class       = "db.t3.micro"
  username             = "app"
  password             = "some_secure_password"
  publicly_accessible  = false
  skip_final_snapshot  = true
  db_subnet_group_name = aws_db_subnet_group.db_subnets.name
}

# ------------------------------------------------------------------------------
# 4. AWS COGNITO (User Pool & App Client)
# ------------------------------------------------------------------------------
resource "aws_cognito_user_pool" "chat_user_pool" {
  name                     = "chatapp-user-pool"
  auto_verified_attributes = ["email"]
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }
}
resource "aws_cognito_user_pool_client" "chat_user_pool_client" {
  name         = "chatapp-react-client"
  user_pool_id = aws_cognito_user_pool.chat_user_pool.id
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
}

# ------------------------------------------------------------------------------
# 5. ELASTIC BEANSTALK APP & ENVIRONMENTS
# ------------------------------------------------------------------------------
resource "aws_elastic_beanstalk_application" "chat_app" {
  name        = "chatapp"
  description = "A chat application separated into frontend and backend."
}

# Security group for Load Balancer (ELB/ALB)
resource "aws_security_group" "eb_elb_sg" {
  name   = "chatapp-elb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security group for instances (only allow traffic from ELB)
resource "aws_security_group" "eb_instances_sg" {
  name   = "chatapp-instances-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "Allow from ELB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.eb_elb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# FRONTEND ENVIRONMENT
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

# Upload lokalnych ZIP-ów (muszą istnieć: ../deploy/frontend-src.zip i ../deploy/backend-src.zip)
resource "aws_s3_object" "frontend_zip" {
  bucket = aws_s3_bucket.media_bucket.id
  key    = "frontend-src.zip"
  source = "${path.module}/../deploy/frontend-src.zip"
  content_type = "application/zip"
  etag   = filemd5("${path.module}/../deploy/frontend-src.zip")
}

resource "aws_s3_object" "backend_zip" {
  bucket = aws_s3_bucket.media_bucket.id
  key    = "backend-src.zip"
  source = "${path.module}/../deploy/backend-src.zip"
  content_type = "application/zip"
  etag   = filemd5("${path.module}/../deploy/backend-src.zip")
}

# Unikalne etykiety wersji
resource "random_id" "frontend_version_id" {
  byte_length = 4
}
resource "random_id" "backend_version_id" {
  byte_length = 4
}

# Wersje aplikacji Elastic Beanstalk wskazujące na obiekty S3
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

# ------------------------------------------------------------------------------
# 6. OUTPUTS
# ------------------------------------------------------------------------------
output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.chat_user_pool.id
}
output "cognito_client_id" {
  value = aws_cognito_user_pool_client.chat_user_pool_client.id
}
output "frontend_url" {
  value = aws_elastic_beanstalk_environment.frontend_env.endpoint_url
}
output "backend_url" {
  value = aws_elastic_beanstalk_environment.backend_env.endpoint_url
}
output "db_endpoint" {
  value = aws_db_instance.postgres_db.address
}

# IAM role for EB instances and instance profile (create only if allowed)
resource "aws_iam_role" "eb_instance_role" {
  count = var.create_iam_roles ? 1 : 0
  name  = "chatapp-eb-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eb_instance_attach" {
  count      = var.create_iam_roles ? 1 : 0
  role       = aws_iam_role.eb_instance_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

# Attach ECR readonly policy so EB instances can pull images from ECR when using Dockerrun referencing ECR
resource "aws_iam_role_policy_attachment" "eb_instance_ecr_readonly" {
  count      = var.create_iam_roles ? 1 : 0
  role       = aws_iam_role.eb_instance_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "LabInstanceProfile" {
  count = var.create_iam_roles ? 1 : 0
  # Use role name to ensure instance profile name matches role and is valid for ASG/LaunchTemplate
  name  = aws_iam_role.eb_instance_role[0].name
  role  = aws_iam_role.eb_instance_role[0].name
}

# IAM role for Elastic Beanstalk service (create only if allowed)
resource "aws_iam_role" "eb_service_role" {
  count = var.create_iam_roles ? 1 : 0
  name  = "chatapp-eb-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "elasticbeanstalk.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "eb_service_inline" {
  count = var.create_iam_roles ? 1 : 0
  name  = "chatapp-eb-service-inline-policy"
  role  = aws_iam_role.eb_service_role[0].name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "autoscaling:*",
          "ec2:*",
          "elasticloadbalancing:*",
          "cloudwatch:*",
          "cloudformation:*",
          "elasticbeanstalk:*",
          "s3:*",
          "rds:*",
          "sns:*",
          "logs:*",
          "iam:PassRole",
          "iam:GetRole",
          "iam:ListRoles"
        ],
        Resource = "*"
      }
    ]
  })
}

variable "create_iam_roles" {
  description = "If true Terraform will create IAM roles and instance profile for Elastic Beanstalk. Set to false to use existing roles/profile."
  type        = bool
  default     = false
}

variable "use_existing_iam" {
  description = "If true Terraform will insert settings pointing to existing InstanceProfile and ServiceRole. Set to false on restricted accounts."
  type        = bool
  default     = false
}

variable "instance_profile_name" {
  description = "Name of the existing instance profile to use for EB instances (or the name to create if create_iam_roles = true)."
  type        = string
  # Typowe nazwy zarządzane przez AWS - zostaw jeśli Twoje konto ma domyślne role
  default     = "chatapp-eb-instance-profile"
}

variable "eb_service_role_name" {
  description = "Name of existing Elastic Beanstalk service role to use when create_iam_roles = false"
  type        = string
  # Typowa nazwa roli serwisowej
  default     = "aws-elasticbeanstalk-service-role"
}

variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "frontend_url" {
  description = "Frontend URL for CORS configuration (e.g., https://myapp.example.com). If not provided, uses *.elasticbeanstalk.com"
  type        = string
  default     = ""
}

# Add data sources to validate/look up existing IAM resources when use_existing_iam = true
data "aws_iam_instance_profile" "existing" {
  count = var.use_existing_iam ? 1 : 0
  name  = var.instance_profile_name
}

data "aws_iam_role" "existing_service_role" {
  count = var.use_existing_iam ? 1 : 0
  name  = var.eb_service_role_name
}

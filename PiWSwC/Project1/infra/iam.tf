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

resource "aws_iam_role_policy_attachment" "eb_instance_ecr_readonly" {
  count      = var.create_iam_roles ? 1 : 0
  role       = aws_iam_role.eb_instance_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "LabInstanceProfile" {
  count = var.create_iam_roles ? 1 : 0
  name  = aws_iam_role.eb_instance_role[0].name
  role  = aws_iam_role.eb_instance_role[0].name
}

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

data "aws_iam_instance_profile" "existing" {
  count = var.use_existing_iam ? 1 : 0
  name  = var.instance_profile_name
}

data "aws_iam_role" "existing_service_role" {
  count = var.use_existing_iam ? 1 : 0
  name  = var.eb_service_role_name
}


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
  default     = "chatapp-eb-instance-profile"
}

variable "eb_service_role_name" {
  description = "Name of existing Elastic Beanstalk service role to use when create_iam_roles = false"
  type        = string
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
  default     = "https://bylena3.cloud"
}


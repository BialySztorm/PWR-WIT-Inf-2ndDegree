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


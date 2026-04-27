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
  vpc_security_group_ids = [aws_security_group.db_sg.id]
}

resource "aws_security_group" "db_sg" {
  name        = "allow_backend_to_db"
  description = "Allow inbound traffic from EB instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from Beanstalk"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eb_instances_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
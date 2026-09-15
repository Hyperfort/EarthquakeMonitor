# RDS stores the earthquake records ingested by the Lambda and used by the API layer.
resource "aws_db_subnet_group" "db_subnets" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.private_subnets
}

resource "aws_db_parameter_group" "mysql" {
  name   = "${var.name}-mysql-params"
  family = "mysql8.0"
}

resource "aws_db_instance" "mysql" {
  identifier              = "${var.name}-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = var.instance_class
  allocated_storage       = 20
  max_allocated_storage   = 100
  storage_type            = "gp3"
  backup_retention_period = 0

  db_name  = var.db_name
  username = var.username
  password = var.password

  multi_az               = false
  skip_final_snapshot    = true
  vpc_security_group_ids = [var.sg_id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name
  parameter_group_name   = aws_db_parameter_group.mysql.name

  tags = {
    Name = "${var.name}-db"
  }
}

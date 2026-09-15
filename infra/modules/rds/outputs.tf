output "host" {
  value = aws_db_instance.mysql.address
}

output "db_name" {
  value = var.db_name
}

output "username" {
  value     = var.username
  sensitive = true
}

output "password" {
  value     = var.password
  sensitive = true
}
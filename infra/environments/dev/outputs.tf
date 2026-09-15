output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.dns_name
}

output "api_url" {
  description = "Public URL for the API"
  value       = "http://${module.alb.dns_name}"
}

output "db_host" {
  description = "RDS hostname for the application database"
  value       = module.rds.host
}

output "db_name" {
  description = "RDS database name"
  value       = module.rds.db_name
}

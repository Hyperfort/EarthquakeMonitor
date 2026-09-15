output "arn" {
  value = aws_lambda_function.ingestion.arn
}

output "name" {
  value = aws_lambda_function.ingestion.function_name
}

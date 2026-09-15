output "public_ids" {
  value = aws_subnet.public[*].id
}

output "private_ids" {
  value = aws_subnet.private[*].id
}

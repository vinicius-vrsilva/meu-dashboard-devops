output "public_ip" {
  description = "IP público da instância EC2 do dashboard."
  value       = aws_instance.dashboard_server.public_ip
}

output "public_dns" {
  description = "DNS público da instância EC2 do dashboard."
  value       = aws_instance.dashboard_server.public_dns
}
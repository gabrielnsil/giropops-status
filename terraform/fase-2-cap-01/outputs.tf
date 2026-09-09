# Saídas úteis pós-apply. `terraform output` exibe todas.

output "public_ip" {
  description = "IP público da EC2"
  value       = aws_instance.giropops.public_ip
}

output "public_dns" {
  description = "DNS público da EC2"
  value       = aws_instance.giropops.public_dns
}

output "dashboard_url" {
  description = "URL do dashboard do Giropops Status (cloud-init demora 60-120s pra terminar)"
  value       = "http://${aws_instance.giropops.public_ip}:5000"
}

output "ssh_command" {
  description = "Comando SSH (só funciona se você passou ssh_public_key)"
  value       = var.ssh_public_key != "" ? "ssh ubuntu@${aws_instance.giropops.public_ip}" : "(ssh_public_key não foi definido, sem SSH)"
}

output "cloud_init_log_command" {
  description = "Ver progresso do user_data depois do SSH"
  value       = "ssh ubuntu@${aws_instance.giropops.public_ip} 'sudo tail -f /var/log/cloud-init-output.log'"
}

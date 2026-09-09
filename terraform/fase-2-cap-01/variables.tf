# Variáveis do projeto. Edite no terraform.tfvars (cópia em
# terraform.tfvars.example) ou passe via CLI/env.

variable "aws_region" {
  description = "Região AWS onde a EC2 vai subir"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto, usado em tags e Security Group"
  type        = string
  default     = "giropops-status"
}

variable "instance_type" {
  description = "Tipo da instância EC2 (t3.micro está no free tier)"
  type        = string
  default     = "t3.micro"
}

variable "ubuntu_release" {
  description = "Versão LTS do Ubuntu (jammy=22.04, noble=24.04)"
  type        = string
  default     = "noble-24.04"
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs permitidos pra SSH (porta 22). Use seu IP pra evitar exposição mundial."
  type        = list(string)
  # Default deixa SSH aberto pro mundo só pra primeira aula funcionar
  # mesmo se o aluno não souber o próprio IP. Em produção: ["SEU_IP/32"].
  default = ["0.0.0.0/0"]
}

variable "ssh_public_key" {
  description = "Conteúdo da sua chave pública SSH (cat ~/.ssh/id_ed25519.pub). Vazio = sem key pair, EC2 sobe sem acesso SSH."
  type        = string
  default     = ""
}

variable "giropops_repo_url" {
  description = "URL HTTPS do repositório giropops-status que o user_data vai clonar"
  type        = string
  default     = "https://github.com/linuxtips/giropops-status.git"
}

variable "giropops_repo_branch" {
  description = "Branch a clonar (fase-2-cap-01 traz o estado pronto desse capítulo)"
  type        = string
  default     = "fase-2-cap-01"
}

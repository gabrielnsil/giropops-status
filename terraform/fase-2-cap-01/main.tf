# ──────────────────────────────────────────────────────────────
# Giropops Status — Fase 2, Capítulo 1
# Provisiona EC2 Ubuntu na AWS que sobe a aplicação no boot via user_data
# ──────────────────────────────────────────────────────────────
#
# O objetivo desse capítulo é VER infraestrutura como código funcionando
# de ponta a ponta:
#   1. Você escreve esse Terraform.
#   2. `terraform apply` cria a EC2 com Ubuntu.
#   3. user_data instala Python, Redis, baixa o giropops-status e sobe.
#   4. Você acessa http://<ip-publico>:5000 e o dashboard responde.
#
# Tudo sem SSH manual. Quando destruir (`terraform destroy`), some.
# É a primeira aula de IaC do treinamento. Foco no fluxo, não em produção.
# Hardening (KMS, IMDSv2, ALB, ASG, instance profile, secrets, etc) entra
# em capítulos posteriores da Fase 2.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ──────────────────────────────────────────────────────────────
# AMI Ubuntu mais recente (Canonical oficial)
# Em vez de fixar AMI ID (que varia por região e expira), pega o mais
# recente do owner 099720109477 (Canonical). Filtro pra Ubuntu LTS,
# arquitetura x86_64, virtualização HVM, disco EBS gp3.
# ──────────────────────────────────────────────────────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-${var.ubuntu_release}-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ──────────────────────────────────────────────────────────────
# Security Group: libera 22 (SSH, pra debug) e 5000 (Flask dashboard).
# Em produção: bota tudo atrás de ALB com HTTPS e fecha 5000 só pra
# subnet do ALB. Aqui é didático.
# ──────────────────────────────────────────────────────────────
resource "aws_security_group" "giropops" {
  name        = "${var.project_name}-sg"
  description = "Acesso ao Giropops Status (SSH + dashboard)"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }

  ingress {
    description = "Flask dashboard"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Saída pra qualquer destino (apt update, pip install)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}

# ──────────────────────────────────────────────────────────────
# Key pair (opcional, pra SSH)
# Se você passou `ssh_public_key`, cria. Caso contrário pula.
# Comando pra gerar: ssh-keygen -t ed25519 -f ~/.ssh/giropops_ed25519
# ──────────────────────────────────────────────────────────────
resource "aws_key_pair" "giropops" {
  count      = var.ssh_public_key != "" ? 1 : 0
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key
}

# ──────────────────────────────────────────────────────────────
# A instância em si
# user_data renderiza o template `user_data.sh` substituindo a versão
# do repositório que vai ser clonada. Cloud-init executa esse script
# no primeiro boot, antes da instância ficar pronta.
# ──────────────────────────────────────────────────────────────
resource "aws_instance" "giropops" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.giropops.id]
  key_name               = var.ssh_public_key != "" ? aws_key_pair.giropops[0].key_name : null

  user_data = templatefile("${path.module}/user_data.sh", {
    repo_url    = var.giropops_repo_url
    repo_branch = var.giropops_repo_branch
  })

  # Substituir a instância sempre que o user_data mudar. Sem isso o
  # Terraform NÃO recria EC2 só porque o script de bootstrap mudou.
  user_data_replace_on_change = true

  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name    = var.project_name
    Project = var.project_name
  }
}

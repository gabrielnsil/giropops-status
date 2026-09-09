# Fase 2 — Capítulo 1

## Sua primeira infraestrutura como código

Bem-vindo à **Fase 2** do projeto Giropops Status. Aqui você sai do "rodar a aplicação na mão num servidor Linux" (Fase 1) e entra no mundo onde **a infraestrutura é descrita em código** e versionada igual a aplicação.

Treinamento da Fase 2: **Descomplicando Terraform** (instrutor: Gomex). Este capítulo é a primeira aula prática.

---

## O que você vai construir

Uma EC2 Ubuntu na AWS que, ao ligar pela primeira vez, **se configura sozinha**: instala Python, Redis, baixa o código do Giropops Status, registra um serviço no systemd e começa a servir o dashboard na porta 5000.

Tudo isso descrito em **3 arquivos `.tf`** que você aplica com 2 comandos.

```
você → terraform apply
       ├─ AWS cria a EC2
       ├─ Ubuntu boota
       ├─ user_data instala dependências
       └─ Giropops Status rodando em http://<ip>:5000
```

E quando você quiser apagar tudo, **um comando** (`terraform destroy`) e a conta não cobra mais.

---

## Pré-requisitos

1. **Conta AWS** com credenciais configuradas localmente. Teste com:
   ```bash
   aws sts get-caller-identity
   ```
   Se devolver seu Account ID, está OK. Se não, configura com `aws configure`.

2. **Terraform** instalado. Versão >= 1.5.0:
   ```bash
   terraform version
   ```

3. **Chave SSH local** (opcional, mas recomendado pra debug):
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/giropops_ed25519 -N ""
   cat ~/.ssh/giropops_ed25519.pub
   ```

---

## Passo a passo

### 1. Entra no diretório do capítulo

```bash
git clone https://github.com/linuxtips/giropops-status.git
cd giropops-status
git checkout fase-2-cap-01
cd terraform/fase-2-cap-01
```

### 2. Copia o exemplo de variáveis e ajusta

```bash
cp terraform.tfvars.example terraform.tfvars
```

Abre `terraform.tfvars` no editor e:

- Cola sua chave pública SSH em `ssh_public_key` (saída do `cat ~/.ssh/giropops_ed25519.pub` do passo 3 acima)
- Opcional: restringe `ssh_allowed_cidrs` ao seu IP (descobre com `curl -s ifconfig.me`)

### 3. Inicializa o Terraform

```bash
terraform init
```

Esse comando baixa o provider AWS pra dentro de `.terraform/`. Roda uma vez por projeto.

### 4. Vê o que vai ser criado (sem aplicar)

```bash
terraform plan
```

O plan mostra os recursos novos: 1 EC2, 1 Security Group, 1 Key Pair, e usa o data source pra descobrir o AMI do Ubuntu mais recente.

### 5. Aplica de verdade

```bash
terraform apply
```

Confirma com `yes` quando perguntar. **Demora ~30 segundos** pra criar a EC2. O `user_data` (script de bootstrap) continua rodando depois, no boot da máquina. No total, **conte 2-3 minutos** até o dashboard responder.

### 6. Acessa

Pega a URL do output:

```bash
terraform output dashboard_url
```

Abre no navegador. Se aparecer **"Status Code: 200"** ou **erro de conexão**, espera mais um minuto (cloud-init pode estar instalando deps).

Pra acompanhar o progresso do bootstrap em tempo real:

```bash
eval "$(terraform output -raw cloud_init_log_command)"
```

(Espere ver `Bootstrap concluído. Acesse http://<IP>:5000` no log.)

### 7. Destrói tudo (importante, evita cobrança)

```bash
terraform destroy
```

Confirma com `yes`. A EC2, Security Group e Key Pair somem da AWS. Sem cobrança.

---

## O que cada arquivo faz

```
terraform/fase-2-cap-01/
├── main.tf                  ← Recursos: AMI lookup, SG, key pair, EC2
├── variables.tf             ← Inputs configuráveis (região, tipo, etc)
├── outputs.tf               ← Saídas pós-apply (IP, URL, comando SSH)
├── user_data.sh             ← Script bash que roda no boot da EC2
├── terraform.tfvars.example ← Modelo do tfvars (você copia e edita)
└── .gitignore               ← Não commitar state, tfvars, etc
```

**Você vai mexer em**: `terraform.tfvars` (sua cópia) e talvez `main.tf` se quiser explorar.

**Não toque sem entender**: `user_data.sh` (a ordem das etapas importa, e o script roda como root no primeiro boot).

---

## O que o `user_data.sh` faz, passo a passo

1. `apt-get update && apt-get install` — instala Python, pip, git, Redis
2. `systemctl start redis-server` — sobe o Redis localmente (porta 6379)
3. `useradd giropops` — cria usuário não-root pra rodar a app
4. `git clone` — baixa o repo nesta branch (`fase-2-cap-01`)
5. `python3 -m venv` + `pip install` — virtualenv e dependências
6. **Escreve** `/etc/systemd/system/giropops-status.service` — unit que aponta pra app
7. `systemctl enable + start` — registra no boot e inicia agora

Se quiser entender melhor, leia o arquivo. Está comentado linha a linha.

---

## Problemas comuns

**`Error: AccessDenied` no apply.**
Suas credenciais AWS não têm permissão pra criar EC2. Use uma conta com `AdministratorAccess` ou crie um IAM user com EC2 + VPC.

**Dashboard não responde após 3 minutos.**
SSH na máquina e olha o log do bootstrap:
```bash
ssh ubuntu@$(terraform output -raw public_ip)
sudo tail -50 /var/log/cloud-init-output.log
```
Vai aparecer onde o script morreu (geralmente `apt-get update` falhando por rede do default VPC).

**`InvalidAMIID.NotFound`.**
A região que você escolheu não tem AMI Ubuntu desse release. Troca em `terraform.tfvars`:
```hcl
ubuntu_release = "jammy-22.04"   # tenta 22.04 em vez de 24.04
```

**Custo:**
`t3.micro` está dentro do free tier (750h/mês no primeiro ano). Mas SE a sua conta já passou do free tier, custa ~$0.01/hora. Destrua quando terminar de testar.

---

## Próximos capítulos

| Cap | Tema | Status |
|:---:|---|---|
| **1** | EC2 + user_data (este) | ✅ Liberado |
| 2 | Variáveis, módulos, workspaces | 🔜 Em desenvolvimento |
| 3 | VPC custom, subnets públicas/privadas, NAT Gateway | 🔜 |
| 4 | RDS pro Redis (em vez de instalar local), Secrets Manager | 🔜 |
| 5 | ALB + Auto Scaling Group + Launch Template | 🔜 |
| 6 | CloudWatch logs/metrics, alarmes | 🔜 |
| 7 | Terraform state remoto (S3 + DynamoDB lock) | 🔜 |
| 8 | Módulo Terraform reutilizável | 🔜 |

---

## Quem dá esta aula

**Rafael Gomex Gomes** (head de educação, instrutor do treinamento Descomplicando Terraform). 20+ anos de infra, autor da série de livros _Descomplicando_.

Dúvidas durante o capítulo: pergunta no Q&A do Mesa ou na live ao vivo.

---

**Bora?**

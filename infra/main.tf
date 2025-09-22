# Define o provedor de nuvem que o Terraform vai usar. No nosso caso, é a AWS.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Garante que estamos usando uma versão compatível do provedor AWS
    }
  }
}

# Configura o provedor AWS, usando a região definida na nossa variável.
provider "aws" {
  region = var.aws_region
}

# ENCONTRA A AMI AUTOMATICAMENTE - ISSO RESOLVE O PROBLEMA DA PORRA DA AMI!
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Cria um Security Group (Grupo de Segurança), que funciona como um firewall para nossa máquina virtual.
# Ele controla qual tráfego pode entrar e sair da instância.
resource "aws_security_group" "dashboard_sg" {
  name        = "dashboard-security-group"
  description = "Permite trafego HTTP e SSH para o dashboard"
  vpc_id      = aws_vpc.main.id # Associa este SG à nossa VPC principal

  # Regra para permitir acesso SSH (porta 22) de qualquer lugar (0.0.0.0/0)
  # ATENÇÃO: Em produção, restrinja o acesso SSH ao seu IP ou VPN!
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regra para permitir acesso HTTP (porta 80) de qualquer lugar (0.0.0.0/0)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regra para permitir acesso à porta 5000 (onde nosso Flask/Docker vai rodar) de qualquer lugar
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regra para permitir todo o tráfego de saída (a instância pode se conectar à internet)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 significa todos os protocolos
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dashboard-security-group"
  }
}

# Cria uma Virtual Private Cloud (VPC) padrão.
# A VPC é sua réseau isolada na AWS.
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}

# Cria uma Subnet (sub-rede) dentro da VPC.
resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a" # Ex: sa-east-1a
  map_public_ip_on_launch = true # Atribui um IP público automaticamente às instâncias
  tags = {
    Name = "main-subnet"
  }
}

# Cria um Internet Gateway para permitir que a VPC se comunique com a internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main-igw"
  }
}

# Cria uma Route Table (Tabela de Rotas) para direcionar o tráfego da internet para o Internet Gateway.
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "main-route-table"
  }
}

# Associa a Route Table à nossa Subnet.
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# Cria a instância EC2 (nossa máquina virtual) onde o Docker vai rodar.
resource "aws_instance" "dashboard_server" {
  ami           = data.aws_ami.ubuntu.id  # ← ALTEREI AQUI - AGORA USA A AMI AUTOMÁTICA!
  instance_type = var.instance_type
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.dashboard_sg.id]
  subnet_id     = aws_subnet.main.id

  # user_data é um script que será executado na primeira inicialização da instância.
  # Usamos ele para instalar o Docker e o Docker Compose.
 user_data = <<-EOF
            #!/bin/bash
            sudo apt update -y
            sudo apt install -y apt-transport-https ca-certificates curl software-properties-common unzip
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt update -y
            sudo apt install -y docker-ce docker-ce-cli containerd.io
            sudo usermod -aG docker ubuntu
            # Instala Docker Compose
            sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            # Instala AWS CLI
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip awscliv2.zip
            sudo ./aws/install
            EOF
  tags = {
    Name = "dashboard-server"
  }
}
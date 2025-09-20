variable "aws_region" {
  description = "Região da AWS onde os recursos serão criados."
  type        = string
  default     = "sa-east-1"
}

variable "instance_type" {
  description = "Tipo da instância EC2 (tamanho da máquina virtual)."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Nome do par de chaves SSH para acesso à instância EC2."
  type        = string
  default     = "minha-chave-devops"
}
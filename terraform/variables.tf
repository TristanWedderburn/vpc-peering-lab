variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "my_ip" {
  description = "Your public IP for SSH/HTTP access (no /32 suffix)."
  type        = string
}

variable "key_name" {
  description = "Name of an existing EC2 key pair to use for SSH."
  type        = string
}

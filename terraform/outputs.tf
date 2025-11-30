output "vpc_a_instance_public_ip" {
  value = aws_instance.flask_a.public_ip
}

output "vpc_b_instance_public_ip" {
  value = aws_instance.flask_b.public_ip
}

output "vpc_a_instance_private_ip" {
  value = aws_instance.flask_a.private_ip
}

output "vpc_b_instance_private_ip" {
  value = aws_instance.flask_b.private_ip
}

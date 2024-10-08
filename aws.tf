
provider "aws" {
  region = "eu-north-1"  # Changez la région selon vos besoins
}

resource "aws_security_group" "allow_all_tcp" {
  name        = "allow_all_tcp"
  description = "Allow all TCP inbound traffic"

  ingress {
    description = "Allow all TCP traffic"
    from_port   = 0
    to_port     = 65535  # Ouvrir tous les ports TCP
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Autoriser depuis n'importe quelle adresse IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Autoriser tout le trafic sortant
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_all_tcp"
  }
}

resource "aws_instance" "web" {
  count         = 3  # Déployer 3 instances
  ami           = "ami-01427dce5d2537266"  # AMI pour Debian
  instance_type = "t3.micro"  # Petite instance
  key_name      = "ssh_nathandevops"  # Nom de la clé SSH existante

  vpc_security_group_ids = [aws_security_group.allow_all_tcp.id]

  root_block_device {
    volume_size = 20  # Taille du volume en Go
    volume_type = "gp2"  # Type de volume SSD à usage général
  }

  # Script de démarrage pour installer Docker sur Debian
  user_data = <<-EOF
              #!/bin/bash
              apt update
              apt install -y docker.io
              systemctl start docker
              usermod -aG docker admin
              EOF

  tags = {
    Name = "DockerInstance-${count.index + 1}"
  }
}

resource "local_file" "inventory" {
  filename = "inventory.ini"
  content  = <<-EOF
    [managers]
    ${aws_instance.web[0].public_ip}

    [workers]
    ${join("\n", slice(aws_instance.web[*].public_ip, 1, 3))}
    EOF

  depends_on = [aws_instance.web]
}

output "instance_ips" {
  value = aws_instance.web[*].public_ip
}

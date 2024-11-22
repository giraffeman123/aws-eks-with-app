resource "random_string" "random" {
  length  = 8
  special = false
  lower   = true
}

resource "aws_security_group" "rds_sg" {
  vpc_id      = var.vpc_id
  name        = "rds-sg"
  description = "Acceso por parte de maquina"

  ingress {
    description = "private subnets from EKS"
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = var.private_subnets_cidr_block
  }

  ingress {
    description     = "Allow bootstrap node access to RDS"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ephemeral_instance_sg.id]
  }

  # Outbound Rules
  # Internet access to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.mandatory_tags,
    {
      Name = "RDS-${var.mandatory_tags.Environment}-sg"
    }
  )

  # Ensure that the resource is rebuilt before destruction when running an update
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "main"
  subnet_ids = var.private_subnets_ids

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_db_instance" "this" {
  allocated_storage = 10
  engine            = "mysql"
  instance_class    = "db.t3.micro"
  identifier        = jsondecode(data.aws_secretsmanager_secret_version.secret_db_credentials.secret_string)["DB_NAME"]
  username          = jsondecode(data.aws_secretsmanager_secret_version.secret_db_credentials.secret_string)["DB_USER"]
  password          = jsondecode(data.aws_secretsmanager_secret_version.secret_db_credentials.secret_string)["DB_PWD"]
  db_name           = jsondecode(data.aws_secretsmanager_secret_version.secret_db_credentials.secret_string)["DB_NAME"]
  port              = var.db_port

  publicly_accessible = false

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.my_db_subnet_group.name

  skip_final_snapshot = true

  tags = merge(
    var.mandatory_tags,
    {
      Name = "flightdb-${var.mandatory_tags.Environment}"
    }
  )
}

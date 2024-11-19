resource "aws_iam_role" "this" {
  name = "RDS-Bootstrap-EC2-Role-${var.mandatory_tags.Environment}"
  path = "/"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "ec2.amazonaws.com"
          },
          "Effect" : "Allow"
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "this" {
  count = length(local.role_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = element(local.role_policy_arns, count.index)
}

resource "aws_security_group" "ephemeral_instance_sg" {
  vpc_id      = var.vpc_id
  name        = "RDS-Bootstrap-${var.mandatory_tags.Environment}-sg"
  description = "RDS-Bootstrap security group"

  # ingress {
  #   description = "SSH port"
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.mandatory_tags,
    {
      Name = "RDS-Bootstrap-${var.mandatory_tags.Environment}-sg"
    }
  )

  # Ensure that the resource is rebuilt before destruction when running an update
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_instance_profile" "this" {
  name = "RDS-Bootstrap-EC2-Profile-${var.mandatory_tags.Environment}"
  role = aws_iam_role.this.name
}

data "aws_ami" "ephemeral_instance_ami" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# Prepare MySQL script
data "template_file" "bootstrap_db_script" {
  template = file("${path.module}/${local.bootstrap_db_script_filepath}")
}

data "template_file" "ephemeral_instance_user_data" {
  template = file("${path.module}/${local.ephemeral_instance_user_data_filepath}")
  vars = {
    DATABASE_ENDPOINT   = "${aws_db_instance.this.address}"
    DATABASE_NAME       = "${var.db_name}"
    DATABASE_USER       = "${var.db_admin_user}"
    DATABASE_PASSWORD   = "${aws_secretsmanager_secret_version.db_pwd.secret_string}"
    DATABASE_PORT       = "${var.db_port}"
    BOOTSTRAP_DB_SCRIPT = "${data.template_file.bootstrap_db_script.rendered}"
  }
}

resource "aws_instance" "ephemeral_instance" {
  # <--- CURRENT AMI IS Ubuntu Server 22.04 LTS [ami-024e6efaf93d85776] --->
  ami                  = data.aws_ami.ephemeral_instance_ami.id
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.this.name
  subnet_id            = element(var.private_subnets_ids, 0)
  security_groups      = [aws_security_group.ephemeral_instance_sg.id]

  # <--- CREATE KEY-PAIR IN AWS CONSOLE THEN REFERENCE NAME OF IT HERE --->
  key_name  = "aws-test"
  user_data = base64encode(data.template_file.ephemeral_instance_user_data.rendered)
  tags = {
    Name = "rds-bootstrap-node-${var.mandatory_tags.Environment}"
  }

  # <--- THIS IS THE ROOT DISK --->
  root_block_device {
    volume_size           = "8"
    volume_type           = "gp2"
    encrypted             = false
    delete_on_termination = true
    tags = {
      Name = "rds_bootstrap_root_ebs_block_device-${var.mandatory_tags.Environment}"
    }
  }

  depends_on = [aws_db_instance.this]
}
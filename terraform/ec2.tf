# Security Group pour EC2
resource "aws_security_group" "ec2_worker" {
  name        = "${var.project_name}-ec2-worker-sg"
  description = "Security group for EC2 worker"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH (optionnel, pour debug)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-worker-sg"
  }
}

# EC2 Instance
resource "aws_instance" "worker" {
  ami           = "ami-0d64bb532e0502c46" # Amazon Linux 2023 eu-west-1
  instance_type = "t2.micro"
  key_name      = var.ec2_key_name

  iam_instance_profile   = aws_iam_instance_profile.ec2_worker.name
  vpc_security_group_ids = [aws_security_group.ec2_worker.id]

  user_data = base64encode(templatefile("${path.module}/ec2-user-data.sh", {
    sqs_queue_url    = aws_sqs_queue.long_tasks.url
    dynamodb_table   = aws_dynamodb_table.orders.name
    rds_endpoint     = aws_db_instance.main.endpoint
    rds_username     = var.db_username
    rds_password     = var.db_password
    sns_topic_arn    = aws_sns_topic.notifications.arn
    aws_region       = var.aws_region
  }))

  tags = {
    Name = "${var.project_name}-ec2-worker"
  }
}
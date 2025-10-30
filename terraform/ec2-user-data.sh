#!/bin/bash
# EC2 User Data - Worker Setup

# Update system
yum update -y

# Install Node.js
curl -sL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs

# Install MySQL client
yum install -y mysql

# Create worker directory
mkdir -p /home/ec2-user/worker
cd /home/ec2-user/worker

# Create package.json
cat > package.json <<'EOF'
{
  "name": "ec2-worker",
  "version": "1.0.0",
  "dependencies": {
    "@aws-sdk/client-sqs": "^3.0.0",
    "@aws-sdk/client-dynamodb": "^3.0.0",
    "@aws-sdk/client-sns": "^3.0.0",
    "mysql2": "^3.0.0"
  }
}
EOF

# Install dependencies
npm install

# Create worker script
cat > worker.js <<'EOF'
i-029356d9dc07a0153
EOF

# Create systemd service
cat > /etc/systemd/system/ec2-worker.service <<'EOF'
[Unit]
Description=EC2 Worker Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/worker
ExecStart=/usr/bin/node worker.js
Restart=always
Environment="SQS_QUEUE_URL=${sqs_queue_url}"
Environment="DYNAMODB_TABLE=${dynamodb_table}"
Environment="RDS_ENDPOINT=${rds_endpoint}"
Environment="RDS_USERNAME=${rds_username}"
Environment="RDS_PASSWORD=${rds_password}"
Environment="SNS_TOPIC_ARN=${sns_topic_arn}"
Environment="AWS_REGION=${aws_region}"

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R ec2-user:ec2-user /home/ec2-user/worker

# Enable and start service
systemctl daemon-reload
systemctl enable ec2-worker
systemctl start ec2-worker
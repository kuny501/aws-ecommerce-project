# SNS Topic pour les notifications de commandes complétées (envoyées aux clients)
resource "aws_sns_topic" "order_completed" {
  name = "${var.project_name}-order-completed"

  tags = {
    Name = "${var.project_name}-order-completed-topic"
  }
}

resource "aws_sns_topic_subscription" "order_completed_email" {
  topic_arn = aws_sns_topic.order_completed.arn
  protocol  = "email"
  endpoint  = var.sns_email
}

# SNS Topic pour les alertes admin (notifications internes)
resource "aws_sns_topic" "admin_alerts" {
  name = "${var.project_name}-admin-alerts"

  tags = {
    Name = "${var.project_name}-admin-alerts-topic"
  }
}

resource "aws_sns_topic_subscription" "admin_alerts_email" {
  topic_arn = aws_sns_topic.admin_alerts.arn
  protocol  = "email"
  endpoint  = var.sns_email
}

# Backward compatibility: alias pour l'ancien topic "notifications"
resource "aws_sns_topic" "notifications" {
  name = "${var.project_name}-notifications"

  tags = {
    Name = "${var.project_name}-sns-topic"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = var.sns_email
}
resource "aws_cloudwatch_metric_alarm" "jenkins_cpu" {
  alarm_name          = "jenkins-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  dimensions          = { InstanceId = module.cicd[0].instance_id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "jenkins_status_check" {
  alarm_name          = "jenkins-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  dimensions          = { InstanceId = module.cicd[0].instance_id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

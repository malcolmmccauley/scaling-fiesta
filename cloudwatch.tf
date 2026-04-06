resource "aws_cloudwatch_dashboard" "aurora" {
  dashboard_name = "aurora-malco"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Aurora Database Connections"
          region = var.aws_region
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            [
              "AWS/RDS",
              "DatabaseConnections",
              "DBClusterIdentifier",
              aws_rds_cluster.main.cluster_identifier
            ]
          ]
          yAxis = {
            left = {
              min   = 0
              label = "Connections"
            }
          }
        }
      }
    ]
  })
}

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home#dashboards:name=${aws_cloudwatch_dashboard.aurora.dashboard_name}"
}

# IAM role for API Gateway to start Step Functions executions
resource "aws_iam_role" "apigw_sfn" {
  name = "apigw-sfn"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "apigw_sfn" {
  name = "apigw-sfn-policy"
  role = aws_iam_role.apigw_sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "StartSFNExecution"
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = aws_sfn_state_machine.migration.arn
    }]
  })
}

# HTTP API
resource "aws_apigatewayv2_api" "migration" {
  name          = "malco-migration"
  protocol_type = "HTTP"

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_apigatewayv2_stage" "migration" {
  api_id      = aws_apigatewayv2_api.migration.id
  name        = "$default"
  auto_deploy = true

  tags = {
    ManagedBy = "terraform"
  }
}


resource "aws_apigatewayv2_integration" "migration" {
  api_id             = aws_apigatewayv2_api.migration.id
  integration_type   = "AWS_PROXY"
  integration_subtype = "StepFunctions-StartExecution"
  credentials_arn    = aws_iam_role.apigw_sfn.arn

  request_parameters = {
    StateMachineArn = aws_sfn_state_machine.migration.arn
    Input           = "$request.body"
  }

  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "migration" {
  api_id    = aws_apigatewayv2_api.migration.id
  route_key = "POST /migrate"
  target    = "integrations/${aws_apigatewayv2_integration.migration.id}"
}

output "migration_api_url" {
  description = "URL to trigger migrations — POST /migrate with JSON body"
  value       = "${aws_apigatewayv2_stage.migration.invoke_url}/migrate"
}

# IAM role for Step Functions to run ECS tasks
resource "aws_iam_role" "sfn_migration" {
  name = "sfn-migration"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "sfn_migration" {
  name = "sfn-migration-policy"
  role = aws_iam_role.sfn_migration.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RunECSTask"
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:StopTask",
          "ecs:DescribeTasks",
        ]
        Resource = "*"
      },
      {
        Sid      = "PassExecutionRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.ecs_execution.arn
      },
      {
        Sid    = "EventBridgeSync"
        Effect = "Allow"
        Action = [
          "events:PutTargets",
          "events:PutRule",
          "events:DescribeRule",
        ]
        Resource = "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForECSTaskRule"
      },
    ]
  })
}

resource "aws_sfn_state_machine" "migration" {
  name     = "malco-migration"
  role_arn = aws_iam_role.sfn_migration.arn

  definition = jsonencode({
    Comment = "Run Flyway DB migrations via ECS Fargate"
    StartAt = "RunMigration"
    States = {
      RunMigration = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"
        Parameters = {
          Cluster        = aws_ecs_cluster.main.arn
          TaskDefinition = aws_ecs_task_definition.flyway.arn
          LaunchType     = "FARGATE"
          NetworkConfiguration = {
            AwsvpcConfiguration = {
              Subnets        = [aws_subnet.private_a.id, aws_subnet.private_b.id]
              SecurityGroups = [aws_security_group.aurora.id]
              AssignPublicIp = "DISABLED"
            }
          }
          Overrides = {
            ContainerOverrides = [{
              Name = "flyway"
              Environment = [{
                Name      = "FLYWAY_TARGET"
                "Value.$" = "$.version"
              }]
            }]
          }
        }
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "MigrationFailed"
        }]
        End = true
      }
      MigrationFailed = {
        Type  = "Fail"
        Error = "MigrationFailed"
        Cause = "Flyway ECS task failed — check CloudWatch logs at /ecs/malco-flyway"
      }
    }
  })

  tags = {
    ManagedBy = "terraform"
  }
}

output "migration_state_machine_arn" {
  description = "ARN of the migration Step Functions state machine"
  value       = aws_sfn_state_machine.migration.arn
}

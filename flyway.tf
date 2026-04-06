# ECR repository
resource "aws_ecr_repository" "flyway" {
  name                 = "malco-flyway"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    ManagedBy = "terraform"
  }
}

# ECS cluster
resource "aws_ecs_cluster" "main" {
  name = "malco"

  tags = {
    ManagedBy = "terraform"
  }
}

# IAM role for ECS task execution (pull image, write logs)
resource "aws_iam_role" "ecs_execution" {
  name = "ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow execution role to read the Aurora master password secret
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "ecs-execution-secrets"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ReadAuroraSecret"
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
      ]
      Resource = aws_rds_cluster.main.master_user_secret[0].secret_arn
    }]
  })
}

# ECS task definition
resource "aws_ecs_task_definition" "flyway" {
  family                   = "malco-flyway"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name  = "flyway"
    image = "${aws_ecr_repository.flyway.repository_url}:latest"

    environment = [
      {
        name  = "FLYWAY_URL"
        value = "jdbc:postgresql://${aws_rds_cluster.main.endpoint}:5432/${aws_rds_cluster.main.database_name}"
      },
      {
        name  = "FLYWAY_USER"
        value = aws_rds_cluster.main.master_username
      },
    ]

    secrets = [
      {
        name      = "FLYWAY_PASSWORD"
        valueFrom = "${aws_rds_cluster.main.master_user_secret[0].secret_arn}:password::"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/malco-flyway"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "flyway"
        "awslogs-create-group"  = "true"
      }
    }
  }])

  tags = {
    ManagedBy = "terraform"
  }
}

output "flyway_task_definition_arn" {
  description = "ARN of the Flyway ECS task definition"
  value       = aws_ecs_task_definition.flyway.arn
}

output "ecr_repository_url" {
  description = "ECR repository URL for the Flyway image"
  value       = aws_ecr_repository.flyway.repository_url
}

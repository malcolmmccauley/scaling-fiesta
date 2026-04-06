# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name      = "main"
    ManagedBy = "terraform"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name      = "private-a"
    ManagedBy = "terraform"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name      = "private-b"
    ManagedBy = "terraform"
  }
}

resource "aws_security_group" "aurora" {
  name        = "aurora-postgres"
  description = "Allow PostgreSQL access within VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_db_subnet_group" "aurora" {
  name       = "aurora-postgres"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    ManagedBy = "terraform"
  }
}

# Aurora PostgreSQL cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier          = "malco"
  engine                      = "aurora-postgresql"
  engine_mode                 = "provisioned"
  database_name               = "malco"
  master_username             = "malco_admin"
  db_subnet_group_name        = aws_db_subnet_group.aurora.name
  vpc_security_group_ids      = [aws_security_group.aurora.id]
  manage_master_user_password = true

  skip_final_snapshot = true

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_rds_cluster_instance" "main" {
  identifier         = "malco-instance-1"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.t3.medium"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  publicly_accessible  = false
  db_subnet_group_name = aws_db_subnet_group.aurora.name

  tags = {
    ManagedBy = "terraform"
  }
}

output "aurora_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = aws_rds_cluster.main.endpoint
}

output "aurora_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the master password"
  value       = aws_rds_cluster.main.master_user_secret[0].secret_arn
}

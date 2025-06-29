#################################################
# DATA CONSOLIDATION MODULE
#################################################
# The data consolidation process uses a fargate service and eventbridge to run
terraform {
  required_version = ">= 1.11.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_region" "current" {}

#################################################
# ECR REPOSITORY
#################################################
resource "aws_ecr_repository" "data_consolidation" {
  name                 = "${var.resource_prefix}-data-consolidation"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

#################################################
# ECS CLUSTER
#################################################
resource "aws_ecs_cluster" "data_consolidation" {
  name = "${var.resource_prefix}-data-consolidation"

  # Remove execute_command_configuration - not needed for batch jobs

  tags = var.tags
}

resource "aws_ecs_cluster_capacity_providers" "data_consolidation" {
  cluster_name = aws_ecs_cluster.data_consolidation.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

#################################################
# CLOUDWATCH LOG GROUP
#################################################
resource "aws_cloudwatch_log_group" "data_consolidation" {
  name              = "/ecs/${var.resource_prefix}-data-consolidation"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

#################################################
# TASK DEFINITION
#################################################
resource "aws_ecs_task_definition" "data_consolidation" {
  family                   = "${var.resource_prefix}-data-consolidation"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "data-consolidation"
      image = "${aws_ecr_repository.data_consolidation.repository_url}:latest"

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.data_consolidation.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      environment = [
        {
          name  = "SOURCE_BUCKET_NAME"
          value = var.source_bucket_name
        },
        {
          name  = "CONSOLIDATED_FILE_NAME"
          value = var.consolidated_file_name
        },
        {
          name  = "SOURCE_PREFIX"
          value = var.source_prefix
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = data.aws_region.current.name
        },
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]

      essential = true
    }
  ])

  tags = var.tags
}

#################################################
# SECURITY GROUP
#################################################
resource "aws_security_group" "data_consolidation" {
  name_prefix = "${var.resource_prefix}-data-consolidation-"
  vpc_id      = var.vpc_id
  description = "Security group for data consolidation ECS tasks"

  # No ingress rules needed for batch jobs

  # Only HTTPS within VPC (uses the S3 VPC endpoint from shared infrastructure)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS to AWS services via VPC endpoint"
  }

  tags = merge(var.tags, {
    Name = "${var.resource_prefix}-data-consolidation-sg"
  })
}

#################################################
# IAM ROLES
#################################################
# ECS Execution Role
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.resource_prefix}-data-consolidation-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.resource_prefix}-data-consolidation-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# S3 access policy for the task role - restricted to only necessary permissions
resource "aws_iam_role_policy" "ecs_task_s3_policy" {
  name = "${var.resource_prefix}-data-consolidation-s3-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.source_bucket_name}",
          "arn:aws:s3:::${var.source_bucket_name}/*"
        ]
      }
    ]
  })
}

#################################################
# EVENTBRIDGE SCHEDULER
#################################################
# EventBridge Scheduler Role
resource "aws_iam_role" "eventbridge_scheduler_role" {
  name = "${var.resource_prefix}-data-consolidation-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Policy for EventBridge to run ECS tasks
resource "aws_iam_role_policy" "eventbridge_scheduler_policy" {
  name = "${var.resource_prefix}-data-consolidation-scheduler-policy"
  role = aws_iam_role.eventbridge_scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = [
          aws_ecs_task_definition.data_consolidation.arn,
          "${aws_ecs_task_definition.data_consolidation.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      }
    ]
  })
}

# EventBridge Schedule Group
resource "aws_scheduler_schedule_group" "data_consolidation" {
  name = "${var.resource_prefix}-data-consolidation"

  tags = var.tags
}

# EventBridge Schedule
resource "aws_scheduler_schedule" "data_consolidation" {
  name       = "${var.resource_prefix}-data-consolidation-schedule"
  group_name = aws_scheduler_schedule_group.data_consolidation.name

  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = var.schedule_timezone
  description                  = "Triggers data consolidation task every 48 hours"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_ecs_cluster.data_consolidation.arn
    role_arn = aws_iam_role.eventbridge_scheduler_role.arn

    ecs_parameters {
      task_definition_arn = aws_ecs_task_definition.data_consolidation.arn
      launch_type         = "FARGATE"
      platform_version    = "LATEST"

      network_configuration {
        subnets          = var.private_subnet_ids
        security_groups  = [aws_security_group.data_consolidation.id]
        assign_public_ip = false
      }
    }

    retry_policy {
      maximum_retry_attempts = 3
    }
  }
}

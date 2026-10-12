data "aws_caller_identity" "me" {}

# Built by api/build.sh before plan; the hash makes Terraform redeploy only when the code changes.
locals {
  lambda_zip = "${path.module}/../api/build/lambda.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api" {
  name               = "shop-api"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# CloudWatch Logs + creating network interfaces in our private subnets.
resource "aws_iam_role_policy_attachment" "api_vpc" {
  role       = aws_iam_role.api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "api_db" {
  statement {
    actions   = ["rds-db:connect"]
    resources = ["arn:aws:rds-db:eu-north-1:${data.aws_caller_identity.me.account_id}:dbuser:*/shop_api"]
  }
}

resource "aws_iam_role_policy" "api_db" {
  name   = "connect-as-shop-api"
  role   = aws_iam_role.api.id
  policy = data.aws_iam_policy_document.api_db.json
}

# Master secret, only for the one-off migrate.
resource "aws_iam_role_policy" "api_migrate" {
  count = var.create_db ? 1 : 0

  name = "read-master-secret"
  role = aws_iam_role.api.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_db_instance.shop[0].master_user_secret[0].secret_arn
    }]
  })
}

resource "aws_lambda_function" "api" {
  function_name    = "shop-api"
  role             = aws_iam_role.api.arn
  runtime          = "python3.13"
  architectures    = ["arm64"]
  handler          = "shop.lambda_handler.handler"
  filename         = local.lambda_zip
  source_code_hash = filebase64sha256(local.lambda_zip)
  memory_size      = 512
  timeout          = 30

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_HOST       = var.create_db ? aws_db_instance.shop[0].address : ""
      DB_SECRET_ARN = var.create_db ? aws_db_instance.shop[0].master_user_secret[0].secret_arn : ""
    }
  }

  depends_on = [aws_cloudwatch_log_group.api, aws_iam_role_policy_attachment.api_vpc]
}

# HTTPS endpoint for the API. AWS_IAM: only requests signed by an allowed AWS identity get in.
resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api.function_name
  authorization_type = "AWS_IAM"
}

output "api_url" {
  value = aws_lambda_function_url.api.function_url
}

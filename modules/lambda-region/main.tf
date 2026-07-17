# Deploys the regional health-check/canary Lambda plus a Function URL. A
# Function URL is used instead of API Gateway to keep the reference
# architecture minimal - swap in API Gateway/ALB if you need custom
# domains, auth, or WAF in front of it.

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = "${path.module}/.build/${var.region_name}-lambda.zip"
}

resource "aws_iam_role" "lambda_exec" {
  provider = aws.this
  name     = "${var.project_name}-${var.environment}-${var.region_name}-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  provider   = aws.this
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dynamodb_access" {
  provider = aws.this
  name     = "${var.project_name}-${var.environment}-${var.region_name}-ddb"
  role     = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Query"
      ]
      Resource = [
        var.dynamodb_table_arn,
        "${var.dynamodb_table_arn}/index/*"
      ]
    }]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  provider          = aws.this
  name              = "/aws/lambda/${var.project_name}-${var.environment}-${var.region_name}"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_lambda_function" "this" {
  provider = aws.this

  function_name    = "${var.project_name}-${var.environment}-${var.region_name}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      DDB_TABLE_NAME = var.dynamodb_table_name
      ENVIRONMENT    = var.environment
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
  tags       = var.tags
}

resource "aws_lambda_function_url" "this" {
  provider           = aws.this
  function_name      = aws_lambda_function.this.function_name
  authorization_type = "NONE" # Reference architecture only - add auth before production use.
}

resource "aws_lambda_permission" "public_url" {
  provider               = aws.this
  statement_id           = "AllowPublicFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.this.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

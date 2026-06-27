terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
resource "aws_lambda_function" "s3_remediation" {
  function_name = "s3-auto-remediation"

  filename         = "../lambda/remediation.zip"
  source_code_hash = filebase64sha256("../lambda/remediation.zip")

  handler = "remediation.lambda_handler"
  runtime = "python3.12"

  role = aws_iam_role.lambda_remediation_role.arn

  timeout = 30
}
resource "aws_cloudwatch_event_rule" "config_noncompliant" {
  name        = "config-noncompliant-s3"
  description = "Trigger Lambda when AWS Config detects S3 bucket changes."

  event_pattern = jsonencode({
    "source" : ["aws.config"],
    "detail-type" : ["Config Rules Compliance Change"],
    "detail" : {
      "configRuleName" : ["s3-bucket-public-read-prohibited"],
      "newEvaluationResult" : {
        "complianceType" : ["NON_COMPLIANT"]
      }
    }
  })
}
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.config_noncompliant.name
  target_id = "s3-remediation-lambda"
  arn       = aws_lambda_function.s3_remediation.arn
}
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_remediation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.config_noncompliant.arn
}
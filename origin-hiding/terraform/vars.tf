variable "lambda_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_runtime" {
  description = "Runtime for the Lambda function"
  type        = string
  default     = "nodejs20.x"
}

variable "lambda_handler" {
  description = "Handler for the Lambda function"
  type        = string
  default     = "aws-lambda-edge-origin-hiding.handler"
}

variable "lambda_filename" {
  description = "Path to the Lambda deployment package zip"
  type        = string
}

variable "shared_secret" {
  description = "Shared secret used for HMAC signing"
  type        = string
  sensitive   = true
}

variable "lambda_role_arn" {
  description = "IAM role ARN for the Lambda function"
  type        = string
}

variable "deploy_region" {
  description = "AWS region for Lambda (use us-east-1 for Lambda@Edge)"
  type        = string
}

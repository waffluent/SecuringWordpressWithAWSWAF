resource "aws_lambda_function" "origin_hiding" {
  function_name = var.lambda_name
  role          = var.lambda_role_arn
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  filename      = var.lambda_filename

  environment {
    variables = {
      CF_ORIGIN_CIDRS = jsonencode([
        for entry in data.aws_ec2_managed_prefix_list_entries.cloudfront_origin_entries.entries : entry.cidr
      ])
      SHARED_SECRET = var.shared_secret
    }
  }
}

# Allow CloudFront to invoke Lambda@Edge
resource "aws_lambda_permission" "allow_cloudfront" {
  statement_id  = "AllowExecutionFromCloudFront"
  action        = "lambda:GetFunction"
  function_name = aws_lambda_function.origin_hiding.function_name
  principal     = "edgelambda.amazonaws.com"
}

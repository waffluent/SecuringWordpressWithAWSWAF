output "lambda_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.origin_hiding.function_name
}

output "lambda_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.origin_hiding.arn
}

output "cloudfront_prefix_list_id" {
  description = "The Prefix List ID for CloudFront origin-facing IPs"
  value       = data.aws_ec2_managed_prefix_list.cloudfront_origin.id
}

output "cloudfront_origin_cidrs" {
  description = "The list of CloudFront origin-facing CIDRs"
  value       = [
    for entry in data.aws_ec2_managed_prefix_list_entries.cloudfront_origin_entries.entries : entry.cidr
  ]
}

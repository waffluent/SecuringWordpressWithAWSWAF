# Retrieve AWS-managed CloudFront origin-facing prefix list
data "aws_ec2_managed_prefix_list" "cloudfront_origin" {
  name   = "com.amazonaws.global.cloudfront.origin-facing"
  region = var.deploy_region
}

# Retrieve all CIDR entries in the prefix list
data "aws_ec2_managed_prefix_list_entries" "cloudfront_origin_entries" {
  prefix_list_id = data.aws_ec2_managed_prefix_list.cloudfront_origin.id
  region         = var.deploy_region
}

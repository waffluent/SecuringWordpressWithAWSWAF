# Securing Wordpress With AWS WAF(v2)

---

# AWS Lambda Origin-Hiding with CloudFront Managed Prefix List

This Terraform module deploys a **secure AWS Lambda function** (usable as Lambda\@Edge for CloudFront or as a Regional Lambda for ALB/API Gateway) that generates a signed header (`x-aws-pass`) for origin-hiding and request authentication.

The Lambda:

* Uses a **shared HMAC secret** to sign requests
* In **CloudFront mode**:
  * Confirms execution in Lambda\@Edge context
  * Validates source IP against AWS’s **CloudFront origin-facing Managed Prefix List (MPL)**
  * Uses AWS-generated `requestId` as the nonce (non-spoofable)
* In **Regional mode**:
  * Skips MPL check
  * Generates a random nonce in AWS

The module dynamically retrieves the latest **CloudFront MPL CIDRs** at deploy time, so no manual IP maintenance is required.

---

## **Files Overview**

### **1. `vars.tf`**

Defines all module input variables:

* **`lambda_name`**: Name of the Lambda function.
* **`lambda_runtime`**: Runtime environment (default: `nodejs20.x`).
* **`lambda_handler`**: Lambda handler (default: `aws-lambda-edge-origin-hiding.handler`).
* **`lambda_filename`**: Path to the zipped Lambda code.
* **`shared_secret`**: HMAC signing secret (sensitive).
* **`lambda_role_arn`**: IAM role ARN assigned to the Lambda.
* **`deploy_region`**: AWS region to deploy Lambda (`us-east-1` for Lambda\@Edge).

---

### **2. `data.tf`**

Retrieves AWS-managed CloudFront MPL data at deploy time:

* **`aws_ec2_managed_prefix_list`**: Metadata for `com.amazonaws.global.cloudfront.origin-facing`.
* **`aws_ec2_managed_prefix_list_entries`**: List of all IPv4 and IPv6 CIDRs in the MPL.

These CIDRs are passed to the Lambda as an environment variable (`CF_ORIGIN_CIDRS`).

---

### **3. `main.tf`**

Creates the Lambda function:

* Sets environment variables:

  * `CF_ORIGIN_CIDRS`: JSON array of all CloudFront origin-facing CIDRs (from MPL)
  * `SHARED_SECRET`: The HMAC signing key
* Includes a `lambda_permission` so CloudFront can invoke the function when used with Lambda\@Edge.

---

### **4. `outputs.tf`**

Exposes useful outputs:

* `lambda_name`
* `lambda_arn`
* `cloudfront_prefix_list_id`
* `cloudfront_origin_cidrs` (array of CIDRs in the MPL)

---

### **5. `aws-lambda-edge-origin-hiding.js`**

The Lambda source code:

* **CloudFront Mode** (`event.Records[0].cf` exists):

  * Verifies `clientIp` is in MPL CIDRs
  * Uses `cfEvent.config.requestId` (non-spoofable) as nonce
  * Generates HMAC signature from:

    ```
    <base64-hmac>.<timestamp>.<nonce>
    ```
  * Adds `x-aws-pass` header to the response
* **Regional Mode**:

  * Skips MPL check
  * Uses a random nonce
  * Generates same signature format
  * Adds `x-aws-pass` header to the response

---

## **Usage Example**

### 1. **Module Call in Root Terraform**

```hcl
module "origin_hiding_lambda" {
  source          = "./modules/aws-lambda-origin-hiding"
  lambda_name     = "origin-hiding-signer"
  lambda_runtime  = "nodejs20.x"
  lambda_filename = "${path.module}/lambda.zip"
  lambda_role_arn = aws_iam_role.lambda_execution.arn
  shared_secret   = var.shared_secret
  deploy_region   = "us-east-1" # For Lambda@Edge; change for regional Lambda
}
```

---

### 2. **IAM Role for Lambda**

```hcl
resource "aws_iam_role" "lambda_execution" {
  name = "lambda-origin-hiding-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_exec" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
```

---

### 3. **Package and Deploy Lambda**

```bash
zip lambda.zip aws-lambda-edge-origin-hiding.js
terraform init
terraform apply
```

---

### 4. **Attach to CloudFront or Regional Service**

* **CloudFront WAF**:

  * Deploy Lambda in `us-east-1`
  * Attach to Viewer Response event in CloudFront
* **Regional WAF (ALB, API Gateway)**:

  * Deploy Lambda in target region
  * Attach to service’s integration point

---

## **Security Notes**

* In CloudFront mode, requests are validated **twice**:

  1. **Lambda**: Confirms request came from CloudFront MPL CIDR and uses AWS-generated nonce.
  2. **Origin App**: Verifies HMAC using shared secret.
* In Regional mode, MPL check is skipped but nonce is still AWS-generated.
* `shared_secret` must be identical in Lambda and origin verification code.
* MPL list is updated automatically at every Terraform apply.



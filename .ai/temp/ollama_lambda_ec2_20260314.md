# AWS research notes — ollama_lambda_ec2 (2026-03-14)

## Scope
- Region: `ap-northeast-1`
- Design reviewed: API Gateway HTTP API -> Lambda (Python 3.12, x86_64, VPC) -> EC2 (AL2023, x86_64) running Ollama on `11434/tcp`
- Goal: implementation-ready AWS guidance and Terraform pitfalls, no application code

## Key source-backed findings

### Lambda in VPC
- Lambda attached to a customer VPC needs ENI permissions. AWS-managed policy `AWSLambdaVPCAccessExecutionRole` includes:
  - `logs:CreateLogGroup`
  - `logs:CreateLogStream`
  - `logs:PutLogEvents`
  - `ec2:CreateNetworkInterface`
  - `ec2:DescribeNetworkInterfaces`
  - `ec2:DescribeSubnets`
  - `ec2:DeleteNetworkInterface`
  - `ec2:AssignPrivateIpAddresses`
  - `ec2:UnassignPrivateIpAddresses`
- Lambda connected to a VPC **does not get internet access by being placed in a public subnet**. AWS explicitly states that connecting a function to a public subnet does not give it internet access or a public IP.
- Lambda service creates Hyperplane ENIs; ENI quota is shared with the VPC and defaults to 500 per VPC.
- Relevant quotas:
  - timeout up to 900s, but API Gateway integration timeout is lower
  - env vars aggregate size 4 KB
  - sync request/response payload 6 MB each
  - zip package 50 MB uploaded / 250 MB unzipped including layers
  - concurrency default 1,000 per Region (new accounts can be lower)

### API Gateway HTTP API
- HTTP API max integration timeout is **30 seconds** and is **not increaseable**.
- HTTP API payload size limit is **10 MB**.
- Total combined request line + header values limit is **10,240 bytes**.
- HTTP API stages require deployment unless `auto_deploy` is enabled.
- `$default` stage can serve from the base invoke URL.
- Access logging is recommended for all stages and requires a CloudWatch Logs log group ARN on the stage.

### Effective end-to-end payload/timeout implication for this design
- `29s` Lambda timeout is valid with HTTP API because HTTP API allows up to `30s` integration timeout.
- Effective non-streaming response ceiling is the stricter Lambda sync payload limit: **6 MB response** even though HTTP API allows 10 MB.
- Effective request ceiling to Lambda is also **6 MB**.
- `x-api-key` header is fine, but total header budget remains small (10 KB combined), so avoid large custom headers.
- Because the budget is only 1 second under the HTTP API hard cap, cold start + Secrets Manager lookup + EC2 connect + Ollama inference can easily consume the margin.

### Default VPC / default subnet behavior
- A default VPC includes public subnets in each AZ, an internet gateway, and DNS resolution enabled.
- Default subnets are public by default because their route table sends `0.0.0.0/0` to the internet gateway.
- Instances launched into a default subnet receive a public IPv4 address by default unless subnet/launch behavior is overridden.
- If a default VPC has been modified or deleted previously, assumptions about default subnets/AZ coverage may fail.

### EC2 / Session Manager / IMDSv2
- Session Manager prerequisites include:
  - supported OS
  - SSM Agent at least `2.3.68.0+` (higher for advanced features)
  - outbound HTTPS (`443`) to `ssm`, `ssmmessages`, and `ec2messages` endpoints, or corresponding interface endpoints
- `AmazonSSMManagedInstanceCore` is sufficient for Systems Manager core functionality / Session Manager on the instance profile.
- Systems Manager now recommends Default Host Management Configuration where appropriate, but instance profile with `AmazonSSMManagedInstanceCore` remains valid.
- IMDS options should be set explicitly; `http_tokens=required` enforces IMDSv2 only.
- If an AMI is registered with `imds-support=v2.0`, launched instances default to IMDSv2 and hop limit 2, but launch-time settings take precedence.

### Secrets Manager
- Best practices: store secrets in Secrets Manager, limit access, optionally use customer-managed KMS only when needed, and cache secret retrievals client-side to reduce cost and latency.
- `GetSecretValue` requires `secretsmanager:GetSecretValue`.
- Secrets have versions with staging labels; `AWSCURRENT` is returned by default.
- Secrets Manager supports interface VPC endpoints (`com.amazonaws.region.secretsmanager`) so private workloads can read secrets without NAT or internet access.

### CloudWatch Logs
- Log groups default to **indefinite retention** unless you set retention explicitly.
- Log data is always encrypted at rest; optional customer-managed KMS can be associated per log group.
- If you use customer-managed KMS and later disable/delete the key, affected log data becomes unreadable.
- API Gateway HTTP API access logging should use a dedicated log group.

### Security groups
- SGs are allow-only; no deny rules.
- New SGs default to no inbound rules and one allow-all outbound rule.
- SG-to-SG references are a supported and appropriate way to restrict EC2 `11434/tcp` ingress to Lambda only.

## Design risks / ambiguities / Terraform-sensitive nuances

1. **Biggest design gap: Lambda in VPC + no NAT + secret lookup**
   - VPC-attached Lambda cannot use the public internet just because it is in default/public subnets.
   - If Lambda must call Secrets Manager at runtime and you do not add NAT, add a **Secrets Manager interface VPC endpoint**.
   - Same consideration applies to any other AWS API your function code directly calls from inside the VPC.

2. **EC2 egress versus “not publicly exposed”**
   - Default subnet behavior usually gives the EC2 a public IPv4 address unless you explicitly disable it.
   - If you disable public IP and also avoid NAT, initial Ansible/Ollama install and model pull from the internet will fail.
   - So initial version must choose one of:
     - allow EC2 outbound internet via public IP in default subnet while keeping inbound SG closed, or
     - add NAT / proxy / alternate package mirror strategy.

3. **29s timeout is valid but fragile**
   - With only 1 second under the API Gateway hard cap, any cold start, secret fetch, DNS jitter, slow model load, or longer prompt can flip requests into 504 territory.
   - This is acceptable for learning, but not a generous budget.

4. **Default VPC lookup is convenient but brittle in Terraform**
   - Some accounts delete/modify default VPCs or default subnets.
   - Filtering by `default = true` can fail or produce unexpected AZ distribution if the environment is non-pristine.

5. **Terraform + Secrets Manager value handling**
   - If Terraform writes `secret_string` directly, the secret value lands in Terraform state. Treat that as an explicit security decision.
   - If you want Terraform to create the secret metadata only, populate/rotate the value outside Terraform or via tightly controlled CI input.

6. **Lambda package reproducibility**
   - Local-source zip packaging is easy but can create nondeterministic diffs if file timestamps / junk files / `__pycache__` are included.
   - Python packaging docs recommend bundling your own dependencies, including Boto3, to avoid runtime-included SDK version skew.

7. **HTTP API deployment gotcha**
   - Route/integration changes do not reach clients unless a deployment is associated to the stage, unless `auto_deploy=true` is enabled.

8. **Log retention gotcha**
   - If you let Lambda/API Gateway create log groups implicitly, retention defaults to indefinite. Create log groups explicitly in Terraform and set retention.

9. **Session Manager hidden dependency**
   - `AmazonSSMManagedInstanceCore` alone is not enough if the instance cannot reach `ssm`, `ssmmessages`, and `ec2messages` over `443`.

## Implementation instructions for the Terraform coder

- Prefer **two subnet IDs** for Lambda VPC config for AZ resilience, but validate the chosen default subnets exist in `ap-northeast-1`.
- Treat the Lambda VPC networking path and the Secrets Manager access path separately:
  - Lambda -> EC2 private IP works inside the VPC.
  - Lambda -> Secrets Manager needs either NAT or a Secrets Manager interface endpoint.
- If the project must avoid NAT in v1, add a **Secrets Manager interface VPC endpoint** and note the hourly/data cost tradeoff.
- For EC2, decide explicitly whether to keep public IP assignment enabled for bootstrap/model downloads. Do not leave this as an accidental default.
- Require **IMDSv2** on EC2 (`http_tokens=required`); set hop limit intentionally.
- Attach only `AmazonSSMManagedInstanceCore` to the EC2 instance role for v1 unless CloudWatch Agent/S3 access is added later.
- For Lambda IAM, attach either:
  - `AWSLambdaVPCAccessExecutionRole`, plus a custom policy for secret read, or
  - a custom least-privilege equivalent including ENI + logs + `secretsmanager:GetSecretValue` on the secret ARN.
- If the secret uses a customer-managed KMS key, add `kms:Decrypt` scoped to that key.
- Pass only **secret ARN/name** to Lambda environment variables, not the secret value.
- In Lambda, cache the secret value outside the hot path where practical to reduce latency/cost.
- Use HTTP API **payload format version 2.0** unless you have a reason to prefer 1.0.
- Explicitly create the HTTP API stage and enable `auto_deploy=true` for the initial learning project, or manage deployments intentionally.
- Explicitly create CloudWatch log groups for:
  - Lambda function logs
  - API Gateway access logs
- Set retention explicitly (for example, short in dev, longer in prod) instead of relying on the default indefinite retention.
- If you choose KMS-encrypted log groups, ensure the key policy allows CloudWatch Logs and document the operational risk of disabling the key.
- Use SG-to-SG rules, not CIDR rules, for Lambda -> EC2 `11434/tcp`.
- Remove broad default egress where practical:
  - Lambda SG: allow only `11434/tcp` to EC2 SG (and endpoint SGs if VPC endpoints are used)
  - EC2 SG: allow only required outbound internet/API traffic for bootstrap/updates
- Do not log `x-api-key`, secret values, or full request bodies by default.
- Keep API Gateway access log format minimal and structured JSON.
- Validate that the planned Ollama responses remain comfortably below **6 MB** and complete within the **29s** end-to-end budget.

## Recommended unresolved decisions to settle before coding
- Will Lambda access Secrets Manager through a **VPC endpoint** or will the design allow a NAT path later?
- Will the EC2 instance intentionally keep a **public IP for outbound bootstrap/model pulls**, or is another egress strategy required?
- Will Terraform manage the **secret value** itself, accepting storage in state, or only the secret container/metadata?
- Should API Gateway access logs and Lambda logs use default AWS-managed encryption or customer-managed KMS keys?

## Primary references
- Giving Lambda functions access to resources in an Amazon VPC — https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc.html
- Enable internet access for VPC-connected Lambda functions — https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc-internet.html
- Lambda quotas — https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html
- Deploying Lambda functions as .zip file archives — https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-package.html
- Working with .zip file archives for Python Lambda functions — https://docs.aws.amazon.com/lambda/latest/dg/python-package.html
- Quotas for configuring and running an HTTP API in API Gateway — https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-quotas.html
- Create AWS Lambda proxy integrations for HTTP APIs in API Gateway — https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-lambda.html
- Stages for HTTP APIs in API Gateway — https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-stages.html
- Configure logging for HTTP APIs in API Gateway — https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-logging.html
- Default VPCs — https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html
- Default subnets — https://docs.aws.amazon.com/vpc/latest/userguide/default-subnet.html
- Security group rules — https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html
- Configure the Instance Metadata Service options — https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-options.html
- Step 1: Complete Session Manager prerequisites — https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-prerequisites.html
- Configure instance permissions required for Systems Manager — https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-permissions.html
- AmazonSSMManagedInstanceCore — https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonSSMManagedInstanceCore.html
- AWSLambdaVPCAccessExecutionRole — https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AWSLambdaVPCAccessExecutionRole.html
- AWS Secrets Manager best practices — https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html
- Using an AWS Secrets Manager VPC endpoint — https://docs.aws.amazon.com/secretsmanager/latest/userguide/vpc-endpoint-overview.html
- Get a Secrets Manager secret value using the Python AWS SDK — https://docs.aws.amazon.com/secretsmanager/latest/userguide/retrieving-secrets-python-sdk.html
- What's in a Secrets Manager secret? — https://docs.aws.amazon.com/secretsmanager/latest/userguide/whats-in-a-secret.html
- Working with log groups and log streams — https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html
- Encrypt log data in CloudWatch Logs using AWS KMS — https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html

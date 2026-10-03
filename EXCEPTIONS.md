# Security Exceptions Register

Every Checkov finding in this repo is either fixed or listed here with a reason. Each exception is also marked in the code with a `#checkov:skip` comment next to the resource it applies to.

**Last reviewed:** 2026-10-02
**Scan result:** 88 passed, 0 failed, 7 skipped

## Fixed

| Check | Requirement | Fix |
| --- | --- | --- |
| CKV_AWS_338 | Keep CloudWatch logs at least 1 year | Log retention raised from 14 to 365 days |
| CKV_AWS_50 | Enable X-Ray tracing on Lambda | Active tracing enabled, with `xray:PutTraceSegments` and `xray:PutTelemetryRecords` permissions |

## Accepted exceptions

| Check | Resource | Requirement | Reason | Compensating control / plan |
| --- | --- | --- | --- | --- |
| CKV_AWS_158 | Lambda log group | Customer-managed KMS key for logs | Logs use AWS-managed encryption by default; a customer-managed key adds cost with no benefit for lab data | Encryption at rest still applies |
| CKV_AWS_145 | Data and state S3 buckets | Customer-managed KMS key for S3 | Both buckets are encrypted at rest with AWS-managed AES256 keys; a KMS key adds monthly cost with no benefit for lab data | Encryption at rest, public access blocked, TLS-only policy on state |
| CKV_AWS_173 | Lambda function | Customer-managed KMS key for environment variables | Only variable is the non-secret bucket name | Encrypted at rest with an AWS-managed key |
| CKV_AWS_117 | Lambda function | Run inside a VPC | Function only calls S3 and CloudWatch; a VPC would need a NAT Gateway or paid endpoints with no security gain | Least-privilege IAM role limits what it can reach |
| CKV_AWS_116 | Lambda function | Dead-letter queue | No asynchronous trigger exists, so a DLQ would never receive events | Revisit when a trigger is added |
| CKV_AWS_115 | Lambda function | Reserved concurrency limit | New accounts often have an account limit of 10 and AWS requires 10 unreserved, so this would fail apply | Revisit after a quota increase |
| CKV_AWS_272 | Lambda function | Code signing | Requires AWS Signer setup | Planned supply-chain hardening upgrade |
| CKV_AWS_274 | GitHub Actions apply role | No `AdministratorAccess` | Terraform must create IAM roles and other resources | Trust policy limited to this repo's `prod` environment, with manual approval; scoped policy planned |

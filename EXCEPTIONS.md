# Security Exceptions Register

Every Checkov finding in this repo is either fixed or listed here with a reason. Each exception is also marked in the code with a `#checkov:skip` comment next to the resource it applies to.

**Last reviewed:** 2026-10-23
**Scan result:** 223 passed, 0 failed, 17 skipped (Checkov 3.3.20 with custom policies)

## Fixed

| Check | Requirement | Fix |
| --- | --- | --- |
| CKV_AWS_338 | Keep CloudWatch logs at least 1 year | Log retention raised from 14 to 365 days |
| CKV_AWS_50 | Enable X-Ray tracing on Lambda | Active tracing enabled, with `xray:PutTraceSegments` and `xray:PutTelemetryRecords` permissions |
| CKV2_AWS_61 | Data bucket needs a lifecycle configuration | Old versions expire after 90 days; incomplete uploads cleaned up after 7 days |

## Accepted exceptions

| Check | Resource | Requirement | Reason | Compensating control / plan |
| --- | --- | --- | --- | --- |
| CKV_AWS_158 | Lambda log group | Customer-managed KMS key for logs | Logs use AWS-managed encryption by default; a customer-managed key adds cost with no benefit for lab data | Encryption at rest still applies |
| CKV_AWS_145 | Data and state S3 buckets | Customer-managed KMS key for S3 | Both buckets are encrypted at rest with AWS-managed AES256 keys; a KMS key adds monthly cost with no benefit for lab data | Encryption at rest, public access blocked, TLS-only policy on state |
| CKV2_AWS_62 | Data and state S3 buckets | Event notifications | No service consumes bucket events | Revisit when a trigger is added |
| CKV_AWS_18 | Data and state S3 buckets | Access logging | Would need a separate log bucket that fails the same check | CloudTrail data events planned once deployed |
| CKV_AWS_144 | Data and state S3 buckets | Cross-region replication | Doubles storage cost for lab data | Versioning, and prevent_destroy on state |
| CKV2_AWS_11 | VPC | Flow logs | No workloads run inside the VPC yet | Flow logs planned when a workload is added |
| CKV_AWS_173 | Lambda function | Customer-managed KMS key for environment variables | Only variable is the non-secret bucket name | Encrypted at rest with an AWS-managed key |
| CKV_AWS_117 | Lambda function | Run inside a VPC | Function only calls S3 and CloudWatch; a VPC would need a NAT Gateway or paid endpoints with no security gain | Least-privilege IAM role limits what it can reach |
| CKV_AWS_116 | Lambda function | Dead-letter queue | No asynchronous trigger exists, so a DLQ would never receive events | Revisit when a trigger is added |
| CKV_AWS_115 | Lambda function | Reserved concurrency limit | New accounts often have an account limit of 10 and AWS requires 10 unreserved, so this would fail apply | Revisit after a quota increase |
| CKV_AWS_272 | Lambda function | Code signing | Requires AWS Signer setup | Planned supply-chain hardening upgrade |
| CKV_AWS_274 | GitHub Actions apply role | No `AdministratorAccess` | Terraform must create IAM roles and other resources | Trust policy limited to this repo's `prod` environment, with manual approval; scoped policy planned |

## drift-ci: long-lived IAM access key for scheduled drift detection

- **Checks/controls:** CKV_AWS_273 (skipped on `aws_iam_user.drift_ci`); CIS 1.13 (rotate keys every 90 days) applies
- **Why:** AWS-managed SCPs deny `iam:*Provider*` (no GitHub OIDC) and `iam:CreateGroup`
- **Scope:** user `drift-check-ci` has no identity policies; its key can only assume role `drift-readonly` (trust policy names that user ARN only). Role carries `SecurityAudit` + `s3:ListBucket` on the state bucket + `s3:GetObject` on `lab/terraform.tfstate` + `drift-extra-reads` (`lambda:GetFunction`, `GetFunctionCodeSigningConfig`, `ListVersionsByFunction` on `devsecops-lab-*` functions only, because SecurityAudit omits them). 15-minute sessions, no write permissions anywhere.
- **Compensating controls:**
  - Secrets scoped to GitHub Environment `drift`, deployable from protected branches only
  - Plan output redacted to resource addresses in public logs
  - Account ID masked (`::add-mask::`) in every job log
  - `-lock=false`, so the job never writes state or lock files
  - Key created outside Terraform, so it's never in state
- **Rotation (every 90 days):** create key 2 → update both secrets → dispatch run → deactivate key 1 → delete key 1
- **Key created:** 2026-10-23 · **Next rotation due:** 2027-01-21
- **Exit criteria:** if the SCP is lifted, enable `github-oidc`, switch the workflow to OIDC role assumption, delete this user

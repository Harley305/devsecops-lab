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

Each entry states why the check is skipped, the residual risk, what limits that risk today, and what event ends the exception.

| Check | Resource | Requirement | Reason | Risk | Compensating control | Revisit when |
| --- | --- | --- | --- | --- | --- | --- |
| CKV_AWS_158 | Lambda log group | Customer-managed KMS key for logs | AWS-managed encryption applies by default; a customer-managed key adds cost with no benefit for lab data | Low. Decryption is governed by IAM alone, with no separate key policy | Encryption at rest; log read access limited by IAM; logs hold no secrets | Logs ever contain sensitive data |
| CKV_AWS_145 | Data and state S3 buckets | Customer-managed KMS key for S3 | Both buckets use AWS-managed AES256 keys; a KMS key adds monthly cost with no benefit for lab data | Low. No independent key policy or key-level audit trail over decryption | Encryption at rest, public access blocked, TLS-only bucket policy on both buckets | Buckets ever hold sensitive data |
| CKV2_AWS_62 | Data and state S3 buckets | Event notifications | No service consumes bucket events | None. This is a functional check, not a security control | Not needed | A trigger is added |
| CKV_AWS_18 | Data and state S3 buckets | Access logging | Would need a separate log bucket that fails the same check | Medium. Object-level reads and writes are not logged, so unauthorized state access would not be visible | Bucket-level changes recorded in CloudTrail event history (default, 90 days); access limited by IAM; drift role is read-only | SOC lab phase (CloudTrail data events) |
| CKV_AWS_144 | Data and state S3 buckets | Cross-region replication | Doubles storage cost for lab data | Low. A regional outage makes data and state unavailable; versioning does not cover that | Versioning; `prevent_destroy` on state; infrastructure is code, so state can be rebuilt by import | Data becomes non-reproducible |
| CKV2_AWS_11 | VPC | Flow logs | No workloads run inside the VPC yet | None. There is no traffic to log | Not needed | A workload is added |
| CKV_AWS_173 | Lambda function | Customer-managed KMS key for environment variables | Only variable is the non-secret bucket name | None. No secret values are stored in environment variables | Encrypted at rest with an AWS-managed key | A secret is needed (use Secrets Manager, not an env var) |
| CKV_AWS_117 | Lambda function | Run inside a VPC | Function only calls S3 and CloudWatch; a VPC would need a NAT Gateway or paid endpoints with no security gain | Low. Egress is not restricted by security groups | Least-privilege IAM role limits what it can reach; code scanned by Semgrep in CI | Function needs private resources |
| CKV_AWS_116 | Lambda function | Dead-letter queue | No asynchronous trigger exists, so a DLQ would never receive events | None. Synchronous invocations return errors to the caller | Not needed | An async trigger is added |
| CKV_AWS_115 | Lambda function | Reserved concurrency limit | New accounts often have an account limit of 10 and AWS requires 10 unreserved, so this would fail apply | Low. Runaway invocations could use up account concurrency | Account concurrency limit caps total invocations | Quota increase approved |
| CKV_AWS_272 | Lambda function | Code signing | Requires AWS Signer setup | Low. Anyone with `lambda:UpdateFunctionCode` could deploy unreviewed code | Code deploys only through Terraform from reviewed `main`; daily drift check reads function config and flags out-of-band changes | Supply-chain hardening phase |
| CKV_AWS_274 | GitHub Actions apply role | No `AdministratorAccess` | Terraform must create IAM roles and other resources | None today, because the role does not exist. High if enabled | Module is disabled (`count = 0`) because the SCP blocks OIDC providers. If enabled: trust policy limited to this repo's `prod` environment, with manual approval | Module is enabled (replace with a scoped policy first) |

## drift-ci: long-lived IAM access key for scheduled drift detection

- **Checks/controls:** CKV_AWS_273 (skipped on `aws_iam_user.drift_ci`); CIS 1.13 (rotate keys every 90 days) applies
- **Why:** AWS-managed SCPs deny `iam:*Provider*` (no GitHub OIDC) and `iam:CreateGroup`
- **Risk:** a leaked key allows read-only access to account security configuration and the state file, in sessions of up to 1 hour, until the key is deactivated
- **Scope:** user `drift-check-ci` has no identity policies and a permissions boundary (`drift-ci-boundary`) capping it at `sts:AssumeRole` on `drift-readonly`; its key can only assume role `drift-readonly` (trust policy names that user ARN only). Role carries `SecurityAudit` + `s3:ListBucket` on the state bucket + `s3:GetObject` on `lab/terraform.tfstate` and `bootstrap/terraform.tfstate` + `drift-extra-reads` (`lambda:GetFunction`, `GetFunctionCodeSigningConfig`, `ListVersionsByFunction` on `devsecops-lab-*` functions only, because SecurityAudit omits them) + `access-analyzer:ValidatePolicy` for the daily policy check. Workflow requests 15-minute sessions (role maximum 1 hour); no write permissions anywhere.
- **Compensating controls:**
  - Secrets scoped to GitHub Environment `drift`, deployable from protected branches only
  - Plan output redacted to resource addresses in public logs
  - Account ID masked (`::add-mask::`) in every job log
  - `-lock=false`, so the job never writes state or lock files
  - Key created outside Terraform, so it's never in state
- **Rotation (every 90 days):** create key 2 → update both secrets → dispatch run → deactivate key 1 → delete key 1
- **Automated check:** daily drift run reports key age, warns from day 75, fails from day 90
- **Key created:** 2026-10-23 · **Next rotation due:** 2027-01-21
- **Exit criteria:** if the SCP is lifted, enable `github-oidc`, switch the workflow to OIDC role assumption, delete this user

## Considered and not adopted

Hardening and detection options reviewed and deliberately not adopted.

| Control | Why not adopted | Risk | Compensating control | Revisit when |
| --- | --- | --- | --- | --- |
| S3 Object Lock (Compliance mode) on state bucket | Object Lock can't be disabled once enabled, and compliance-mode retention can't be shortened or removed by anyone, including root; this blocks bucket teardown in a lab and conflicts with avoiding irreversible account settings | Medium. A principal with `s3:DeleteObjectVersion` on the state bucket could purge old state versions | No CI identity can write or delete in the state bucket (drift role reads the two state objects only); versioning; `prevent_destroy`; deletes require admin credentials | State must survive a compromised admin |
| MFA Delete on state bucket | Can only be enabled by the root user with root MFA through the CLI or API; Terraform can't manage it, and it would require root access keys, which CIS 1.4 prohibits | Low. Version deletes and versioning suspension don't require MFA | Same as above | Never via root keys; use Object Lock governance mode if deletion protection becomes a requirement |
| Real-time drift detection | Needs a CloudTrail and EventBridge pipeline, which is paid and belongs to the SOC lab phase | Low. A change made right after the 13:17 UTC run can go unseen for up to about 24 hours | Daily scheduled run plus on-demand runs; IAM roles and users declare their complete policy lists, so additions show as drift | SOC lab phase |
| Detection of unmanaged resources | `terraform plan` only compares resources already in state; finding resources created outside Terraform needs AWS Config or CloudTrail analysis | Medium. A new IAM user, key or resource created by hand is not reported | Additions to managed IAM identities are caught; admin access is limited to the owner | SOC lab phase |
| Access Analyzer policy validation on pull requests | `ValidatePolicy` needs AWS credentials, and PR runs deliberately have none: OIDC is blocked and the drift key is restricted to the `drift` environment on protected branches | Low. A malformed or overly broad policy can merge before Access Analyzer sees it | Checkov IAM checks on every PR (privilege escalation, unconstrained write, wildcard resources: CKV_AWS_286 to 290, CKV_AWS_355, CKV_AWS_62, CKV_AWS_63); `policy-check.sh` run locally before each PR; Access Analyzer daily in CI after merge | OIDC becomes available, so PR runs can get short-lived read-only credentials |

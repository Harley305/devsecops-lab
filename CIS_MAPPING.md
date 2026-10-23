# CIS AWS Foundations Benchmark Mapping

This maps the devsecops-lab against the **CIS AWS Foundations Benchmark v5.0.0**, the version AWS Security Hub currently uses. Requirement numbers come from the AWS Security Hub control mapping. CIS has since published v6.0.0, so numbering may shift in a later update.

The lab is deployed to an AWS account created with the new simplified AWS experience. A Builder ID owns the account (there is no root user), and AWS-managed organization policies (SCPs) that the account cannot change block some controls. Those rows are marked 🚫.

Every requirement has one of these statuses:

| Status | Meaning |
| --- | --- |
| ✅ Implemented | Enforced in Terraform and scanned by CI |
| 🔧 Gap: free fix | Not yet implemented; can be added in Terraform at no cost |
| 💲 Gap: cost | Not implemented because the service bills; accepted for a $0 lab |
| 📝 Manual | Account-level setting outside Terraform; checked by hand |
| ⚠️ Verify | Depends on code details; confirm and update this row |
| ➖ N/A | Resource type not used in this lab |
| 🚫 Blocked | Prevented by an organization policy this account cannot change |

## Section 1: Identity and Access Management

| CIS | Requirement | Security Hub | Status | How it's met / plan |
| --- | --- | --- | --- | --- |
| 1.2 | Security contact information provided | Account.1 | 🚫 | The account's SCP denies `account:PutAlternateContact`. Contact details are managed by AWS Settings for this account type |
| 1.3 | No root user access keys | IAM.4 | ➖ | No root user exists; a Builder ID owns the account |
| 1.4 | MFA enabled for root user | IAM.9 | ✅ | No root user; MFA is registered on the owning Builder ID (checked 2026-10-16) |
| 1.5 | Hardware MFA for root user (Level 2) | IAM.6 | ➖ | No root user exists |
| 1.7 | Password policy: minimum length 14 | IAM.15 | ✅ | `aws_iam_account_password_policy` in `account-baseline`: 14+ characters, all character classes, 90-day expiry |
| 1.8 | Password policy: prevent reuse | IAM.16 | ✅ | Same resource as 1.7 (`password_reuse_prevention = 24`) |
| 1.9 | MFA for IAM users with console passwords | IAM.5 | ➖ | The account's SCP denies `iam:*LoginProfile*`, so IAM users cannot have console passwords |
| 1.11 | Remove credentials unused for 45 days | IAM.22 | ✅ | Deploys use short-lived `aws login` sessions; workloads use roles. The one access key (`drift-check-ci`) is used daily by the scheduled drift check |
| 1.13 | Rotate access keys every 90 days | IAM.3 | ✅ | One access key, for scheduled drift detection (OIDC is blocked by SCP). Created 2026-10-23, rotation due 2027-01-21; runbook in [EXCEPTIONS.md](EXCEPTIONS.md#drift-ci-long-lived-iam-access-key-for-scheduled-drift-detection) |
| 1.14 | No policies attached directly to IAM users | IAM.2 | ✅ | All permissions are on roles (`app`, `github-oidc`, `account-baseline`, `drift-readonly`). The only IAM user, `drift-check-ci`, has no policies; it can only assume `drift-readonly` |
| 1.16 | Support role exists for incident management | IAM.18 | ✅ | `devsecops-lab-support` role with `AWSSupportAccess`, trusted only by this account |
| 1.18 | Remove expired IAM SSL/TLS certificates | IAM.26 | ➖ | No IAM server certificates |
| 1.19 | IAM Access Analyzer enabled | IAM.28 | 🚫 | The Free plan SCP allows only Access Analyzer policy checks, not creating an analyzer |
| 1.21 | No `AWSCloudShellFullAccess` attachments | IAM.27 | ✅ | Not attached to any role in this code |

## Section 2: Storage

| CIS | Requirement | Security Hub | Status | How it's met / plan |
| --- | --- | --- | --- | --- |
| 2.1.1 | S3 buckets require TLS | S3.5 | ✅ | Both buckets (state and `storage`) have a bucket policy denying any request where `aws:SecureTransport` is false |
| 2.1.2 | S3 MFA delete enabled | S3.20 | 🚫 | MFA delete can only be enabled with root user credentials, and this account has no root user. Compensated by versioning and `prevent_destroy` |
| 2.1.4 | S3 Block Public Access enabled | S3.1, S3.8 | ✅ | Bucket level (S3.8): all four settings on for every bucket. Account level (S3.1): `aws_s3_account_public_access_block` in `account-baseline` |
| 2.2.x | RDS controls | RDS.2, .3, .5, .13, .15 | ➖ | No RDS |
| 2.3.1 | EFS encrypted at rest | EFS.1, EFS.8 | ➖ | No EFS |

## Section 3: Logging

| CIS | Requirement | Security Hub | Status | How it's met / plan |
| --- | --- | --- | --- | --- |
| 3.1 | Multi-Region CloudTrail with read and write management events | CloudTrail.1 | 💲 | Deferred. CloudTrail Event History (90 days, free) covers management events. Trail planned for the SOC lab phase |
| 3.2 | CloudTrail log file validation | CloudTrail.4 | ➖ | Applies once a trail exists |
| 3.3 | AWS Config enabled | Config.1 | 💲 | Billed per configuration item; drift detection via `drift-check.sh` (`terraform plan -detailed-exitcode`) instead |
| 3.4 | Access logging on the CloudTrail bucket | CloudTrail.7 | ➖ | Applies once a trail exists |
| 3.5 | CloudTrail encrypted with KMS | CloudTrail.2 | ➖ | Applies once a trail exists. Customer-managed keys bill monthly |
| 3.6 | KMS key rotation enabled | KMS.4 | ➖ | No customer-managed KMS keys; all encryption uses AWS-managed keys |
| 3.7 | VPC flow logs enabled | EC2.6 | 💲 | Billed on ingestion; deferred. Private subnets have no internet route, which limits exposure |

## Section 4: Monitoring

CIS v5.0.0 lists metric filters and alarms (root usage, IAM policy changes, CloudTrail changes and others) as manual checks. They depend on CloudTrail and are planned for the SOC lab phase.

## Section 5: Networking

| CIS | Requirement | Security Hub | Status | How it's met / plan |
| --- | --- | --- | --- | --- |
| 5.1.1 | EBS default encryption enabled | EC2.7 | ✅ | `aws_ebs_encryption_by_default` in `account-baseline` (us-east-2). No EBS volumes exist yet |
| 5.2 | NACLs: no ingress from 0.0.0.0/0 to ports 22 or 3389 | EC2.21 | ✅ | `aws_default_network_acl` (used by all four subnets) denies TCP 22 and 3389 from 0.0.0.0/0 in rules 10 and 20, ahead of the allow rule. The VPC has no IPv6 |
| 5.3 | Security groups: no 0.0.0.0/0 to admin ports | EC2.53 | ✅ | No security groups open 22 or 3389 |
| 5.4 | Security groups: no ::/0 to admin ports | EC2.54 | ✅ | Same as 5.3 |
| 5.5 | Default security group restricts all traffic | EC2.2 | ✅ | Default security group locked with no inbound or outbound rules |
| 5.7 | EC2 uses IMDSv2 | EC2.8 | ➖ | No EC2 instances |

## Summary

| Status | Count |
| --- | --- |
| ✅ Implemented | 15 |
| 🔧 Gap: free fix | 0 |
| 💲 Gap: cost (accepted) | 3 |
| 📝 Manual | 0 |
| ⚠️ Verify | 0 |
| ➖ N/A | 11 |
| 🚫 Blocked | 3 |

## Free-fix backlog: closed

All six free fixes were added in one pull request (2026-10-23): password policy (1.7, 1.8), account-level S3 Block Public Access (2.1.4), EBS default encryption (5.1.1), support role (1.16), default NACL denying 22 and 3389 (5.2), and a TLS-only policy on the `storage` bucket (2.1.1). The account-wide settings live in `infra/modules/account-baseline` and are covered by the scheduled drift check.

Removed because the account blocks them: security contact (CIS 1.2) and IAM Access Analyzer (CIS 1.19). Access Analyzer policy checks are planned as a compensating control for 1.19.

## References

- [AWS Security Hub: CIS AWS Foundations Benchmark control mapping](https://docs.aws.amazon.com/securityhub/latest/userguide/cis-aws-foundations-benchmark.html)
- [EXCEPTIONS.md](EXCEPTIONS.md): accepted Checkov findings and compensating controls
- [AWS: Managed policies for your organization (new AWS experience)](https://docs.aws.amazon.com/accounts/latest/reference/scps-and-rcps-for-projects.html): the SCPs behind the 🚫 rows
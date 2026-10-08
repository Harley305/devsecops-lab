# CIS AWS Foundations Benchmark Mapping

This maps the devsecops-lab against the **CIS AWS Foundations Benchmark v5.0.0**, the version AWS Security Hub currently uses. Requirement numbers come from the AWS Security Hub control mapping. CIS has since published v6.0.0, so numbering may shift in a later update.

Every requirement has one of these statuses:

| Status | Meaning |
| --- | --- |
| ✅ Implemented | Enforced in Terraform and scanned by CI |
| 🔧 Gap: free fix | Not yet implemented; can be added in Terraform at no cost |
| 💲 Gap: cost | Not implemented because the service bills; accepted for a $0 lab |
| 📝 Manual | Account-level setting outside Terraform; checked by hand |
| ⚠️ Verify | Depends on code details; confirm and update this row |
| ➖ N/A | Resource type not used in this lab |

## Section 1: Identity and Access Management

| CIS | Requirement | Security Hub | Status | How it's met / plan |
| --- | --- | --- | --- | --- |
| 1.2 | Security contact information provided | Account.1 | 🔧 | Add `aws_account_alternate_contact` with type `SECURITY` |
| 1.3 | No root user access keys | IAM.4 | 📝 | Confirm none exist in the console; record the check date |
| 1.4 | MFA enabled for root user | IAM.9 | 📝 | Confirm in the console |
| 1.5 | Hardware MFA for root user (Level 2) | IAM.6 | 📝 | Accepted exception: virtual MFA used in a personal lab |
| 1.7 | Password policy: minimum length 14 | IAM.15 | 🔧 | Add `aws_iam_account_password_policy` |
| 1.8 | Password policy: prevent reuse | IAM.16 | 🔧 | Same resource as 1.7 (`password_reuse_prevention = 24`) |
| 1.9 | MFA for IAM users with console passwords | IAM.5 | 📝 | Confirm for any console users |
| 1.11 | Remove credentials unused for 45 days | IAM.22 | ✅ | No long-lived credentials: CI uses OIDC short-lived tokens; workloads use roles |
| 1.13 | Rotate access keys every 90 days | IAM.3 | ✅ | No access keys in use; OIDC replaces stored keys |
| 1.14 | No policies attached directly to IAM users | IAM.2 | ✅ | All permissions are on roles (`app`, `github-oidc` modules) |
| 1.16 | Support role exists for incident management | IAM.18 | 🔧 | Add a role with `AWSSupportAccess`, assumable only by this account |
| 1.18 | Remove expired IAM SSL/TLS certificates | IAM.26 | ➖ | No IAM server certificates |
| 1.19 | IAM Access Analyzer enabled | IAM.28 | 🔧 | Add `aws_accessanalyzer_analyzer` (type `ACCOUNT`; external access analyzer is free) |
| 1.21 | No `AWSCloudShellFullAccess` attachments | IAM.27 | ✅ | Not attached to any role in this code |

## Section 2: Storage

| CIS | Requirement | Security Hub | Status | How it's met / plan |
| --- | --- | --- | --- | --- |
| 2.1.1 | S3 buckets require TLS | S3.5 | 🔧 | State bucket denies non-TLS requests. The `storage` bucket has no TLS-only bucket policy yet; add one |
| 2.1.2 | S3 MFA delete enabled | S3.20 | 📝 | Accepted exception: MFA delete can only be enabled by the root user with MFA through the CLI, not Terraform. Compensated by versioning and `prevent_destroy` |
| 2.1.4 | S3 Block Public Access enabled | S3.1, S3.8 | ✅ / 🔧 | Bucket level: all four settings on for every bucket. Account level (S3.1): add `aws_s3_account_public_access_block` |
| 2.2.x | RDS controls | RDS.2, .3, .5, .13, .15 | ➖ | No RDS |
| 2.3.1 | EFS encrypted at rest | EFS.1, EFS.8 | ➖ | No EFS |

## Section 3: Logging

| CIS | Requirement | Security Hub | Status | How it's met / plan |
| --- | --- | --- | --- | --- |
| 3.1 | Multi-Region CloudTrail with read and write management events | CloudTrail.1 | 💲 | Deferred. CloudTrail Event History (90 days, free) covers management events. Trail planned for the SOC lab phase |
| 3.2 | CloudTrail log file validation | CloudTrail.4 | ➖ | Applies once a trail exists |
| 3.3 | AWS Config enabled | Config.1 | 💲 | Billed per configuration item; drift detection via scheduled `terraform plan` instead |
| 3.4 | Access logging on the CloudTrail bucket | CloudTrail.7 | ➖ | Applies once a trail exists |
| 3.5 | CloudTrail encrypted with KMS | CloudTrail.2 | ➖ | Applies once a trail exists. Customer-managed keys bill monthly |
| 3.6 | KMS key rotation enabled | KMS.4 | ➖ | No customer-managed KMS keys; all encryption uses AWS-managed keys |
| 3.7 | VPC flow logs enabled | EC2.6 | 💲 | Billed on ingestion; deferred. Private subnets have no internet route, which limits exposure |

## Section 4: Monitoring

CIS v5.0.0 lists metric filters and alarms (root usage, IAM policy changes, CloudTrail changes and others) as manual checks. They depend on CloudTrail and are planned for the SOC lab phase.

## Section 5: Networking

| CIS | Requirement | Security Hub | Status | How it's met / plan |
| --- | --- | --- | --- | --- |
| 5.1.1 | EBS default encryption enabled | EC2.7 | 🔧 | No EBS volumes, but `aws_ebs_encryption_by_default` is free and closes this account-wide |
| 5.2 | NACLs: no ingress from 0.0.0.0/0 to ports 22 or 3389 | EC2.21 | 🔧 | No `aws_default_network_acl` in the network module, so the default NACL allows all inbound traffic. Manage it and deny 22 and 3389 from 0.0.0.0/0 |
| 5.3 | Security groups: no 0.0.0.0/0 to admin ports | EC2.53 | ✅ | No security groups open 22 or 3389 |
| 5.4 | Security groups: no ::/0 to admin ports | EC2.54 | ✅ | Same as 5.3 |
| 5.5 | Default security group restricts all traffic | EC2.2 | ✅ | Default security group locked with no inbound or outbound rules |
| 5.7 | EC2 uses IMDSv2 | EC2.8 | ➖ | No EC2 instances |

## Summary

| Status | Count |
| --- | --- |
| ✅ Implemented | 8 |
| 🔧 Gap: free fix | 8 |
| 💲 Gap: cost (accepted) | 3 |
| 📝 Manual | 5 |
| ⚠️ Verify | 0 |
| ➖ N/A | 8 |

Row 2.1.4 is counted once, under ✅. Its account-level fix is also listed in the backlog below.

## Free-fix backlog

Each item below closes a gap at $0 and goes through the normal pull request and CI scan:

1. `aws_iam_account_password_policy`: CIS 1.7, 1.8
2. `aws_accessanalyzer_analyzer`: CIS 1.19
3. `aws_s3_account_public_access_block`: CIS 2.1.4 (account level)
4. `aws_ebs_encryption_by_default`: CIS 5.1.1
5. `aws_account_alternate_contact` (SECURITY): CIS 1.2
6. Support role with `AWSSupportAccess`: CIS 1.16
7. `aws_default_network_acl` denying 22 and 3389: CIS 5.2
8. TLS-only bucket policy on the `storage` bucket: CIS 2.1.1

## References

- [AWS Security Hub: CIS AWS Foundations Benchmark control mapping](https://docs.aws.amazon.com/securityhub/latest/userguide/cis-aws-foundations-benchmark.html)
- [EXCEPTIONS.md](EXCEPTIONS.md): accepted Checkov findings and compensating controls
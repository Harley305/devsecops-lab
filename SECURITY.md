# Security Policy

## Scope

This repository is a personal DevSecOps lab: Terraform-managed AWS
infrastructure and GitHub Actions security pipelines. In scope:

- Terraform code and module configuration
- GitHub Actions workflows (scanning, drift detection)
- IAM policies, trust policies, and S3 bucket policies defined here
- Secrets or sensitive identifiers accidentally committed to the repo

Out of scope:

- Vulnerabilities in AWS services, GitHub, Terraform, or third-party
  tools themselves (report those to the vendor)
- Findings already documented as accepted risk in
  [EXCEPTIONS.md](EXCEPTIONS.md)

## Supported Versions

Only the `main` branch is maintained.

## Reporting a Vulnerability

**Do not open a public issue.** Use GitHub's private reporting:
**Security tab → Report a vulnerability** on this repository.

Please include:

- Affected file(s) and line numbers
- Description of the issue and its potential impact
- Steps to reproduce, if applicable

## Response

This is a solo-maintained project. Target timelines:

- Acknowledgment: within 7 days
- Triage and severity assessment: within 14 days
- Fix or documented exception: based on severity

There is no bug bounty.

# Adversarial Review

This repo is periodically reviewed by an outside model or person using the prompt below. The rules keep the review focused on gaps that aren't already documented, and require every claim to be checked against the code.

## Review prompt

```text
Audit the current main branch of https://github.com/Harley305/devsecops-lab
Read EXCEPTIONS.md, README.md, SECURITY.md, skip-check.sh, drift-check.sh,
policy-check.sh, .github/workflows/ci.yml, .github/workflows/drift-check.yml,
bootstrap/ and infra/ before answering.

Assume an attacker holds one of these and wants to stay undetected:
1. The drift-check-ci access key
2. A GitHub account with write access to the repo
3. AWS admin credentials

For each, describe what they could do and which control in this repo would
catch it, or say plainly that nothing would.

Then answer:
- What would make the drift check silently stop working?
- Which claims in README.md or EXCEPTIONS.md are not enforced by the code?

Rules:
- Only report gaps NOT already listed in EXCEPTIONS.md
- Every finding must cite the file and line, the exact attack step, and why
  existing controls miss it
- Don't recommend controls that need paid AWS services or don't apply to a
  single-account, single-maintainer lab
- Verify claims against the code. Don't assume a control works the way its
  name suggests
- If you find nothing new, say so instead of padding
```

## Review log

Findings are verified against the code before any change is made. Accepted risks go to [EXCEPTIONS.md](EXCEPTIONS.md).

| Date | Verified findings | Outcome |
| --- | --- | --- |
| 2026-10-23 | Out-of-band IAM policies invisible to drift; bootstrap not drift-checked; drift schedule could lapse after 60 days; Checkov skips not validated against the register; Gitleaks not a required check | Fixed in #22, #24, #28, #30 and branch protection; detection limits and PR-time Access Analyzer recorded in EXCEPTIONS.md |

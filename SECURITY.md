# Security Policy

## Supported Branch

Security fixes should target `main`.

## Reporting a Vulnerability

Please do not open a public issue for a suspected vulnerability. Use GitHub private vulnerability reporting if it is enabled for this repository, or contact the repository owner directly.

Include:

- A short description of the issue.
- Steps to reproduce or a proof of concept.
- The affected platform or workflow.
- Any relevant logs or screenshots with secrets removed.

## Secrets and Credentials

Never commit private keys, service account JSON, keystores, signing certificates, `.env` files, or reusable test credentials. Firebase client configuration can be committed because it is required by the app, but privileged credentials must stay outside version control.

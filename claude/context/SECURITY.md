# Security

- Never commit secrets: `.env`, API keys, tokens, passwords, private keys. Warn if asked.
- Don't echo secrets in output or logs.
- Sensitive patterns: `.env*`, `credentials.json`, `*.pem`, `*.key`, `id_rsa*`. Don't read unless explicitly asked with clear context.
- `git status` shows sensitive file → warn before adding.
- Never modify or display private key material.

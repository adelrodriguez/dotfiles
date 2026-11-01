# Environment for agents and the services that start them.
# scripts/agents-env.sh fills this template from 1Password into ~/.config/agents/env.
# Write one KEY=value per line. Values may use only letters, digits, and _ . / : @ + , = % -
# so that systemd, zsh, and fish read every line the same way.

# upload skill: a public R2 bucket and a token scoped to that bucket.
FILE_UPLOAD_ACCESS_KEY_ID=op://Agents/FILE_UPLOAD/access_key_id
FILE_UPLOAD_SECRET_ACCESS_KEY=op://Agents/FILE_UPLOAD/secret_access_key
FILE_UPLOAD_ACCOUNT_ID=op://Agents/FILE_UPLOAD/account_id
FILE_UPLOAD_BUCKET=op://Agents/FILE_UPLOAD/bucket
FILE_UPLOAD_PUBLIC_URL=op://Agents/FILE_UPLOAD/public_url

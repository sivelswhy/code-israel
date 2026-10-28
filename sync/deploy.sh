#!/usr/bin/env bash
# Puts the free sync server online (Cloudflare Workers, free plan) and tells the web app and the iPhone/Mac app where it is.
# You need a free Cloudflare account: `npx wrangler login` opens the browser once.
set -euo pipefail
cd "$(dirname "$0")"

npx --yes wrangler login

if grep -q REPLACE_WITH_NAMESPACE_ID wrangler.toml; then
  id=$(npx --yes wrangler kv namespace create PROGRESS 2>&1 | grep -oE '[0-9a-f]{32}' | head -1)
  [ -n "$id" ] || { echo "Could not read the namespace id: create it with 'npx wrangler kv namespace create PROGRESS' and paste it in wrangler.toml." >&2; exit 1; }
  sed -i.bak "s/REPLACE_WITH_NAMESPACE_ID/$id/" wrangler.toml && rm -f wrangler.toml.bak
fi

url=$(npx --yes wrangler deploy 2>&1 | tee /dev/stderr | grep -oE 'https://[a-zA-Z0-9.-]+\.workers\.dev' | head -1)
[ -n "$url" ] || { echo "Could not read the address of the server from the output above." >&2; exit 1; }

# The function that mails the code (Vercel project "code-israel-mail") is already online.
printf '{ "url": "%s", "mail": "https://code-israel-mail.vercel.app/api/send-code" }\n' "$url" > ../public/sync.json
cp ../public/sync.json ../ios/App/Resources/Data/sync.json
echo
echo "Server online: $url"
echo "Written to public/sync.json and ios/App/Resources/Data/sync.json: commit and push them, the apps pick it up."
echo "Last step: in Vercel (project code-israel-mail), set SYNC_URL to $url and redeploy."

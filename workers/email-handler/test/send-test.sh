#!/usr/bin/env bash
# Send test .eml fixtures to the local wrangler dev server.
# Usage: bash test/send-test.sh

set -euo pipefail

BASE_URL="${1:-http://localhost:8787}"
FIXTURE_DIR="$(dirname "$0")/fixtures"

for eml in "$FIXTURE_DIR"/*.eml; do
  name="$(basename "$eml")"
  echo "--- Sending $name ---"
  # Extract From/To from the .eml file
  from=$(grep -m1 '^From:' "$eml" | sed -E 's/.*<(.+)>/\1/' | tr -d ' ')
  to=$(grep -m1 '^To:' "$eml" | sed -E 's/.*<(.+)>/\1/' | tr -d ' ')
  curl -s -X POST "$BASE_URL/cdn-cgi/handler/email?from=${from}&to=${to}" \
    -H "Content-Type: message/rfc822" \
    --data-binary "@$eml" \
    -w "\nHTTP %{http_code}\n"
  echo
done

echo "Done."

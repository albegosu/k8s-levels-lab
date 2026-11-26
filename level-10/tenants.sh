#!/usr/bin/env bash
# Creates two tenants in the gateway, each a team with one virtual key:
#   team-a: no budget, 60 requests per minute
#   team-b: a tiny budget (0.02, about one request) and 2 requests per minute, to see limits bite
# The keys are stored in the Secret inference/tenant-keys (keys team-a and team-b).
set -euo pipefail
cd "$(dirname "$0")"; source lib.sh
if kn get secret tenant-keys >/dev/null 2>&1; then
  echo "Tenants already exist. Keys: kubectl get secret tenant-keys -n inference -o jsonpath='{.data.team-a}' | base64 -d"
  exit 0
fi
MK=$(master_key)
new_key() { # <team alias> <max budget or null> <rpm>
  local team key
  team=$(echo "{\"team_alias\": \"$1\", \"max_budget\": $2}" | gw POST /team/new "$MK" | tail -n +2 |
         python3 -c 'import sys, json; print(json.load(sys.stdin)["team_id"])')
  key=$(echo "{\"team_id\": \"$team\", \"key_alias\": \"$1-key\", \"rpm_limit\": $3, \"models\": [\"chat\"]}" |
        gw POST /key/generate "$MK" | tail -n +2 | python3 -c 'import sys, json; print(json.load(sys.stdin)["key"])')
  echo "$key"
}
A=$(new_key team-a null 60)
B=$(new_key team-b 0.02 2)
kn create secret generic tenant-keys --from-literal=team-a="$A" --from-literal=team-b="$B" >/dev/null
echo "Created team-a and team-b. Their keys are in the Secret inference/tenant-keys."

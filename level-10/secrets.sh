#!/usr/bin/env bash
# Creates the level 10 credentials as Secrets with random values, so none is written in Git:
#   inference/postgres  password            the database password
#   inference/litellm   LITELLM_MASTER_KEY  the gateway admin key (sk-…)
# Run it once, before applying postgres.yaml and litellm.yaml. It never overwrites existing Secrets:
# the database keeps the password it was created with.
set -euo pipefail
cd "$(dirname "$0")"; source lib.sh
kubectl --context "$CTX" create ns "$NS" --dry-run=client -o yaml | kubectl --context "$CTX" apply -f - >/dev/null
rand() { python3 -c 'import secrets; print(secrets.token_urlsafe(24))'; }
if kn get secret postgres >/dev/null 2>&1; then echo "Secret postgres exists, kept."
else kn create secret generic postgres --from-literal=password="$(rand)" >/dev/null; echo "Created Secret postgres."; fi
if kn get secret litellm >/dev/null 2>&1; then echo "Secret litellm exists, kept."
else kn create secret generic litellm --from-literal=LITELLM_MASTER_KEY="sk-$(rand)" >/dev/null; echo "Created Secret litellm."; fi

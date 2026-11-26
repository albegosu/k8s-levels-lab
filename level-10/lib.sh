# Helpers for level 10 scripts. Sourced, not run.
# Calls to the gateway run inside the LiteLLM pod (python is there), so no port-forward is needed.
CTX=${CTX:-kind-lab}
NS=inference
kn() { kubectl --context "$CTX" -n "$NS" "$@"; }

# A LiteLLM pod that is Ready and not being deleted. After a restart, `exec deploy/litellm`
# can pick the old pod while it terminates, and the call hangs.
gw_pod() {
  kn get pods -l app=litellm -o json | python3 -c '
import sys, json
for p in json.load(sys.stdin)["items"]:
    ready = any(c["type"] == "Ready" and c["status"] == "True" for c in p["status"].get("conditions", []))
    if ready and not p["metadata"].get("deletionTimestamp"):
        print(p["metadata"]["name"]); break'
}

# gw <METHOD> <path> <key> [json body on stdin]: prints the HTTP status, then the body.
# GET requests send no body, so they never wait on stdin.
gw() {
  local in=/dev/stdin; [[ $1 == GET ]] && in=/dev/null
  kn exec -i "$(gw_pod)" -c litellm -- python -c '
import sys, urllib.request as u
m, p, k = sys.argv[1:4]
d = sys.stdin.read().encode() or None
r = u.Request("http://localhost:4000" + p, data=d, method=m,
              headers={"Authorization": "Bearer " + k, "Content-Type": "application/json"})
try:
    x = u.urlopen(r, timeout=120); print(x.status); print(x.read().decode())
except u.HTTPError as e:
    print(e.code); print(e.read().decode())
' "$@" < "$in"
}

master_key() { kn get secret litellm -o jsonpath='{.data.LITELLM_MASTER_KEY}' | base64 -d; }
tenant_key() { kn get secret tenant-keys -o jsonpath="{.data.$1}" 2>/dev/null | base64 -d; }

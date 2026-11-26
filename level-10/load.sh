#!/usr/bin/env bash
# A tiny load generator, like `vllm bench serve` (inference note 21), run inside the cluster.
# Usage: ./level-10/load.sh <concurrency> [requests] [tenant] [max_tokens]
#   ./level-10/load.sh 1          # one at a time
#   ./level-10/load.sh 8 16       # 8 at once: more than the 4 slots of the model server
#   LONG=1 ./level-10/load.sh 2   # with a ~700-token prompt, like a RAG app pasting a document
set -euo pipefail
cd "$(dirname "$0")"; source lib.sh
C=${1:-4}; N=${2:-$((C * 2))}; TENANT=${3:-team-a}; MAXTOK=${4:-128}
KEY=$(tenant_key "$TENANT"); [[ -n $KEY ]] || { echo "No key for $TENANT: run ./level-10/tenants.sh first"; exit 1; }
echo "Sending $N requests, $C at a time, as $TENANT, up to $MAXTOK tokens each…"
POD=$(gw_pod); [[ -n $POD ]] || { echo "No Ready LiteLLM pod: kubectl get pods -n inference"; exit 1; }
kn exec -i "$POD" -c litellm -- python - "$C" "$N" "$KEY" "$MAXTOK" "${LONG:-0}" <<'PY'
import sys, json, time, threading, urllib.request as u
from collections import Counter
c, n, key, maxtok, long = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3], int(sys.argv[4]), sys.argv[5] == "1"
question = "Explain in detail how a Kubernetes Deployment rolls out a new version."
if long:
    question = ("Context document:\n" + "A Deployment manages ReplicaSets and rolls out new pods gradually. " * 60
                + "\nUsing the document above, " + question)
body = json.dumps({"model": "chat", "max_tokens": maxtok, "messages": [
    {"role": "user", "content": question}]}).encode()
results, lock, idx, seen = [], threading.Lock(), iter(range(n)), {}
def worker():
    for _ in idx:
        t0 = time.time(); status, toks = 0, 0
        try:
            r = u.urlopen(u.Request("http://localhost:4000/v1/chat/completions", data=body,
                headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"}), timeout=300)
            status = r.status; toks = json.load(r)["usage"]["completion_tokens"]
        except u.HTTPError as e:
            status = e.code
            with lock:
                if status not in seen: seen[status] = e.read().decode()[:300]
        except Exception:
            status = -1
        with lock: results.append((status, time.time() - t0, toks))
t0 = time.time()
threads = [threading.Thread(target=worker) for _ in range(c)]
[t.start() for t in threads]; [t.join() for t in threads]
wall = time.time() - t0
ok = sorted(d for s, d, _ in results if s == 200)
pct = lambda p: ok[min(len(ok) - 1, int(p * len(ok)))] if ok else float("nan")
print(f"status codes:   {dict(Counter(s for s, _, _ in results))}")
print(f"latency p50:    {pct(0.5):.1f} s    p95: {pct(0.95):.1f} s")
print(f"output tokens:  {sum(t for *_, t in results) / wall:.0f} tokens/s in total over {wall:.0f} s")
for code, msg in seen.items():
    print(f"first {code}:      {msg}")
PY

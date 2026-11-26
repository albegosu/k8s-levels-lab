#!/usr/bin/env bash
# Injects one fault into the level 10 stack, to diagnose blind (inference note 25).
#   ./level-10/break.sh          a random fault; you are not told which
#   ./level-10/break.sh <1-5>    a given fault
#   ./level-10/break.sh reveal   which fault is active
#   ./level-10/break.sh reset    undo every fault
# Do not read the cases below before diagnosing. Solutions: level-10/solutions.md.
set -euo pipefail
cd "$(dirname "$0")"; source lib.sh
STATE=../.fault-10

reset() {
  kubectl --context "$CTX" apply -f model.yaml -f postgres.yaml -f litellm.yaml >/dev/null
  kn get servicemonitor litellm >/dev/null 2>&1 && kubectl --context "$CTX" apply -f monitoring.yaml >/dev/null
  kn scale sts/postgres --replicas=1 >/dev/null
  kn rollout restart deploy/litellm >/dev/null
  kn rollout status sts/postgres --timeout=180s >/dev/null
  kn rollout status deploy/qwen --timeout=300s >/dev/null
  kn rollout status deploy/litellm --timeout=300s >/dev/null
  rm -f "$STATE"
  echo "Stack restored."
}

inject() {
  case "$1" in
    1) kn set resources deploy/qwen -c llama --requests=memory=100Mi --limits=memory=150Mi >/dev/null ;;
    2) kn get configmap litellm-config -o yaml | sed 's#http://qwen.inference:8080/v1#http://qwen.inference:8000/v1#' | kn apply -f - >/dev/null
       kn rollout restart deploy/litellm >/dev/null
       kn rollout status deploy/litellm --timeout=300s >/dev/null ;;
    3) kn patch deploy qwen --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/args/5","value":"1024"}]' >/dev/null ;;
    4) kn patch deploy qwen --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/args/7","value":"1"}]' >/dev/null ;;
    5) kn scale sts/postgres --replicas=0 >/dev/null ;;
    *) echo "Faults: 1-5"; exit 1 ;;
  esac
  echo "$1" > "$STATE"
}

case "${1:-random}" in
  reset) reset ;;
  reveal) [[ -f $STATE ]] && echo "Active fault: $(cat "$STATE") (see level-10/solutions.md)" || echo "No fault active." ;;
  random) [[ -f $STATE ]] && { echo "A fault is already active: ./level-10/break.sh reset first"; exit 1; }
          inject $(( RANDOM % 5 + 1 ))
          echo "A fault is in. Users will notice within a minute or two. Find it: inference note 25." ;;
  *) [[ -f $STATE ]] && { echo "A fault is already active: ./level-10/break.sh reset first"; exit 1; }
     inject "$1"; echo "Fault $1 is in." ;;
esac

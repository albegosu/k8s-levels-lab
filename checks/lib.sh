# Shared helpers for ./lab.sh check. Sourced by level-N/check.sh; not run on its own.
# Each task prints a pass or a fail with a hint. Messages follow LAB_LANG (en | es),
# which defaults to Spanish when LANG starts with "es".

CTX=${CTX:-kind-lab}
LAB_LANG=${LAB_LANG:-$([[ "${LANG:-}" == es* ]] && echo es || echo en)}
PASS=0
FAIL=0

if [[ -t 1 ]]; then G=$'\e[32m'; R=$'\e[31m'; D=$'\e[2m'; B=$'\e[1m'; N=$'\e[0m'; else G= R= D= B= N=; fi

k() { kubectl --context "$CTX" --request-timeout=10s "$@"; }

# t "English" "Español": pick the text for the current language.
t() { if [[ "$LAB_LANG" == es ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

# task <title en> <title es> <hint en> <hint es> <command...>
# The command must exit 0 when the task is done. Its output is hidden.
task() {
  local title hint
  title=$(t "$1" "$2"); hint=$(t "$3" "$4"); shift 4
  if "$@" >/dev/null 2>&1; then
    printf '  %s✔%s %s\n' "$G" "$N" "$title"; PASS=$((PASS + 1))
  else
    printf '  %s✘%s %s\n    %s%s%s\n' "$R" "$N" "$title" "$D" "$hint" "$N"; FAIL=$((FAIL + 1))
  fi
}

header() { printf '\n%s%s%s\n' "$B" "$(t "$1" "$2")" "$N"; }

# Record the result. A level counts as done only when every task passes.
finish() {
  local level=$1 total=$((PASS + FAIL)) file
  file="$(dirname "${BASH_SOURCE[0]}")/../.progress"
  echo
  if (( FAIL == 0 )); then
    printf '%s%s%s\n' "$G" "$(t "Level $level done: $PASS/$total tasks." "Nivel $level superado: $PASS/$total tareas.")" "$N"
    { grep -v "^$level " "$file" 2>/dev/null || true; echo "$level $(date +%F)"; } | sort -n > "$file.tmp" && mv "$file.tmp" "$file"
  else
    printf '%s\n' "$(t "$PASS/$total tasks done. Fix the ones marked ✘ and run the check again." "$PASS/$total tareas hechas. Arregla las marcadas con ✘ y vuelve a lanzar el check.")"
  fi
  (( FAIL == 0 ))
}

# --- predicates ----------------------------------------------------------

jp() { k get "$@" 2>/dev/null; }

exists() { k get "$@" >/dev/null 2>&1; }

# deploy_ready <ns> <name>: every desired replica is updated and available.
deploy_ready() {
  local want upd avail
  read -r want upd avail <<< "$(jp deploy "$2" -n "$1" -o jsonpath='{.spec.replicas} {.status.updatedReplicas} {.status.availableReplicas}')"
  [[ -n "$want" && "$want" -gt 0 && "$upd" == "$want" && "$avail" == "$want" ]]
}

sts_ready() {
  local want ready
  read -r want ready <<< "$(jp sts "$2" -n "$1" -o jsonpath='{.spec.replicas} {.status.readyReplicas}')"
  [[ -n "$want" && "$ready" == "$want" ]]
}

ds_ready() {
  local want ready upd
  read -r want ready upd <<< "$(jp ds "$2" -n "$1" -o jsonpath='{.status.desiredNumberScheduled} {.status.numberReady} {.status.updatedNumberScheduled}')"
  [[ -n "$want" && "$want" -gt 0 && "$ready" == "$want" && "$upd" == "$want" ]]
}

# condition <kind> <ns> <name> <type>: that status condition is True.
condition() {
  [[ "$(jp "$1" "$3" -n "$2" -o jsonpath="{.status.conditions[?(@.type=='$4')].status}")" == True ]]
}

pod_phase() { [[ "$(jp pod "$2" -n "$1" -o jsonpath='{.status.phase}')" == "$3" ]]; }

pvc_bound() { [[ "$(jp pvc "$2" -n "$1" -o jsonpath='{.status.phase}')" == Bound ]]; }

endpoints_ready() {
  # At least one ready address behind the Service.
  jp endpointslices -n "$1" -l "kubernetes.io/service-name=$2" -o jsonpath='{.items[*].endpoints[?(@.conditions.ready==true)].addresses[0]}' | grep -q .
}

image_tag_is() {
  [[ "$(jp deploy "$2" -n "$1" -o jsonpath='{.spec.template.spec.containers[0].image}')" == *":$3" ]]
}

can_i() { [[ "$(k auth can-i "$@" 2>/dev/null)" == yes ]]; }
cannot_i() { [[ "$(k auth can-i "$@" 2>/dev/null)" == no ]]; }

not() { ! "$@"; }

# prom_query <promql>: true when the query returns at least one series with value 1.
prom_query() {
  local q
  q=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1")
  k get --raw "/api/v1/namespaces/observability/services/http:kps-kube-prometheus-stack-prometheus:9090/proxy/api/v1/query?query=$q" | grep -q '"1"\]'
}

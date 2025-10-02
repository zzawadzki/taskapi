#!/usr/bin/env bash
set -euo pipefail

# Kubernetes diagnostic helper for the Task API running on k3d/k3s
# It checks cluster status, lists pods, tails logs, tests connectivity via
# pod and service port-forward, inspects ingress/traefik, and highlights
# warnings/errors. Designed to be safe to run multiple times.

# -------- Config (override with env vars or flags) --------
NAMESPACE=${NAMESPACE:-taskapi}
APP_LABEL=${APP_LABEL:-taskapi}
SERVICE_NAME=${SERVICE_NAME:-taskapi-service}
INGRESS_NAME=${INGRESS_NAME:-taskapi-ingress}
INGRESS_HOST=${INGRESS_HOST:-taskapi.local}
POD_LOCAL_PORT=${POD_LOCAL_PORT:-18080}
SVC_LOCAL_PORT=${SVC_LOCAL_PORT:-18081}
HEALTH_PATH=${HEALTH_PATH:-/actuator/health}
CURL_TIMEOUT=${CURL_TIMEOUT:-5}
K3D_CLUSTER=${K3D_CLUSTER:-}

# -------- Colors --------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ${NC} $*"; }
ok() { echo -e "${GREEN}✔${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
error() { echo -e "${RED}✘${NC} $*"; }
section() { echo -e "\n${BOLD}== $* ==${NC}"; }

cleanup_pids=()
cleanup() {
  set +e
  for pid in "${cleanup_pids[@]:-}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
}
trap cleanup EXIT INT TERM

usage() {
  cat <<EOF
Task API Kubernetes diagnostic script

Usage: $0 [--namespace NAMESPACE] [--app-label LABEL] [--service NAME] [--host HOST] [--cluster NAME]

Env overrides:
  NAMESPACE, APP_LABEL, SERVICE_NAME, INGRESS_NAME, INGRESS_HOST, POD_LOCAL_PORT, SVC_LOCAL_PORT, HEALTH_PATH, CURL_TIMEOUT, K3D_CLUSTER
EOF
}

while [[ ${1:-} ]]; do
  case "$1" in
    -n|--namespace) NAMESPACE="$2"; shift 2;;
    -l|--app-label) APP_LABEL="$2"; shift 2;;
    -s|--service) SERVICE_NAME="$2"; shift 2;;
    -h|--host) INGRESS_HOST="$2"; shift 2;;
    -c|--cluster) K3D_CLUSTER="$2"; shift 2;;
    --help) usage; exit 0;;
    *) warn "Unknown arg: $1"; usage; exit 1;;
  esac
done

# -------- Dependency checks --------
section "Dependency checks"
if ! command -v kubectl >/dev/null 2>&1; then
  error "kubectl not found in PATH"
  exit 1
fi
ok "kubectl found: $(kubectl version --client --short 2>/dev/null || echo 'client version OK')"

if command -v k3d >/dev/null 2>&1; then
  ok "k3d found: $(k3d version 2>/dev/null | head -n1)"
else
  warn "k3d not found. Continuing assuming a working kubeconfig/context."
fi

# -------- Cluster status --------
section "Cluster status"
context=$(kubectl config current-context 2>/dev/null || echo "<none>")
info "kubectl context: $context"

if command -v k3d >/dev/null 2>&1; then
  if [[ -n "$K3D_CLUSTER" ]]; then
    k3d_out=$(k3d cluster list "$K3D_CLUSTER" 2>/dev/null || true)
  else
    k3d_out=$(k3d cluster list 2>/dev/null || true)
  fi
  echo "$k3d_out" | sed 's/^/  /'
  if echo "$k3d_out" | grep -q "running"; then
    ok "k3d cluster is running"
  else
    warn "k3d cluster not reported as running."
  fi
fi

if kubectl cluster-info >/dev/null 2>&1; then
  ok "kubectl can reach the cluster"
else
  error "kubectl cannot reach the cluster"
  exit 1
fi

# Ensure namespace exists
if kubectl get ns "$NAMESPACE" >/dev/null 2>&1; then
  ok "Namespace '$NAMESPACE' exists"
else
  error "Namespace '$NAMESPACE' not found"
  exit 1
fi

# -------- List pods --------
section "Pods in namespace: $NAMESPACE"
kubectl get pods -n "$NAMESPACE" -o wide || true

# -------- Tail logs from app pods --------
section "Last 20 log lines from app pods (label app=$APP_LABEL)"
app_pods=( $(kubectl get pods -n "$NAMESPACE" -l app="$APP_LABEL" -o name 2>/dev/null || true) )
if [[ ${#app_pods[@]} -eq 0 ]]; then
  warn "No pods found with label app=$APP_LABEL in namespace $NAMESPACE"
else
  for p in "${app_pods[@]}"; do
    echo "--- $(basename "$p") ---"
    if ! kubectl logs -n "$NAMESPACE" "$p" --tail=20 2>/dev/null; then
      warn "Failed to get logs for $p"
    fi
  done
fi

# Helper to pick a running pod
pick_running_pod() {
  kubectl get pods -n "$NAMESPACE" -l app="$APP_LABEL" \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
}

# -------- Test direct pod connection (port-forward) --------
section "Test direct pod connection via port-forward to $POD_LOCAL_PORT -> 8080"
pod_name=$(pick_running_pod)
if [[ -z "$pod_name" ]]; then
  warn "No running pod found with label app=$APP_LABEL"
else
  kubectl -n "$NAMESPACE" port-forward "pod/$pod_name" "$POD_LOCAL_PORT:8080" >/dev/null 2>&1 &
  pf_pid=$!
  cleanup_pids+=("$pf_pid")
  # Give port-forward a moment to establish
  for i in {1..10}; do
    if curl -fsS --max-time 1 "http://127.0.0.1:$POD_LOCAL_PORT" >/dev/null 2>&1; then break; fi
    sleep 0.2
  done
  if curl -fsS --max-time "$CURL_TIMEOUT" "http://127.0.0.1:$POD_LOCAL_PORT$HEALTH_PATH" | sed 's/^/  /'; then
    ok "Direct pod health check succeeded"
  else
    error "Direct pod health check failed"
  fi
fi

# -------- Test service connection (port-forward svc) --------
section "Test service connection via port-forward to $SVC_LOCAL_PORT -> 80 (svc/$SERVICE_NAME)"
if kubectl get svc -n "$NAMESPACE" "$SERVICE_NAME" >/dev/null 2>&1; then
  kubectl -n "$NAMESPACE" port-forward svc/"$SERVICE_NAME" "$SVC_LOCAL_PORT:80" >/dev/null 2>&1 &
  pf_svc_pid=$!
  cleanup_pids+=("$pf_svc_pid")
  for i in {1..10}; do
    if curl -fsS --max-time 1 "http://127.0.0.1:$SVC_LOCAL_PORT" >/dev/null 2>&1; then break; fi
    sleep 0.2
  done
  if curl -fsS --max-time "$CURL_TIMEOUT" "http://127.0.0.1:$SVC_LOCAL_PORT$HEALTH_PATH" | sed 's/^/  /'; then
    ok "Service health check succeeded"
  else
    error "Service health check failed"
  fi
else
  warn "Service '$SERVICE_NAME' not found in namespace '$NAMESPACE'"
fi

# -------- Ingress configuration --------
section "Ingress configuration: $INGRESS_NAME"
kubectl get ingress -n "$NAMESPACE" 2>/dev/null || true
if kubectl get ingress -n "$NAMESPACE" "$INGRESS_NAME" >/dev/null 2>&1; then
  echo
  kubectl describe ingress -n "$NAMESPACE" "$INGRESS_NAME" || true
else
  warn "Ingress '$INGRESS_NAME' not found in namespace '$NAMESPACE'"
fi

# -------- Traefik availability --------
section "Traefik availability"
if kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik >/dev/null 2>&1; then
  kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik -o wide || true
  # Try to access via ingress on localhost using Host header (k3d maps LB:80)
  info "Testing ingress route via traefik: curl http://localhost$HEALTH_PATH with Host: $INGRESS_HOST"
  if curl -fsS --max-time "$CURL_TIMEOUT" -H "Host: $INGRESS_HOST" "http://127.0.0.1$HEALTH_PATH" | sed 's/^/  /'; then
    ok "Ingress/Traefik route appears reachable on localhost"
  else
    warn "Failed to reach ingress route on localhost. Your k3d LB may not expose port 80 on localhost."
  fi
else
  warn "Traefik pods not found in kube-system"
fi

# -------- Events (warnings/errors) --------
section "Recent Warning/Error events across all namespaces"
if kubectl get events --all-namespaces >/dev/null 2>&1; then
  # Show last 50 Warning events
  kubectl get events --all-namespaces --field-selector type=Warning --sort-by=.lastTimestamp \
    | tail -n 50 \
    | sed -E "s/^/${RED}/; s/$/${NC}/" || true
  # Additionally, show last 20 generic events for the target namespace
  echo
  info "Last 20 events in namespace '$NAMESPACE'"
  kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 20 || true
else
  warn "Unable to retrieve events"
fi

section "Summary"
ok "Diagnostics completed for namespace '$NAMESPACE' (context: $context)"

exit 0

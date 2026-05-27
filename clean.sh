#!/bin/bash

ARGOCD_NS="openshift-gitops"

# ArgoCD Applications to keep (noobaa manages ODF/storage, deleting it can break the cluster)
KEEP_APPS="noobaa|keycloak"

echo "=== Cleaning rhdh-gitops ArgoCD instance ==="
oc get application -n rhdh-gitops -o name 2>/dev/null \
  | xargs -r oc delete -n rhdh-gitops --ignore-not-found || true
oc get appproject -n rhdh-gitops -o name 2>/dev/null \
  | grep -v default \
  | xargs -r oc delete -n rhdh-gitops --ignore-not-found || true

echo ""
echo "=== Cleaning ArgoCD Applications in ${ARGOCD_NS} (keeping: ${KEEP_APPS}) ==="
oc get application -n "${ARGOCD_NS}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null \
  | tr ' ' '\n' \
  | grep -v -E "^(${KEEP_APPS// /|})$" \
  | xargs -r oc delete application -n "${ARGOCD_NS}" --ignore-not-found || true

echo ""
echo "=== Cleaning namespaces ==="
NAMESPACES=(
  gitlab
  vault
  rhdh-gitops
  rhdh
  openshift-devspaces
  trusted-artifact-signer
  showroom
  openshift-pipelines
  quay-registry
  external-secrets
)

for ns in "${NAMESPACES[@]}"; do
  if oc get project "${ns}" &>/dev/null; then
    echo "  Deleting namespace: ${ns}"
    oc delete project "${ns}" --ignore-not-found &
  fi
done

echo ""
echo "=== Waiting for namespace deletions to complete ==="
wait || true

echo ""
echo "=== Cleaning Dev Spaces user workspaces ==="
oc get project -o jsonpath='{.items[*].metadata.name}' 2>/dev/null \
  | tr ' ' '\n' \
  | grep 'devspaces-' \
  | grep -v openshift-devspaces \
  | xargs -r oc delete project --ignore-not-found || true

echo ""
echo "=== Cleaning ArgoCD repo credentials for GitLab ==="
oc delete secret argocd-repo-gitlab-helm -n "${ARGOCD_NS}" --ignore-not-found 2>/dev/null || true

echo ""
echo "=== Cleaning Showroom ClusterRoleBinding ==="
oc delete clusterrolebinding showroom-showroom-cluster-admin --ignore-not-found 2>/dev/null || true

echo ""
echo "Done."

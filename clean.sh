#!/bin/bash

echo "Cleaning rhdh-gitops ArgoCD instance"
oc get Application  -n rhdh-gitops -o yaml 2>/dev/null | yq '.items.[].metadata.name' | xargs -r oc -n rhdh-gitops delete Application
oc get AppProject   -n rhdh-gitops -o yaml 2>/dev/null | yq '.items.[].metadata.name' | xargs -r oc -n rhdh-gitops delete AppProject

echo

echo "Cleaning ArgoCD applications (openshift-gitops)"
oc get Applications -n openshift-gitops \
  | grep -e gitlab -e noobaa -e vault -e rhdh-gitops \
  | awk '{print $1}' \
  | xargs -r oc -n openshift-gitops delete Applications

echo

echo "Cleaning namespaces"
oc get project \
  | grep -e gitlab -e openshift-storage -e vault -e rhdh-gitops \
  | awk '{print $1}' \
  | xargs -r oc delete project

echo

echo "Cleaning Dev Spaces workspaces"
oc get project -o json 2>/dev/null \
  | jq -r '.items.[].metadata.name' \
  | grep devspaces \
  | grep -v openshift-devspaces \
  | while read ns; do
      oc delete project "$ns"
    done

echo

echo "Cleaning GitLab OAuth secret"
oc get secret gitlab-oauth-config -n openshift-devspaces >/dev/null 2>&1 \
  && oc delete secret gitlab-oauth-config -n openshift-devspaces

echo

# echo "Cleaning lab users"
# oc get users -o json 2>/dev/null \
#   | jq -r '.items.[].metadata.name' \
#   | grep -v admin \
#   | while read user; do
#       oc delete user "$user"
#     done

echo "Done."

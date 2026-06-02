# Permissions du ClusterRole IDP Lab

Le ClusterRole créé pour le Job de déploiement dispose des permissions suivantes :

## Permissions Kubernetes Core

- **Core Resources** (`apiGroups: [""]`)
  - configmaps, secrets, services, serviceaccounts
  - pods, namespaces
  - persistentvolumeclaims, persistentvolumes

- **Apps** (`apps`)
  - deployments, replicasets, statefulsets, daemonsets

- **RBAC** (`rbac.authorization.k8s.io`)
  - roles, rolebindings, clusterroles, clusterrolebindings
  - Avec verbes spéciaux: `bind`, `escalate`

- **Networking** (`networking.k8s.io`)
  - ingresses, networkpolicies

- **Batch** (`batch`)
  - jobs, cronjobs

- **API Extensions** (`apiextensions.k8s.io`)
  - customresourcedefinitions

## Permissions OpenShift

### Routes et Images
- **Routes** (`route.openshift.io`)
  - routes, routes/custom-host

- **Images** (`image.openshift.io`)
  - imagestreams, imagestreamtags

### Configuration (Read-Only)
- **Config** (`config.openshift.io`)
  - ingresses, clusterversions, infrastructures, networks
  - **Verbes**: `get`, `list`, `watch` uniquement

### Operator Framework
- **OpenShift Operators** (`operator.openshift.io`)
  - ingresscontrollers, kubeapiservers, openshiftapiservers

- **OLM Operators** (`operators.coreos.com`)
  - subscriptions, clusterserviceversions
  - installplans, operatorgroups, catalogsources

### Projects et Security
- **Projects** (`project.openshift.io`)
  - projects, projectrequests

- **User** (`user.openshift.io` - Read-Only)
  - users, groups, identities

- **Security** (`security.openshift.io`)
  - securitycontextconstraints (+ verbe `use`)

### Templates et Helm
- **Templates** (`template.openshift.io`)
  - templates, templateinstances, processedtemplates

- **Helm** (`helm.openshift.io`)
  - helmchartrepositories

### Machine Config (Read-Only)
- **Machine Config** (`machineconfiguration.openshift.io`)
  - machineconfigs, machineconfigpools

## Permissions pour ArgoCD et GitOps

- **ArgoCD** (`argoproj.io`)
  - applications, appprojects

## Permissions pour Storage

- **Storage** (`storage.k8s.io`)
  - storageclasses

- **NooBaa** (`noobaa.io`)
  - noobaas, backingstores, bucketclasses

## Permissions OAuth et Console

- **OAuth** (`oauth.openshift.io`)
  - oauthclients

- **Console** (`console.openshift.io`)
  - consolelinks

## Équivalent à cluster-admin ?

**Non**, ce n'est pas l'équivalent de `cluster-admin`. Les différences clés :

1. **Pas de permissions sur** :
   - Nodes et leurs ressources
   - Admission webhooks
   - Cluster monitoring
   - Beaucoup d'autres ressources cluster-wide

2. **Read-only sur** :
   - Configuration du cluster
   - Users et groupes
   - Machine configs

3. **Pas de permission `*` sur tous les API groups**

C'est un **ClusterRole élevé** mais **ciblé** pour déployer des workloads applicatifs et des opérateurs.

## Risques et Recommandations

### Risques
- Peut créer des ClusterRoles et ClusterRoleBindings (escalation possible)
- Peut installer des opérateurs via OLM
- Peut modifier la configuration réseau et les routes

### Recommandations
1. **N'utilisez ce ServiceAccount que pour le déploiement initial**
2. **Supprimez ou désactivez le ClusterRoleBinding après déploiement** si nécessaire
3. **Auditez les logs du Job** pour voir exactement ce qui est créé
4. **Utilisez dans des environnements non-production** pour tester d'abord

## Commandes de Vérification

```bash
# Voir toutes les permissions
oc describe clusterrole idp-lab

# Voir qui peut utiliser ces permissions
oc get clusterrolebinding idp-lab -o yaml

# Auditer ce que le Job a créé
oc get all -A --show-labels | grep "demo.redhat.com/application=idp-lab"
```

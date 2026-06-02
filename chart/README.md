# IDP Lab Helm Chart

Ce chart Helm déploie le Red Hat IDP Lab en utilisant Ansible automation via un Kubernetes Job.

## Description

Ce chart crée :
- Un namespace dédié pour le job de déploiement
- Un ServiceAccount avec les permissions ClusterRole nécessaires
- Un ConfigMap avec la configuration Ansible
- Un Job qui clone votre repo Git, installe les dépendances et exécute le playbook Ansible

Le Job déploie automatiquement :
- OpenShift GitOps (ArgoCD)
- GitLab
- NooBaa (Object Storage)
- HashiCorp Vault
- Red Hat Developer Hub

## Installation

### Via ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: idp-lab
  namespace: openshift-gitops
spec:
  destination:
    namespace: openshift-gitops
    server: 'https://kubernetes.default.svc'
  project: default
  source:
    path: chart
    helm:
      values: |
        deployer:
          apiUrl: https://api.cluster-xxxxx.domain.com:6443
          domain: apps.cluster-xxxxx.domain.com
        gitops:
          repoURL: https://github.com/rh-idp-lab/ansible
          revision: main
          path: ''
    repoURL: 'https://github.com/rh-idp-lab/ansible'
    targetRevision: main
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
    syncOptions:
      - CreateNamespace=true
```

### Via Helm CLI

```bash
helm install idp-lab ./chart \
  --set deployer.apiUrl="https://api.cluster-xxxxx.domain.com:6443" \
  --set deployer.domain="apps.cluster-xxxxx.domain.com"
```

## Configuration

### Paramètres Requis

| Paramètre | Description | Exemple |
|-----------|-------------|---------|
| `deployer.apiUrl` | URL de l'API Kubernetes | `https://api.cluster.domain.com:6443` |
| `deployer.domain` | Domaine des routes OpenShift | `apps.cluster.domain.com` |

### Paramètres Optionnels

| Paramètre | Description | Défaut |
|-----------|-------------|--------|
| `ansible.playbook` | Playbook Ansible à exécuter | `idp_lab_from0.yml` |
| `ansible.repository.url` | URL du repo Git | `https://github.com/rh-idp-lab/ansible` |
| `ansible.repository.branch` | Branche Git | `main` |
| `ansible.extraVars.*` | Variables extra pour Ansible | Voir `values.yaml` |
| `job.ttlSecondsAfterFinished` | TTL du Job après complétion | `600` |
| `resources.limits.cpu` | Limite CPU | `2000m` |
| `resources.limits.memory` | Limite mémoire | `2Gi` |

### Activer/Désactiver des composants

```yaml
ansible:
  extraVars:
    gitlab_enabled: true
    noobaa_enabled: true
    vault_enabled: true
    rhdh_enabled: true
```

## Monitoring

### Vérifier le Job

```bash
# Voir le statut du job
kubectl get job -n idp-lab-deployer

# Voir les logs du job
kubectl logs -n idp-lab-deployer job/idp-lab

# Suivre les logs en temps réel
kubectl logs -n idp-lab-deployer job/idp-lab -f
```

### Vérifier les déploiements

```bash
# GitOps
kubectl get pods -n openshift-gitops

# GitLab
kubectl get pods -n gitlab

# NooBaa
kubectl get pods -n openshift-storage

# Vault
kubectl get pods -n vault

# Developer Hub
kubectl get pods -n developer-hub
```

## Dépannage

### Le Job échoue

```bash
# Voir les événements
kubectl get events -n idp-lab-deployer --sort-by='.lastTimestamp'

# Voir les logs détaillés
kubectl logs -n idp-lab-deployer job/idp-lab --all-containers=true

# Décrire le job pour voir les erreurs
kubectl describe job -n idp-lab-deployer idp-lab
```

### Permissions insuffisantes

Le chart crée un ClusterRole avec les permissions nécessaires. Si vous voyez des erreurs de permissions :

1. Vérifiez que le ClusterRoleBinding est créé :
   ```bash
   kubectl get clusterrolebinding idp-lab
   ```

2. Ajoutez des règles supplémentaires dans `values.yaml` :
   ```yaml
   rbac:
     additionalRules:
       - apiGroups: ["example.com"]
         resources: ["customresources"]
         verbs: ["get", "list", "create"]
   ```

### Relancer le Job

Si vous devez relancer le déploiement :

```bash
# Supprimer le job existant
kubectl delete job -n idp-lab-deployer idp-lab

# Resynchroniser l'application ArgoCD
argocd app sync idp-lab
```

## Structure du Chart

```
chart/
├── Chart.yaml              # Métadonnées du chart
├── values.yaml             # Valeurs par défaut
├── README.md              # Cette documentation
└── templates/
    ├── _helpers.tpl       # Helpers Helm
    ├── namespace.yaml     # Namespace du job
    ├── serviceaccount.yaml # ServiceAccount
    ├── clusterrole.yaml   # Permissions cluster-wide
    ├── clusterrolebinding.yaml
    ├── configmap.yaml     # Config Ansible
    └── job.yaml          # Job principal
```

## Personnalisation

### Utiliser un playbook différent

```yaml
ansible:
  playbook: "custom_playbook.yml"
  repository:
    path: "custom/path"
```

### Ajouter des collections Ansible

```yaml
ansible:
  collections:
    - kubernetes.core:==3.2.0
    - community.general:==9.5.0
    - mycollection.custom:==1.0.0
```

### Ajouter des packages Python

```yaml
ansible:
  requirements:
    - ansible-core
    - kubernetes
    - custom-package
```

## Support

Pour des questions ou des problèmes :
- GitHub Issues: https://github.com/rh-idp-lab/ansible/issues
- Documentation: https://github.com/rh-idp-lab/ansible

## Licence

Red Hat IDP Lab - Internal Use

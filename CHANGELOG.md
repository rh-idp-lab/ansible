# Changelog - IDP Lab Deployment

## 2026-06-02 - Déploiement via Helm Chart et ArgoCD

### Ajouts

#### Helm Chart (`chart/`)
- **Chart.yaml** : Métadonnées du chart IDP Lab
- **values.yaml** : Configuration par défaut avec tous les paramètres
- **templates/** :
  - `_helpers.tpl` : Fonctions helper Helm
  - `namespace.yaml` : Création du namespace deployer
  - `serviceaccount.yaml` : ServiceAccount pour le Job
  - `clusterrole.yaml` : Permissions cluster-wide étendues
  - `clusterrolebinding.yaml` : Association SA <-> ClusterRole
  - `configmap.yaml` : Configuration Ansible (requirements, collections, inventory)
  - `job.yaml` : Job Kubernetes qui exécute Ansible

#### Permissions Étendues (ClusterRole)
- **API Groups OpenShift** :
  - `config.openshift.io` : Lecture de la configuration cluster
  - `operator.openshift.io` : Gestion des IngressControllers, etc.
  - `project.openshift.io` : Gestion des Projects
  - `user.openshift.io` : Lecture des Users/Groups
  - `security.openshift.io` : Utilisation des SCCs
  - `template.openshift.io` : Gestion des Templates
  - `helm.openshift.io` : Gestion des Helm repositories
  - `machineconfiguration.openshift.io` : Lecture des MachineConfigs
  
- **API Groups Kubernetes** :
  - `apiextensions.k8s.io` : Gestion des CRDs
  
- **API Groups ArgoCD** :
  - `argoproj.io` : Gestion des Applications, AppProjects, et ArgoCD instances

#### UserInfo ConfigMap
- **Fichier** : `roles/idp_lab_from0/tasks/post_workload.yml`
- **ConfigMap créé** : `idp-lab-userinfo` dans namespace `showroom`
- **Label** : `demo.redhat.com/userinfo: ""` (pour AgnosticD)
- **Données incluses** :
  - URLs : Showroom, GitLab, API cluster
  - Passwords : common_password, gitlab_root, gitlab_users
  - Métadonnées : lab_title, deployment_type, instructions

#### Documentation
- **chart/README.md** : Documentation du Helm chart
- **docs/USERINFO-CONFIGMAP.md** : Documentation complète du ConfigMap userinfo
- **PERMISSIONS-SUMMARY.md** : Liste détaillée des permissions du ClusterRole
- **argocd-application.yaml** : Application ArgoCD pour déployer le lab

### Corrections

#### Path Ansible
- **Problème** : Le Job ne trouvait pas les rôles Ansible
- **Cause** : `ansible.repository.path: "playbooks"` navigait dans le mauvais dossier
- **Solution** : 
  - `ansible.repository.path: ""` (vide = racine du repo)
  - `ansible.playbook: "playbooks/idp_lab_from0.yml"`

#### Permissions Manquantes
- **Problème** : Erreur 403 Forbidden sur `ingresscontrollers.operator.openshift.io`
- **Cause** : ClusterRole ne contenait pas les API groups OpenShift
- **Solution** : Ajout de ~10 API groups OpenShift supplémentaires

#### Spec ArgoCD Invalide
- **Problème** : `InvalidSpecError: spec.source.repoURL and either spec.source.path or spec.source.chart are required`
- **Cause** : L'Application ArgoCD ne spécifiait pas de `path`
- **Solution** : Ajout de `spec.source.path: chart`

### Architecture du Déploiement

```
GitHub Repo (rh-idp-lab/ansible)
  └─ chart/                    # Helm Chart
       ├── Chart.yaml
       ├── values.yaml
       └── templates/
            └── job.yaml       # Crée un Job Kubernetes
                 └─ Job exécute Ansible
                      └─ Clone le repo
                      └─ Exécute playbooks/idp_lab_from0.yml
                           └─ Déploie GitOps, GitLab, Vault, NooBaa, RHDH
                           └─ Crée ConfigMap userinfo
```

### Workflow de Déploiement

1. **ArgoCD** synchronise l'Application depuis GitHub
2. **Helm** génère les manifests Kubernetes
3. **Namespace** `idp-lab-deployer` est créé
4. **ServiceAccount** + **ClusterRole** sont créés
5. **Job** démarre avec les permissions élevées
6. **Ansible** s'exécute dans le Job :
   - Clone le repo Git
   - Installe les collections Ansible
   - Exécute le playbook principal
   - Déploie tous les composants
   - Crée le ConfigMap userinfo
7. **Résultat** : Lab IDP complet déployé

### Variables Importantes

#### Chart values.yaml
- `deployer.apiUrl` : URL de l'API Kubernetes (**REQUIS**)
- `deployer.domain` : Domaine des routes OpenShift (**REQUIS**)
- `ansible.repository.url` : URL du repo Git
- `ansible.repository.branch` : Branche Git
- `ansible.playbook` : Playbook à exécuter
- `ansible.extraVars.*` : Variables passées à Ansible

#### Ansible
- `common_password` : Mot de passe partagé pour tous les services
- `idp_lab_from0_showroom_namespace` : Namespace Showroom
- `idp_lab_from0_gitlab_namespace` : Namespace GitLab
- `r_openshift_subdomain` : Domaine du cluster (auto-détecté)

### Commandes Utiles

```bash
# Déployer
oc apply -f argocd-application.yaml

# Suivre les logs
oc logs -n idp-lab-deployer job/idp-lab -f

# Voir le ConfigMap userinfo
oc get configmap idp-lab-userinfo -n showroom -o yaml

# Vérifier les permissions
oc describe clusterrole idp-lab

# Nettoyer
oc delete application -n openshift-gitops idp-lab
oc delete namespace idp-lab-deployer
```

### Prochaines Étapes Possibles

- [ ] Ajouter des health checks dans le Job
- [ ] Créer un Secret pour stocker les passwords au lieu du ConfigMap
- [ ] Ajouter un hook ArgoCD pour la synchronisation
- [ ] Documenter l'intégration avec AgnosticD RHDP
- [ ] Créer des tests automatisés du déploiement
- [ ] Ajouter un README à la racine du repo ansible

### Contributeurs

- Helm Chart design basé sur https://github.com/rhpds/field-sourced-content-template
- ClusterRole permissions étendues pour OpenShift
- UserInfo ConfigMap pour intégration AgnosticD

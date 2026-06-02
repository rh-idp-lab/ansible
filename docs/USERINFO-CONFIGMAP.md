# UserInfo ConfigMap

## Description

Le playbook IDP Lab crée automatiquement un **ConfigMap** nommé `idp-lab-userinfo` dans le namespace `showroom` à la fin du déploiement. Ce ConfigMap contient toutes les informations d'accès nécessaires pour utiliser le lab.

## Label Important

Le ConfigMap est marqué avec le label spécial :
```yaml
demo.redhat.com/userinfo: ""
```

Ce label permet à **AgnosticD** et à la **plateforme RHDP** (Red Hat Demo Platform) de :
- Détecter automatiquement le ConfigMap
- Extraire les informations pour les afficher à l'utilisateur final
- Fournir les URLs et credentials lors de la provisioning d'une démo

## Structure du ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: idp-lab-userinfo
  namespace: showroom
  labels:
    demo.redhat.com/userinfo: ""
    demo.redhat.com/application: "idp-lab"
data:
  # Titre du lab
  lab_title: "Red Hat Internal Developer Platform Lab"
  
  # Instructions d'accès
  access_instructions: |
    Access the Showroom lab guide at https://showroom-xxx.apps.cluster.domain.com
    GitLab is available at https://gitlab-xxx.apps.cluster.domain.com
  
  # Type de déploiement
  deployment_type: "ansible"
  
  # URL Showroom
  showroom_url: "https://showroom-xxx.apps.cluster.domain.com"
  
  # URL GitLab
  gitlab_url: "https://gitlab-xxx.apps.cluster.domain.com"
  
  # Mot de passe commun
  common_password: "xxxxx"
  
  # Domaine du cluster
  cluster_domain: "apps.cluster-xxx.domain.com"
  
  # URL API du cluster
  cluster_api_url: "https://api.cluster-xxx.domain.com:6443"
  
  # Mot de passe root GitLab
  gitlab_root_password: "xxxxx"
  
  # Mot de passe des utilisateurs GitLab
  gitlab_users_password: "xxxxx"
```

## Champs Disponibles

| Champ | Description | Exemple |
|-------|-------------|---------|
| `lab_title` | Titre du lab | "Red Hat Internal Developer Platform Lab" |
| `access_instructions` | Instructions formatées pour l'utilisateur | Texte multi-lignes avec URLs |
| `deployment_type` | Type de déploiement | "ansible" |
| `showroom_url` | URL complète de Showroom | https://showroom-xxx.apps... |
| `gitlab_url` | URL complète de GitLab | https://gitlab-xxx.apps... |
| `common_password` | Mot de passe générique | Valeur de `common_password` |
| `cluster_domain` | Domaine des routes OpenShift | apps.cluster-xxx.domain.com |
| `cluster_api_url` | URL de l'API Kubernetes | https://api.cluster-xxx... |
| `gitlab_root_password` | Password root GitLab | Même que `common_password` |
| `gitlab_users_password` | Password utilisateurs GitLab | Même que `common_password` |

## Comment Accéder au ConfigMap

### Via CLI

```bash
# Voir le ConfigMap
oc get configmap idp-lab-userinfo -n showroom -o yaml

# Extraire une valeur spécifique
oc get configmap idp-lab-userinfo -n showroom -o jsonpath='{.data.showroom_url}'

# Afficher toutes les données
oc get configmap idp-lab-userinfo -n showroom -o jsonpath='{.data}' | jq .
```

### Via Ansible (dans un playbook)

```yaml
- name: Get userinfo ConfigMap
  kubernetes.core.k8s_info:
    api_version: v1
    kind: ConfigMap
    name: idp-lab-userinfo
    namespace: showroom
  register: userinfo_cm

- name: Display Showroom URL
  ansible.builtin.debug:
    msg: "Showroom: {{ userinfo_cm.resources[0].data.showroom_url }}"
```

### Via Python (kubernetes client)

```python
from kubernetes import client, config

config.load_kube_config()
v1 = client.CoreV1Api()

cm = v1.read_namespaced_config_map(
    name="idp-lab-userinfo",
    namespace="showroom"
)

print(f"Showroom URL: {cm.data['showroom_url']}")
print(f"GitLab URL: {cm.data['gitlab_url']}")
print(f"Password: {cm.data['common_password']}")
```

## Intégration AgnosticD

Lorsque ce lab est déployé via **AgnosticD** sur la plateforme RHDP, le workload role `ocp4_workload_field_content` :

1. Détecte automatiquement le ConfigMap avec le label `demo.redhat.com/userinfo`
2. Extrait les données
3. Les passe en retour à AgnosticD via des variables d'output
4. AgnosticD les affiche à l'utilisateur final dans l'email de confirmation

Exemple de sortie AgnosticD :
```
Your Red Hat Internal Developer Platform Lab is ready!

Access Instructions:
  Showroom Lab Guide: https://showroom-xxx.apps.cluster.domain.com
  GitLab: https://gitlab-xxx.apps.cluster.domain.com
  
Credentials:
  Common Password: your-password-here
```

## Création du ConfigMap

Le ConfigMap est créé dans le fichier :
```
roles/idp_lab_from0/tasks/post_workload.yml
```

Il est généré **après** que tous les composants soient déployés, pour s'assurer que :
- La route Showroom existe et est accessible
- La route GitLab existe et est accessible
- Les variables de configuration sont toutes définies

## Variables Ansible Utilisées

Le ConfigMap utilise les variables suivantes :
- `idp_lab_from0_showroom_namespace` - Namespace Showroom
- `idp_lab_from0_gitlab_namespace` - Namespace GitLab
- `common_password` - Mot de passe partagé
- `r_openshift_subdomain` - Domaine du cluster
- `cluster_api_url` - URL API du cluster
- `idp_lab_from0_gitlab_config_root_password` - Password root GitLab
- `idp_lab_from0_gitlab_users_password` - Password utilisateurs GitLab

## Dépannage

### Le ConfigMap n'est pas créé

Vérifiez que :
1. Les routes Showroom et GitLab existent :
   ```bash
   oc get route -n showroom
   oc get route -n gitlab
   ```

2. Le playbook post_workload s'est exécuté :
   ```bash
   # Vérifiez les logs du job
   oc logs -n idp-lab-deployer job/idp-lab | grep "Create userinfo ConfigMap"
   ```

### Le ConfigMap existe mais les données sont vides

Cela peut arriver si :
- Les routes ne sont pas encore créées au moment de l'exécution
- Les variables Ansible ne sont pas définies

Solution : Relancez la tâche post_workload ou recréez le ConfigMap manuellement.

### Mettre à jour le ConfigMap après déploiement

```bash
# Récupérer les URLs actuelles
SHOWROOM_URL=$(oc get route -n showroom -o jsonpath='{.items[0].spec.host}')
GITLAB_URL=$(oc get route -n gitlab -l app=webservice -o jsonpath='{.items[0].spec.host}')

# Mettre à jour le ConfigMap
oc patch configmap idp-lab-userinfo -n showroom --type merge -p "{\"data\":{\"showroom_url\":\"https://$SHOWROOM_URL\",\"gitlab_url\":\"https://$GITLAB_URL\"}}"
```

## Sécurité

⚠️ **ATTENTION** : Le ConfigMap contient des mots de passe en clair !

- Ne committez jamais ce ConfigMap dans Git
- N'exposez pas ce ConfigMap publiquement
- Utilisez des Secrets Kubernetes pour des environnements de production
- Ce ConfigMap est adapté pour des environnements de **lab/démo temporaires uniquement**

Pour les environnements de production, utilisez plutôt des **Secrets** :
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: idp-lab-credentials
type: Opaque
stringData:
  common_password: "{{ common_password }}"
  gitlab_root_password: "{{ gitlab_root_password }}"
```

## Ressources Additionnelles

- [AgnosticD Documentation](https://github.com/redhat-cop/agnosticd)
- [Field Content Template](https://github.com/rhpds/field-sourced-content-template)
- [Kubernetes ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)

# Déploiement Automatique des Microservices

**Date de mise en œuvre** : 19 Août 2025  
**Statut** : ✅ Opérationnel  
**Responsable** : Infrastructure automatisée  

## Vue d'ensemble

Le système de déploiement automatique permet de déployer automatiquement les microservices (api-gateway, api-enrichment, api-generation) lors de chaque push sur la branche `main`, avec zero-downtime et traçabilité complète.

## Architecture du déploiement

### Flux de déploiement

```
Push GitHub → Actions CI → Image SHA créée → Flux détecte → Script Cron → Déploiement K8s → API mise à jour
```

**Temps de déploiement** : Maximum 2 minutes après le push

## Composants du système

### 1. GitHub Actions

Les workflows GitHub Actions buildent automatiquement les images Docker avec des tags SHA :

```yaml
- name: Build and push
  uses: docker/build-push-action@v6
  with:
    push: true
    tags: |
      ghcr.io/team-mercurious/[SERVICE]:latest
      ghcr.io/team-mercurious/[SERVICE]:sha-${{ github.sha }}
```

**Services concernés** :
- `api-gateway`
- `api-enrichment` 
- `api-generation`

**Registry** : `ghcr.io/team-mercurious/`

### 2. Flux GitOps (Image Detection)

Flux surveille automatiquement les nouveaux tags dans le GitHub Container Registry :

**Image Repositories** :
```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: [SERVICE]
  namespace: flux-system
spec:
  image: ghcr.io/team-mercurious/[SERVICE]
  interval: 5m
```

**Image Policies** :
```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: [SERVICE]
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: [SERVICE]
  filterTags:
    pattern: '^sha-[a-f0-9]+$'
  policy:
    alphabetical:
      order: asc
```

### 3. Script de déploiement automatique

**Fichier** : `/home/ubuntu/auto-deploy-simple.sh`

**Fonctionnalités** :
- 🔍 Détection automatique des nouvelles images SHA via Flux
- ⚡ Déploiement immédiat avec rolling updates
- 🏥 Vérification de santé des déploiements  
- 📝 Logging complet dans `/home/ubuntu/auto-deploy.log`
- 🛡️ Timeout de sécurité (5 minutes par déploiement)

**Algorithme** :
1. Synchronisation forcée des Image Repositories Flux
2. Comparaison image actuelle vs dernière image détectée
3. Déploiement automatique si différence détectée
4. Attente du rollout complet avec vérification
5. Vérification de la santé finale des services

### 4. Surveillance cron

**Configuration** : `*/2 * * * *` (toutes les 2 minutes)

```bash
crontab -l
# */2 * * * * /home/ubuntu/auto-deploy-simple.sh >/dev/null 2>&1
```

## Configuration des services

### Services déployés automatiquement

| Service | Port | Health Check | Registry |
|---------|------|-------------|----------|
| api-gateway | 8080, 8081 | `/` | ghcr.io/team-mercurious/api-gateway |
| api-enrichment | 8080 | N/A | ghcr.io/team-mercurious/api-enrichment |
| api-generation | 8080 | N/A | ghcr.io/team-mercurious/api-generation |

### Authentification GitHub Container Registry

**Secret Kubernetes** : `github-token` (namespace: flux-system)
- Username: `team-mercurious`
- Token: GitHub Personal Access Token avec permissions read/write packages

## Monitoring et observabilité

### Logs de déploiement

**Fichier** : `/home/ubuntu/auto-deploy.log`

**Format des logs** :
```
[2025-08-19 11:20:03] 🚀 Démarrage auto-deploy
[2025-08-19 11:20:03] 🔄 Synchronisation Flux...
[2025-08-19 11:20:03] 🔍 Vérification api-gateway...
[2025-08-19 11:20:03] 📊 api-gateway: actuel=ghcr.io/team-mercurious/api-gateway:sha-xxx
[2025-08-19 11:20:03] 📊 api-gateway: flux=ghcr.io/team-mercurious/api-gateway:sha-yyy
[2025-08-19 11:20:03] 🆕 Mise à jour détectée pour api-gateway
[2025-08-19 11:20:03] 🚀 Déploiement de api-gateway vers ghcr.io/team-mercurious/api-gateway:sha-yyy
[2025-08-19 11:20:21] ✅ Déploiement réussi: api-gateway
[2025-08-19 11:20:21] 🎉 api-gateway mis à jour avec succès
```

### Script de monitoring

**Fichier** : `/home/ubuntu/check-status.sh`

**Utilisation** :
```bash
./check-status.sh
```

**Informations affichées** :
- État des déploiements actuels
- Status des pods
- Dernières détections Flux
- Derniers logs d'activité
- Prochaine exécution cron

### Vérification de l'API

**Endpoint de test** : `https://api2.gotravelyzer.com/`

**Commande de vérification** :
```bash
curl -s https://api2.gotravelyzer.com/
# Retourne la version actuelle (ex: v1.0.1-rc3)
```

## Traçabilité et versions

### Format des SHA

**Pattern** : `sha-[40 caractères hexadécimaux]`
**Exemple** : `sha-0d82e2d9cb7db354bb88faf91fe2efe21e5d46d4`

### Correspondance Git → Image → Déploiement

1. **Commit Git** : SHA du commit sur main
2. **Image Docker** : `ghcr.io/team-mercurious/[service]:sha-[git-sha]`
3. **Déploiement K8s** : Rolling update vers la nouvelle image
4. **Vérification** : API accessible avec nouvelle version

## Procédures d'urgence

### Arrêt temporaire du déploiement automatique

```bash
# Supprimer le cron
crontab -r

# Ou commenter la ligne
crontab -e
# Ajouter # devant la ligne
```

### Rollback manuel

```bash
# Voir les versions précédentes
kubectl rollout history deployment/api-gateway

# Rollback vers version précédente
kubectl rollout undo deployment/api-gateway

# Rollback vers version spécifique
kubectl rollout undo deployment/api-gateway --to-revision=2
```

### Déploiement manuel d'une image spécifique

```bash
# Déployer un SHA spécifique
kubectl set image deployment/api-gateway api-gateway=ghcr.io/team-mercurious/api-gateway:sha-xxxxx

# Attendre le déploiement
kubectl rollout status deployment/api-gateway
```

## Résolution de problèmes

### Problèmes courants

1. **Image non trouvée** (ImagePullBackOff)
   - Vérifier que l'image existe dans ghcr.io
   - Vérifier les permissions GitHub token
   - Vérifier le format du tag SHA

2. **Déploiement qui timeout**
   - Vérifier les ressources du cluster
   - Vérifier les health checks des applications
   - Examiner les logs des pods

3. **Flux ne détecte pas les nouvelles images**
   - Forcer la synchronisation : `flux reconcile image repository [service]`
   - Vérifier les Image Policies : `kubectl get imagepolicies -n flux-system`
   - Vérifier les permissions du token GitHub

### Commandes de diagnostic

```bash
# État général du système
./check-status.sh

# Logs récents du déploiement automatique
tail -20 /home/ubuntu/auto-deploy.log

# État des ressources Flux
flux get all

# État des déploiements Kubernetes
kubectl get deployments -o wide

# Logs d'un pod spécifique
kubectl logs -l app=[service] --tail=50
```

## Métriques de performance

### Temps de déploiement moyens

- **Détection** : < 2 minutes (surveillance cron)
- **Déploiement rolling** : 20-30 secondes par service
- **Vérification santé** : 10 secondes
- **Total end-to-end** : < 3 minutes

### Disponibilité

- **Zero-downtime** : ✅ Rolling updates
- **Health checks** : ✅ Readiness probes
- **Rollback automatique** : ✅ En cas d'échec

## Sécurité

### Authentification
- GitHub token avec permissions minimales (read/write packages)
- Secret Kubernetes chiffré
- Accès limité au namespace flux-system

### Autorisation
- Script exécuté par l'utilisateur `ubuntu`
- Permissions kubectl limitées aux déploiements
- Isolation des services dans le namespace par défaut

### Audit
- Tous les déploiements tracés dans les logs
- Correspondance SHA Git → SHA Image → Déploiement
- Historique des rollouts Kubernetes disponible

## Évolutions futures

### Améliorations possibles

1. **Notifications** : Intégration Slack/Discord pour les déploiements
2. **Tests automatiques** : Health checks avancés post-déploiement
3. **Rollback automatique** : En cas de failure des health checks
4. **Multi-environnements** : Déploiement staging → prod
5. **Métriques avancées** : Prometheus metrics pour les déploiements

### Maintenance

- **Logs rotation** : Nettoyer `/home/ubuntu/auto-deploy.log` régulièrement
- **Images cleanup** : Supprimer les anciennes images du registry
- **Secrets rotation** : Renouveler le GitHub token périodiquement

---

**Dernière mise à jour** : 19 Août 2025  
**Version du document** : 1.0  
**Prochaine révision** : 1er Septembre 2025
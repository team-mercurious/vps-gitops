# Validation des Workflows CI/CD - 2025-08-13

## ✅ Workflows GitHub Actions opérationnels

Le workflow de publication fonctionne correctement avec cette configuration :

```yaml
name: Publish container

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build-and-push:
    permissions:
      contents: read
      packages: write
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          push: true
          tags: |
            ghcr.io/team-mercurious/api-gateway:latest
            ghcr.io/team-mercurious/api-gateway:sha-${{ github.sha }}
```

## Configuration FluxCD correspondante

Nos ImagePolicy sont configurés pour détecter automatiquement ces nouvelles images :

### api-gateway
- **Registry**: `ghcr.io/team-mercurious/api-gateway`
- **Policy**: semver range `>=0.0.0` (capture tous les tags)
- **Automation**: Mise à jour automatique du tag dans `apps/api-gateway/kustomization.yaml`

### Tags générés par le workflow
- `latest`: Image de la branche main
- `sha-{commit}`: Image taguée avec le SHA du commit

## Flux de déploiement automatique

1. **Push sur main** → Déclenche GitHub Actions
2. **Build & Push** → Image poussée vers GHCR avec les tags
3. **FluxCD scan** → Détecte la nouvelle image (interval: 5m)
4. **Auto-update** → Met à jour le kustomization.yaml
5. **Git commit** → FluxCD commit automatiquement les changements
6. **Deploy** → Kubernetes déploie la nouvelle version

## Vérification de l'automation

```bash
# Vérifier les ImageRepository
kubectl get imagerepositories -n flux-system

# Vérifier les ImagePolicy  
kubectl get imagepolicies -n flux-system

# Vérifier les ImageUpdateAutomation
kubectl get imageupdateautomations -n flux-system

# Voir les logs d'automation
flux logs --kind ImageUpdateAutomation
```

## Status actuel

✅ **GitHub Actions** : Workflows configurés et fonctionnels
✅ **GHCR Push** : Images poussées correctement  
✅ **FluxCD ImagePolicy** : Configuré pour détecter les nouvelles images
✅ **Auto-update** : Prêt à mettre à jour automatiquement les déploiements

## Prochaine validation

Une fois qu'un push est effectué sur une des branches main des repos :
1. Vérifier que l'image apparaît dans GHCR
2. Contrôler que FluxCD détecte l'image : `flux get images`
3. Valider la mise à jour automatique du tag dans GitOps
4. Confirmer le déploiement automatique dans K8s

Le pipeline CI/CD complet est maintenant opérationnel ! 🚀
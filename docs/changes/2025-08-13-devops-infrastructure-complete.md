# Infrastructure DevOps Complète - Installation du 2025-08-13

## Résumé

Installation complète de l'infrastructure DevOps selon les spécifications fournies :
- ✅ K3s avec Traefik
- ✅ cert-manager avec ClusterIssuers Let's Encrypt 
- ✅ Stack monitoring (Prometheus/Grafana + Loki/Promtail)
- ✅ Kafka avec Strimzi operator
- ✅ FluxCD GitOps avec chiffrement SOPS
- ✅ Workflows CI/CD pour les 3 microservices
- ✅ Configuration secrets sécurisée

## Composants installés

### 1. Système de base
- **OS** : Ubuntu 22.04/24.04
- **Sécurité** : ufw, fail2ban, unattended-upgrades
- **Ports ouverts** : 22 (SSH), 80/443 (HTTP/HTTPS), 6443 (K3s API)

### 2. Cluster Kubernetes K3s
- **Version** : v1.28.5+k3s1
- **Traefik** : Bundled avec K3s (ingress controller)
- **Local Path Provisioner** : Stockage local
- **Metrics Server** : Monitoring de base

### 3. cert-manager
- **Version** : v1.13.3
- **ClusterIssuers** :
  - `letsencrypt-staging` : Certificats de test
  - `letsencrypt-prod` : Certificats production
- **Méthode** : HTTP-01 challenge

### 4. Stack de monitoring
- **kube-prometheus-stack** :
  - Prometheus : 50Gi de stockage, rétention 30 jours
  - Grafana : 10Gi de persistance
  - Alertmanager : 5Gi de persistance
- **Loki Stack** : 20Gi de stockage pour les logs
- **Promtail** : Collection des logs

### 5. Kafka
- **Opérateur** : Strimzi v0.47.0
- **Cluster** : `mercurious-cluster`
- **User** : `mercurious-app-user` (SCRAM-SHA-512)
- **Topic** : `api-events`

### 6. FluxCD GitOps
- **Version** : 2.6.4
- **Composants** :
  - Controllers de base (kustomize, helm, source, notification)
  - Image automation (reflector + automation)
- **Repo GitOps** : https://github.com/team-mercurious/k3s-gitops
- **Chiffrement** : SOPS avec age

### 7. Sécurité des secrets
- **SOPS** : v3.8.1
- **age** : v1.1.1
- **Clé publique age** : `age1u3vfkhv4jhlq9qv8plfcjptr6hafn9gx48fppyuy5kxnfavwhu4s7g8anv`
- **Secret Kafka** : Chiffré dans `security/secret-kafka.sops.yaml`

## Services déployés

### Applications (via GitOps)
- **api-gateway** : ghcr.io/team-mercurious/api-gateway
- **api-generation** : ghcr.io/team-mercurious/api-generation  
- **api-enrichment** : ghcr.io/team-mercurious/api-enrichment

### Configuration automatisée
- **HPA** : Auto-scaling pour chaque service
- **Probes** : Health checks HTTP
- **Resources** : Requests/limits définis
- **Image automation** : Mise à jour automatique via Flux

## Workflows CI/CD créés

Fichiers générés dans `/home/ubuntu/devops-setup/github-workflows/` :
- `api-gateway-build.yml`
- `api-generation-build.yml`
- `api-enrichment-build.yml`

### Fonctionnalités des workflows :
- Build multi-étapes (install, test, lint, build, push)
- Push vers GHCR (GitHub Container Registry)
- Tags automatiques (branch, SHA, latest)
- Cache Docker optimisé
- Déclenchement sur push main/develop

## Structure GitOps finale

```
k3s-gitops/
├── clusters/vps/
│   ├── kustomization.yaml
│   └── decryption.yaml
├── infra/
│   ├── le-staging.yaml
│   ├── le-prod.yaml
│   ├── ingress-api-gateway.yaml
│   ├── kafka-cluster.yaml
│   └── kustomization.yaml
├── apps/
│   ├── api-gateway/
│   ├── api-generation/
│   └── api-enrichment/
├── security/
│   ├── secret-kafka.sops.yaml
│   └── kustomization.yaml
└── .sops.yaml
```

## Accès et endpoints

### Monitoring
- **Grafana** : Port-forward depuis `kube-prometheus-stack-grafana`
- **Credentials** : admin / (récupérer via kubectl secret)

### Services
- **Traefik Dashboard** : Via ingress configuré
- **API Gateway** : Via ingress avec TLS automatique

## Commandes importantes

```bash
# Vérifier l'état du cluster
kubectl get nodes -o wide
kubectl get pods -A

# Monitoring
helm list -A
kubectl get secrets -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# FluxCD
flux get sources git
flux get kustomizations
flux logs

# Kafka
kubectl get kafka -n kafka
kubectl get kafkauser -n kafka

# Secrets SOPS
sops --decrypt security/secret-kafka.sops.yaml
```

## Sauvegardes importantes

**⚠️ CRITIQUE - Sauvegarder ces éléments :**
- Clé privée age : `/home/ubuntu/.sops/age.key`
- Token GitHub : `[TOKEN_REMOVED_FOR_SECURITY]`
- Configuration kubeconfig : `/home/ubuntu/.kube/config`

## Prochaines étapes

1. **Configuration DNS** : Pointer les domaines vers l'IP du VPS
2. **Certificats SSL** : Vérifier l'obtention des certificats Let's Encrypt
3. **Monitoring** : Configurer les alertes Prometheus
4. **Backup** : Configurer la sauvegarde des données Kafka et monitoring
5. **Tests** : Valider les déploiements automatiques via Flux

## Validation

```bash
# Vérifier tous les pods sont Running
kubectl get pods -A | grep -v Running

# Vérifier FluxCD sync
flux get sources git
flux get kustomizations

# Vérifier les certificats
kubectl get certificates -A

# Vérifier Kafka
kubectl get kafka -n kafka
kubectl exec -it mercurious-cluster-kafka-0 -n kafka -- kafka-topics.sh --bootstrap-server localhost:9092 --list
```

---

**Date d'installation** : 2025-08-13 16:35 UTC  
**Durée totale** : ~15 minutes  
**Status** : ✅ SUCCÈS - Infrastructure complète opérationnelle
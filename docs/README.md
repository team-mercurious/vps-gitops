# Documentation VPS - Guide complet

## Vue d'ensemble

Cette documentation complète couvre l'ensemble de l'infrastructure VPS hébergée chez Nova Clouds, configurée avec un cluster Kubernetes K3s et un écosystème GitOps complet.

### Architecture générale
- **VPS**: Nova Clouds - vps-6227e9e1 (16 cores, 15.6GB RAM, 155GB storage)
- **OS**: Ubuntu 24.10 (Oracular) 
- **Orchestration**: Kubernetes K3s v1.28.5
- **GitOps**: Flux v2 avec automatisation complète
- **Monitoring**: Stack Prometheus/Grafana/Loki
- **Messaging**: Apache Kafka via Strimzi
- **Applications**: API Gateway, Generation, Enrichment

## Structure de la documentation

### 📋 Infrastructure
#### [Architecture Overview](infrastructure/architecture-overview.md)
Vue d'ensemble complète de l'architecture, composants principaux, flux de données et points critiques.

#### [Kubernetes Cluster](infrastructure/kubernetes-cluster.md)
Configuration détaillée du cluster K3s, namespaces, services système et applications déployées.

#### [GitOps avec Flux](infrastructure/gitops-flux.md)
Workflows GitOps, contrôleurs Flux, automatisation des déploiements et gestion des secrets SOPS.

#### [Configuration Réseau](infrastructure/network-configuration.md)
DNS, routage, services Kubernetes, load balancing et troubleshooting réseau.

### 🔒 Sécurité
#### [Firewall et Sécurité](security/firewall-security.md)
Configuration UFW, Fail2Ban, ports exposés, certificats TLS et surveillance sécurité.

### 🚀 Opérations
#### [Procédures de Déploiement](operations/deployment-procedures.md)
CI/CD GitHub Actions, Flux automation, rollback, validation et environnements.

#### [Monitoring et Observabilité](operations/monitoring-observability.md)
Stack Prometheus/Grafana/Loki, métriques, alertes, dashboards et debugging.

#### [Guide de Troubleshooting](operations/troubleshooting-guide.md)
Diagnostic système, problèmes Kubernetes, Flux, applications et procédures d'urgence.

#### [Backup et Disaster Recovery](operations/backup-disaster-recovery.md)
Stratégies de sauvegarde, automatisation, procédures de recovery et tests.

### 💻 Applications
#### [Services API](applications/api-services.md)
API Gateway, Generation, Enrichment - déploiements, communication, monitoring et sécurité.

#### [Kafka Messaging](applications/kafka-messaging.md)
Configuration Kafka/Strimzi, topics, producers/consumers, monitoring et troubleshooting.

### 📊 Système
#### [Spécifications](system/specifications.md)
Ressources matérielles, système d'exploitation, réseau et virtualisation.

#### [État Actuel](system/current-state.md)
Status en temps réel des services, utilisation des ressources et santé système.

### 🔧 Maintenance
#### [Guide de Maintenance](maintenance/maintenance-guide.md)
Procédures de maintenance régulière, mises à jour et optimisation.

### 🏆 Performance
#### [Optimisation](performance/optimization-2025-08-13.md)
Optimisations appliquées, métriques de performance et recommandations.

### 📝 Historique
#### [Changelog](changes/)
Historique détaillé des modifications, déploiements et incidents.

## Quick Start

### Accès au VPS
```bash
# SSH connection
ssh ubuntu@37.59.98.241

# Vérification santé générale
kubectl get nodes
kubectl get pods -A
systemctl status k3s
```

### Commandes essentielles
```bash
# Cluster Kubernetes
kubectl get nodes
kubectl get pods -A
kubectl top nodes
kubectl top pods -A

# Flux GitOps
flux get all
flux get sources git
flux get kustomizations

# Monitoring
kubectl get pods -n monitoring
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Applications
kubectl get pods -l app=api-gateway
kubectl logs -l app=api-gateway --tail=100
```

### URLs des services (à configurer)
- **Grafana**: https://grafana.domain.com
- **API Gateway**: https://api.domain.com
- **Prometheus**: Accès interne cluster seulement

## Contacts et support

### Escalation
1. **Self-service**: Cette documentation + logs + redémarrages
2. **Admin système**: [contact-admin]
3. **Provider**: Nova Clouds support
4. **Critical**: Escalation complète

### Ressources utiles
- **Logs centralisés**: Loki via Grafana
- **Métriques**: Prometheus/Grafana dashboards  
- **Status cluster**: `kubectl get nodes && kubectl get pods -A`
- **Health checks**: `/health` endpoints sur services

## Conventions

### Naming
- **Kebab-case**: Pour noms de services, deployments, ingress
- **snake_case**: Pour variables d'environnement
- **CamelCase**: Pour labels Kubernetes spécifiques

### Labels standards
```yaml
metadata:
  labels:
    app: service-name
    version: v1.0.0
    component: api|database|cache
    managed-by: flux
```

### Annotations importantes
```yaml
metadata:
  annotations:
    # Monitoring
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
    
    # Flux
    flux.weave.works/automated: "true"
    flux.weave.works/tag.chart-image: "semver:~1.0"
    
    # Ingress
    kubernetes.io/ingress.class: "traefik"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

## Roadmap et évolutions

### Améliorations courte terme
- [ ] Configuration domaines et certificats Let's Encrypt
- [ ] Alertes Slack/Discord pour monitoring
- [ ] Backup automatique vers stockage externe
- [ ] Tests d'intégration automatisés

### Évolutions moyen terme
- [ ] Multi-node Kubernetes pour haute disponibilité
- [ ] Service mesh (Istio/Linkerd) pour observabilité avancée
- [ ] CI/CD avancé avec tests de charge
- [ ] Disaster recovery site distant

### Optimisations long terme
- [ ] Auto-scaling cluster nodes
- [ ] Cache distribué (Redis Cluster)
- [ ] CDN pour assets statiques
- [ ] Observability avancée (tracing distribué)

---

**Dernière mise à jour**: 2025-08-15  
**Version documentation**: 2.0  
**Contributeurs**: Claude Code  
**Status**: Production Ready ✅
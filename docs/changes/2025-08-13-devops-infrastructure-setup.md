# Setup infrastructure DevOps complète - 2025-08-13

**Date:** 2025-08-13  
**Heure:** 14:10 UTC  
**Effectué par:** Claude (Assistant IA DevOps)  
**Durée:** En cours

## Objectif
Mettre en place une infrastructure DevOps complète avec K3s, Traefik, monitoring (Prometheus/Grafana/Loki), GitOps (FluxCD), et déployer 3 microservices avec CI/CD automatisé vers GHCR.

## Contexte
Infrastructure cible:
- **Platform**: VPS Ubuntu optimisé (16 cores, 16GB RAM)
- **Orchestration**: K3s + Traefik (intégré)
- **Monitoring**: Prometheus/Grafana + Loki/Promtail
- **GitOps**: FluxCD avec auto-update images
- **Security**: SOPS + age pour secrets, cert-manager pour TLS
- **Services**: api-gateway + 2 microservices (api-generation, api-enrichment)
- **External**: MongoDB, Redis (cloud), Kafka (local sur VPS)

## Modifications planifiées
- [x] Structure projet et bootstrap script
- [ ] Installation K3s + outils DevOps
- [ ] Configuration GitOps repository 
- [ ] Manifests Kubernetes infrastructure
- [ ] Déploiements applications
- [ ] Secrets SOPS + Kafka
- [ ] Configuration FluxCD GitOps
- [ ] CI/CD GitHub Actions
- [ ] Documentation complète
- [ ] Tests et validation

## Architecture technique

### Stack technology
```
├── K3s (Kubernetes lightweight)
├── Traefik (Ingress Controller, TLS termination)  
├── cert-manager (Let's Encrypt automation)
├── Monitoring Stack
│   ├── Prometheus (metrics)
│   ├── Grafana (dashboards)
│   ├── Loki (logs aggregation)
│   └── Promtail (log shipping)
├── FluxCD (GitOps continuous deployment)
├── SOPS + age (secrets encryption)
└── Applications
    ├── api-gateway (port 8080)
    ├── api-generation (microservice)
    ├── api-enrichment (microservice)
    └── Kafka (message broker)
```

### Repositories GitHub
- **Infrastructure**: k3s-gitops (GitOps repo)
- **Applications**: 
  - https://github.com/team-mercurious/api-gateway.git
  - https://github.com/team-mercurious/api-generation.git
  - https://github.com/team-mercurious/api-enrichment.git
- **Registry**: GitHub Container Registry (GHCR)

## Étapes en cours

### 1. Structure projet et bootstrap
**Objectif:** Créer l'arborescence complète et le script d'installation automatique

**Status:** 🔄 En cours
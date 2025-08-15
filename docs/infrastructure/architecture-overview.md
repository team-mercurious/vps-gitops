# Architecture Overview - VPS Infrastructure

## Vue d'ensemble de l'infrastructure

Cette documentation décrit l'architecture complète de votre VPS hébergé chez Nova Clouds, configuré avec un cluster Kubernetes K3s et un écosystème GitOps complet.

## Architecture générale

```
┌─────────────────────────────────────────────────────────────────┐
│                        VPS - vps-6227e9e1                       │
│                         Nova Clouds                             │
├─────────────────────────────────────────────────────────────────┤
│                     Ubuntu 24.10 (Oracular)                    │
│                    AMD EPYC-Milan 16 cores                     │
│                         15.6 GB RAM                            │
│                        155 GB Storage                          │
├─────────────────────────────────────────────────────────────────┤
│                    Infrastructure Layer                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌──────────────┐│
│  │    SSH      │ │    UFW      │ │  Fail2Ban   │ │ System Utils ││
│  │   Port 22   │ │  Firewall   │ │  Security   │ │   & Cron    ││
│  └─────────────┘ └─────────────┘ └─────────────┘ └──────────────┘│
├─────────────────────────────────────────────────────────────────┤
│                    Kubernetes Layer (K3s)                      │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                Control Plane (Single Node)                 │ │
│  │                        Port 6443                           │ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌──────────────┐│
│  │   Traefik   │ │   CoreDNS   │ │ Local Path  │ │   Metrics    ││
│  │   Ingress   │ │     DNS     │ │ Provisioner │ │   Server     ││
│  └─────────────┘ └─────────────┘ └─────────────┘ └──────────────┘│
├─────────────────────────────────────────────────────────────────┤
│                      GitOps Layer (Flux)                       │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Flux Controllers                        │ │
│  │  Source │ Kustomize │ Helm │ Image │ Notification │ Image   │ │
│  │  Controller │ Controller │ Controller │ Reflector │ Controller │ Controller │ │
│  └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                    Application Namespaces                      │
│  ┌───────────────┐ ┌─────────────┐ ┌─────────────┐ ┌──────────┐ │
│  │   default     │ │   kafka     │ │ monitoring  │ │cert-mgr  │ │
│  │   ├─API GW    │ │ ├─Strimzi    │ │├─Prometheus │ │├─Cert    │ │
│  │   ├─API Gen   │ │ ├─Zookeeper  │ │├─Grafana   │ ││Manager  │ │
│  │   └─API Enr   │ │ └─Kafka     │ │├─Loki      │ │└─Let's   │ │
│  │               │ │             │ │└─Alert Mgr │ │Encrypt  │ │
│  └───────────────┘ └─────────────┘ └─────────────┘ └──────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Composants principaux

### 1. Infrastructure de base
- **Hyperviseur**: QEMU/KVM avec Guest Agent
- **OS**: Ubuntu 24.10 avec kernel 6.11.0-19-generic
- **Réseau**: systemd-networkd avec DNS résolu par systemd-resolved
- **Sécurité**: UFW firewall + Fail2Ban

### 2. Orchestration Kubernetes
- **Distribution**: K3s v1.28.5
- **Mode**: Single-node control-plane/master
- **Runtime**: containerd 1.7.11-k3s2
- **Ingress**: Traefik intégré
- **Storage**: Local Path Provisioner

### 3. GitOps et CI/CD
- **GitOps**: Flux v2 (tous les contrôleurs activés)
- **CI/CD**: GitHub Actions avec automatisation d'images
- **Sécurité**: SOPS-Age pour le chiffrement des secrets
- **Source**: Repository GitHub avec structure GitOps

### 4. Applications métier
- **API Gateway**: Service d'entrée et routage
- **API Generation**: Service de génération de contenu
- **API Enrichment**: Service d'enrichissement de données
- **Communication**: Apache Kafka via Strimzi Operator

### 5. Observabilité
- **Métriques**: Prometheus + Node Exporter + Kube State Metrics
- **Logs**: Loki + Promtail
- **Visualisation**: Grafana
- **Alerting**: AlertManager

### 6. Gestion des certificats
- **Provider**: cert-manager avec Let's Encrypt
- **Environnements**: Staging et Production
- **Automatisation**: Renouvellement automatique

## Flux de données

```
Internet → UFW (ports 80,443,22,6443) → Traefik → Services K8s
                                      ↓
GitHub → Flux GitOps → Kubernetes Resources → Applications
                                      ↓
Applications → Kafka → Data Processing → Metrics/Logs → Monitoring
```

## Points de haute disponibilité

### Avantages
- **Automatisation complète**: GitOps avec Flux
- **Monitoring complet**: Stack Prometheus/Grafana/Loki
- **Sécurité**: Certificats automatiques, secrets chiffrés
- **Scalabilité**: HPA configuré sur toutes les applications

### Points d'attention
- **Single point of failure**: Configuration single-node
- **Ressources**: Monitoring actif nécessaire (actuellement 6GB/15.6GB utilisés)
- **Backup**: Stratégie de sauvegarde à définir
- **Disaster Recovery**: Plan de récupération à documenter

## Performances actuelles

- **CPU**: 16 cores AMD EPYC-Milan (utilisation optimale)
- **Mémoire**: 15.6 GB (6GB utilisés, 9.2GB disponibles)
- **Stockage**: 155GB (17GB utilisés, 138GB libres)
- **Réseau**: Bande passante selon offre Nova Clouds

## Évolutivité

L'architecture actuelle supporte:
- **Scaling horizontal**: via HPA Kubernetes
- **Ajout de nodes**: K3s supporte le multi-node
- **Nouveaux services**: via GitOps automatisé
- **Monitoring avancé**: Stack complète déjà en place
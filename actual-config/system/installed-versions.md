# Versions Installées (2025-08-15)

## Système
- OS: Ubuntu 24.10
- Kernel: 6.11.0-19-generic  
- Architecture: amd64

## Kubernetes & Container Runtime
- K3s: v1.28.5+k3s1
- containerd: 1.7.11-k3s2
- Node: vps-6227e9e1 (control-plane,master)

## GitOps & Automation
- Flux: v2.2.2
- SOPS: v3.8.1 (avec age v1.1.1)

## Kafka & Streaming  
- Strimzi Operator: 0.43.0
- Kafka: 3.7.0
- Zookeeper: inclus avec Kafka

## Monitoring Stack
- Prometheus Operator
- Grafana
- Loki + Promtail
- AlertManager

## Outils de sécurité
- cert-manager (Let's Encrypt)
- UFW Firewall activé
- RBAC Kubernetes activé

## Images des microservices
- api-gateway: ghcr.io/team-mercurious/api-gateway:latest
- api-generation: ghcr.io/team-mercurious/api-generation:latest
- api-enrichment: ghcr.io/team-mercurious/api-enrichment:latest

Toutes ces versions sont FONCTIONNELLES au moment de l'archive.
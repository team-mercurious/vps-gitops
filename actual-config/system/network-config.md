# Configuration Réseau Actuelle

## Adresse IP publique
- IP: 37.59.98.241
- Hébergeur: OVH VPS

## Domaines configurés
- api2.gotravelyzer.com (API Gateway avec SSL)
- grafana.gotravelyzer.com (Monitoring avec SSL)
- prometheus.gotravelyzer.com (Monitoring avec SSL)

## Ports exposés (UFW)
- 22/tcp: SSH
- 80/tcp: HTTP (redirigé vers HTTPS)
- 443/tcp: HTTPS
- 6443/tcp: Kubernetes API Server

## Services internes Kubernetes
- Cluster CIDR: 10.43.0.0/16
- Service DNS: coredns
- Load Balancer: Traefik (intégré K3s)

## Ingress Controller
- Traefik v2 (inclus avec K3s)
- Let's Encrypt automatique via cert-manager
- Redirection HTTP vers HTTPS activée

## Kafka Network
- Service interne: mercurious-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
- Port SASL/PLAINTEXT: 9092
- Port SASL/TLS: 9093
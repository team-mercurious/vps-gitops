# Configuration Réseau - DNS, Routing et Connectivité

## Configuration réseau système

### Interface réseau principale
**Gestion**: systemd-networkd
```bash
# Status interfaces
ip addr show

# Configuration DHCP automatique
# Pas de configuration statique nécessaire (Nova Clouds DHCP)
```

### Adresse IP publique
- **IP publique**: 37.59.98.241 (via Nova Clouds)
- **Interface**: Assignation automatique DHCP
- **IPv6**: Supporté (configuration automatique)

### DNS Configuration

#### systemd-resolved
**Service**: systemd-resolved (actif)
**Configuration**: `/etc/systemd/resolved.conf`

```ini
[Resolve]
DNS=127.0.0.53
FallbackDNS=1.1.1.1 8.8.8.8
Domains=~.
DNSSEC=yes
DNSOverTLS=no
Cache=yes
ReadEtcHosts=yes
```

**Ports d'écoute DNS**:
- `127.0.0.53:53` - systemd-resolved (système)
- `127.0.0.54:53` - systemd-resolved (backup)

#### Configuration actuelle
```bash
# Vérification résolution DNS
resolvectl status

# Test résolution
nslookup google.com
dig @127.0.0.53 kubernetes.io
```

## Routage et connectivité

### Table de routage
```bash
# Routes système
ip route show
# Default via Nova Clouds gateway
# Local network routes automatiques
```

### Connectivité externe
**Tests standards**:
```bash
# Connectivité internet
ping -c 4 8.8.8.8

# Résolution DNS
nslookup google.com

# HTTPS connectivity
curl -I https://google.com
```

## Configuration Kubernetes réseau

### CNI Plugin (K3s intégré)
**Plugin**: Flannel (intégré K3s)
**CIDR Pod**: 10.42.0.0/16 (par défaut K3s)
**CIDR Service**: 10.43.0.0/16 (par défaut K3s)

### Services réseau Kubernetes

#### CoreDNS (DNS interne cluster)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: 10.43.0.10
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP
```

**Configuration DNS pods**:
- `.cluster.local` - Services Kubernetes internes
- `.svc.cluster.local` - Services par namespace
- Forward vers systemd-resolved pour external

#### Service LoadBalancer (Traefik)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: traefik
  namespace: kube-system
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: traefik
  ports:
  - name: web
    port: 80
    targetPort: 8000
    protocol: TCP
  - name: websecure
    port: 443
    targetPort: 8443
    protocol: TCP
```

### Ingress et exposition services

#### Traefik Configuration
**Ports d'écoute**:
- `:80` - HTTP (redirection HTTPS automatique)
- `:443` - HTTPS (terminaison TLS)
- `:8080` - Dashboard (localhost seulement)

**Ingress Rules exemple**:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway
  annotations:
    traefik.ingress.kubernetes.io/router.tls: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  rules:
  - host: api.domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 80
  tls:
  - hosts:
    - api.domain.com
    secretName: api-gateway-tls
```

## Configuration monitoring réseau

### Exposition métriques
**Node Exporter**: Port 9100 (exposé publiquement)
```yaml
# Service pour métriques système
apiVersion: v1
kind: Service
metadata:
  name: node-exporter
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: node-exporter
  ports:
  - port: 9100
    targetPort: 9100
    nodePort: 9100
```

### Métriques réseau disponibles
- **Interface stats**: RX/TX bytes, packets, errors
- **TCP connections**: Established, listening ports
- **DNS performance**: Resolution time, failures
- **Load balancer**: Request rate, response time

## Inter-service communication

### Communication interne Kubernetes
**Pattern**: Service discovery via DNS
```yaml
# Communication entre services
http://api-generation.default.svc.cluster.local:80
http://kafka-bootstrap.kafka.svc.cluster.local:9092
```

### Kafka networking
**Broker**: Port 9092 interne cluster
**Configuration**:
```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: mercurious-cluster
spec:
  kafka:
    listeners:
    - name: plain
      port: 9092
      type: internal
      tls: false
    - name: tls
      port: 9093
      type: internal
      tls: true
```

**Topics et partitions**:
- Communication async entre microservices
- Réplication factor: 1 (single broker)
- Retention: 7 jours par défaut

## Network Policies et sécurité

### Isolation réseau par namespace
```yaml
# Politique par défaut - deny all
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

### Autorisations spécifiques
```yaml
# Permettre accès à Kafka depuis apps
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-kafka-access
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: api-gateway
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kafka
    ports:
    - protocol: TCP
      port: 9092
```

### Monitoring network policies
```yaml
# Permettre Prometheus scraping
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080  # metrics port
```

## Load balancing et haute disponibilité

### Traefik Load Balancing
**Algorithmes disponibles**:
- Round Robin (défaut)
- Weighted Round Robin
- IP Hash (session affinity)

**Configuration service**:
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: api-gateway-route
spec:
  entryPoints:
  - websecure
  routes:
  - match: Host(`api.domain.com`)
    kind: Rule
    services:
    - name: api-gateway
      port: 80
      strategy: RoundRobin
      weight: 100
```

### Kubernetes Service Load Balancing
**sessionAffinity**: ClientIP pour services stateful
```yaml
apiVersion: v1
kind: Service
metadata:
  name: api-generation
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800
```

## Troubleshooting réseau

### Diagnostics système
```bash
# Interfaces et IPs
ip addr show
ip route show

# Ports d'écoute
ss -tlnp

# Connectivité
ping 8.8.8.8
traceroute google.com

# DNS
nslookup domain.com
dig @127.0.0.53 kubernetes.io
```

### Diagnostics Kubernetes
```bash
# Services et endpoints
kubectl get svc -A
kubectl get endpoints -A

# Network policies
kubectl get networkpolicies -A

# Ingress status
kubectl get ingress -A
kubectl describe ingress api-gateway

# DNS cluster
kubectl exec -it test-pod -- nslookup kubernetes.default
```

### Logs réseau
```bash
# Traefik access logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik

# CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# System network logs
journalctl -u systemd-networkd
journalctl -u systemd-resolved
```

### Tests de connectivité
```bash
# Pod to pod
kubectl run test-pod --image=busybox --rm -it -- sh
# Dans le pod:
wget -qO- api-gateway.default.svc.cluster.local

# External connectivity
kubectl run test-external --image=busybox --rm -it -- sh
# Dans le pod:
wget -qO- https://google.com
```

## Performance réseau

### Métriques importantes
- **Latency**: RTT entre services < 1ms (local)
- **Throughput**: Bande passante Nova Clouds
- **Packet loss**: Monitoring via Prometheus
- **Connection pooling**: Applications optimisées

### Optimisations
- **Keep-alive**: Connexions HTTP réutilisées
- **Connection pooling**: Pools de connexions DB/Kafka
- **DNS caching**: systemd-resolved + CoreDNS
- **Service mesh**: Istio/Linkerd (futur upgrade)

## Configuration domaines

### DNS externe (à configurer)
```dns
# Records A pour services exposés
api.domain.com    IN  A   37.59.98.241
grafana.domain.com IN  A   37.59.98.241
*.domain.com      IN  A   37.59.98.241  # Wildcard

# Records AAAA pour IPv6 (si disponible)
api.domain.com    IN  AAAA  [IPv6_address]
```

### Certificats Let's Encrypt
**Validation**: HTTP-01 via Traefik
**Renouvellement**: Automatique 60 jours avant expiration
**Backup**: Secrets stockés dans etcd cluster
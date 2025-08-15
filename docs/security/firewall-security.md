# Sécurité et Firewall - Configuration UFW et Fail2Ban

## Configuration UFW (Uncomplicated Firewall)

### Status actuel
```bash
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere                  
80/tcp                     ALLOW       Anywhere                  
443/tcp                    ALLOW       Anywhere                  
6443/tcp                   ALLOW       Anywhere                  
22/tcp (v6)                ALLOW       Anywhere (v6)             
80/tcp (v6)                ALLOW       Anywhere (v6)             
443/tcp (v6)               ALLOW       Anywhere (v6)             
6443/tcp (v6)              ALLOW       Anywhere (v6)
```

### Ports autorisés et justifications

#### Port 22 (SSH)
- **Service**: OpenSSH Server
- **Justification**: Administration système distante
- **Sécurité**: Fail2Ban actif pour protection brute-force
- **Recommandations**: 
  - Clés SSH seulement (désactiver password auth)
  - Changer le port par défaut si besoin
  - Limiter par IP source si possible

#### Port 80 (HTTP)
- **Service**: Traefik Ingress (redirection HTTPS)
- **Justification**: Redirection automatique vers HTTPS
- **Sécurité**: Certificats Let's Encrypt automatiques
- **Configuration**: Traefik redirige tout le trafic vers 443

#### Port 443 (HTTPS)
- **Service**: Traefik Ingress (terminaison TLS)
- **Justification**: Applications web sécurisées
- **Sécurité**: Certificats TLS valides, chiffrement fort
- **Applications exposées**:
  - API Gateway
  - Grafana (monitoring)
  - Autres services selon configuration

#### Port 6443 (Kubernetes API)
- **Service**: K3s API Server
- **Justification**: Accès kubectl/administration K8s
- **Sécurité**: Authentification par certificat client
- **Risques**: Port sensible - accès admin cluster
- **Recommandations**:
  - VPN ou bastion host pour accès externe
  - Audit des connexions API
  - RBAC strict configuré

### Configuration avancée UFW

#### Règles par défaut
```bash
# Politique par défaut
ufw default deny incoming
ufw default allow outgoing
ufw default deny forward
```

#### Logging
```bash
# Activer logs détaillés
sudo ufw logging on
sudo ufw logging medium

# Logs disponibles dans
tail -f /var/log/ufw.log
```

#### Protection DDoS basique
```bash
# Limiter connexions SSH
sudo ufw limit ssh

# Limiter connexions HTTP
sudo ufw limit 80/tcp
sudo ufw limit 443/tcp
```

## Configuration Fail2Ban

### Status et jails actives
```bash
# Vérifier status
sudo fail2ban-client status

# Jails configurées
sudo fail2ban-client status sshd
```

### Configuration SSH jail
```ini
# /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
ignoreip = 127.0.0.1/8 ::1
```

### Jails recommandées supplémentaires

#### Traefik (HTTP/HTTPS)
```ini
[traefik-auth]
enabled = true
port = http,https
filter = traefik-auth
logpath = /var/log/traefik/access.log
maxretry = 5
bantime = 7200
findtime = 300
```

#### Kubernetes API
```ini
[k3s-api]
enabled = true
port = 6443
filter = k3s-api
logpath = /var/log/audit/audit.log
maxretry = 3
bantime = 86400
findtime = 600
```

### Monitoring Fail2Ban
```bash
# IPs bannies actuellement
sudo fail2ban-client status sshd

# Débannir une IP
sudo fail2ban-client set sshd unbanip IP_ADDRESS

# Logs fail2ban
sudo tail -f /var/log/fail2ban.log
```

## Sécurité réseau

### Ports en écoute
```bash
State  Recv-Q Send-Q Local Address:Port  Peer Address:Port
LISTEN 0      65535      127.0.0.1:8080       0.0.0.0:*     # kubectl proxy
LISTEN 0      65535      127.0.0.1:6444       0.0.0.0:*     # K3s internal
LISTEN 0      65535  127.0.0.53%lo:53         0.0.0.0:*     # systemd-resolved
LISTEN 0      65535        0.0.0.0:22         0.0.0.0:*     # SSH
LISTEN 0      65535              *:6443             *:*     # K3s API
LISTEN 0      65535              *:9100             *:*     # Node Exporter
LISTEN 0      65535              *:10250            *:*     # kubelet
```

### Services internes seulement
- **127.0.0.1:8080**: kubectl proxy (administration locale)
- **127.0.0.1:6444**: K3s supervisor (internal)
- **127.0.0.53:53**: DNS résolution système
- **Ports 10xxx**: Services Kubernetes internes

### Services exposés
- **:22**: SSH (administration)
- **:6443**: Kubernetes API (gestion cluster)
- **:9100**: Node Exporter (métriques système)
- **:10250**: kubelet (métriques pods)

## Sécurité Kubernetes

### Network Policies
```yaml
# Isolation par défaut
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### RBAC Configuration
```yaml
# Service account apps avec permissions limitées
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-gateway
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: api-gateway-role
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
```

### Pod Security Standards
```yaml
# Namespace avec restriction
apiVersion: v1
kind: Namespace
metadata:
  name: default
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## Certificats et TLS

### Let's Encrypt Configuration
```yaml
# Issuer production
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@domain.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
```

### Rotation automatique
- **Renouvellement**: 60 jours avant expiration
- **Validation**: HTTP-01 challenge via Traefik
- **Backup**: Secrets stockés dans etcd K3s

## Surveillance sécurité

### Logs système importants
```bash
# Connexions SSH
sudo grep "sshd" /var/log/auth.log | tail -20

# Tentatives de connexion
sudo grep "Failed password" /var/log/auth.log

# UFW blocks
sudo grep "UFW BLOCK" /var/log/ufw.log

# Fail2ban actions
sudo grep "Ban\|Unban" /var/log/fail2ban.log
```

### Métriques sécurité dans Prometheus
- **Failed SSH attempts**: Via node_exporter
- **Firewall drops**: Logs parsés par Promtail
- **Certificate expiry**: cert-manager metrics
- **API access**: Kubernetes audit logs

### Alertes configurées
- SSH brute force détecté
- Certificats expirant < 7 jours
- Pods non-conformes pod security
- Accès API non autorisé

## Bonnes pratiques sécurité

### Système
- **Updates automatiques**: Activées (unattended-upgrades)
- **Kernel**: À jour (reboot nécessaire pour 6.11.0-29)
- **Services**: Minimum nécessaire
- **Audit**: Logs centralisés dans Loki

### Kubernetes
- **Images**: Scanning de vulnérabilités
- **Secrets**: Chiffrés avec SOPS-Age
- **RBAC**: Principe du moindre privilège
- **Network**: Isolation entre namespaces

### Applications
- **Ingress**: TLS terminaison obligatoire
- **Communication**: Service mesh (futur)
- **Secrets**: Rotation automatique
- **Monitoring**: APM et tracing

## Incident Response

### Compromission suspectée
1. **Isolation**: Bloquer IP source (UFW/Fail2Ban)
2. **Investigation**: Analyser logs (journalctl, Loki)
3. **Containment**: Arrêter services compromis
4. **Recovery**: Restaurer depuis backup/Git

### Procédures d'urgence
```bash
# Bloquer toutes les connexions
sudo ufw default deny incoming
sudo ufw default deny outgoing

# Arrêt d'urgence K3s
sudo systemctl stop k3s

# Mode rescue SSH seulement
sudo ufw allow 22
sudo ufw enable
```

### Contact et escalation
- **Admin système**: [contact]
- **Hébergeur**: Nova Clouds support
- **Incident**: Documentation dans docs/incidents/
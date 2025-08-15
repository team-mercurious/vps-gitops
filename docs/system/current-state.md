# État actuel du système

**Dernière mise à jour:** 2025-08-13 14:00 UTC

## Performance en temps réel

### Charge système
- **Load Average:** 0.09, 0.28, 0.16 (excellent)
- **CPU Usage:** Très faible utilisation
- **Uptime:** 26 minutes (depuis dernier redémarrage)

### Utilisation mémoire
- **RAM utilisée:** 5.6% (excellente disponibilité)
- **RAM libre:** ~14.7GB
- **Buffers/Cache:** ~1GB
- **Swap:** Non utilisé (non configuré)

### Stockage
- **Utilisation disque racine:** 2% (2.3GB/155GB)
- **Espace libre:** 152GB
- **Inodes libres:** Excellent

### Réseau
- **Connexions actives:** 8
- **Ports en écoute:** SSH (22), services système
- **Trafic:** Normal

## Services actifs

### Services système essentiels (19 actifs)
- systemd-* (journald, networkd, resolved, timesyncd, etc.)
- ssh.service (OpenSSH)
- cron.service
- rsyslog.service
- fail2ban.service ✅

### Services de sécurité
- **fail2ban:** ✅ Actif
  - IPs actuellement bannies: 1 (185.93.89.4)
  - Total des tentatives bloquées: 38 dernière heure
- **ufw:** ✅ Actif
  - Politique par défaut: DENY incoming, ALLOW outgoing
  - SSH autorisé

### Services de monitoring
- **qemu-guest-agent:** ✅ Actif
- **vps-monitor:** ✅ Script configuré (cron toutes les 6h)

## État de sécurité

### SSH
- **Service:** ✅ Actif sur port 22
- **Authentification:** Mot de passe + clés publiques
- **Protection:** fail2ban configuré (bantime: 1h)
- **Tentatives récentes:** 38 échecs bloqués

### Firewall
- **UFW Status:** ✅ Enabled
- **Règles actives:**
  - DENY incoming (par défaut)
  - ALLOW outgoing (par défaut)  
  - ALLOW SSH (port 22)

### Mises à jour
- **Dernière mise à jour:** 2025-08-13 13:57 UTC
- **Packages mis à jour:** 134 packages + nouveau kernel
- **Redémarrage requis:** Oui (nouveau kernel en attente)

## Utilisateurs

- **Root:** Accès limité (prohibit-password)
- **ubuntu (UID 1000):** Utilisateur principal avec sudo
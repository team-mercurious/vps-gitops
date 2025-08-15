# Guide de maintenance VPS

**Dernière mise à jour:** 2025-08-13 14:00 UTC

## Vue d'ensemble

Ce guide contient toutes les procédures de maintenance régulière pour maintenir le VPS en parfait état de fonctionnement.

## Monitoring automatique

### Script principal
**Emplacement:** `/usr/local/bin/vps-monitor`  
**Fréquence:** Toutes les 6 heures  
**Log:** `/var/log/vps-performance.log`

### Métriques surveillées
- Load average (charge CPU)
- Utilisation mémoire (%)
- Utilisation disque (%)
- Connexions réseau actives
- Tentatives SSH échouées

### Visualiser les rapports
```bash
# Dernier rapport
/usr/local/bin/vps-monitor

# Historique des rapports
cat /var/log/vps-performance.log

# Rapports des 24 dernières heures
tail -50 /var/log/vps-performance.log
```

## Maintenance quotidienne

### Vérifications automatiques (via cron)
- ✅ **Monitoring système** : Toutes les 6h
- ✅ **Rotation logs** : Quotidienne (logrotate)
- ✅ **fail2ban** : Surveillance continue
- ✅ **Mises à jour sécurité** : unattended-upgrades

### Actions manuelles (optionnelles)
```bash
# Vérifier état général
systemctl status

# Vérifier espace disque
df -h

# Vérifier mémoire
free -h

# Vérifier charge système
uptime
```

## Maintenance hebdomadaire

### Vérifications recommandées

1. **Logs de sécurité**
```bash
# Tentatives SSH de la semaine
grep "Failed password" /var/log/auth.log | wc -l

# IPs bannies
sudo fail2ban-client status sshd
```

2. **Performance système**
```bash
# Analyser tendances performance
tail -100 /var/log/vps-performance.log | grep "Load Average"
```

3. **Services critiques**
```bash
# Vérifier services essentiels
systemctl is-active ssh fail2ban ufw systemd-resolved
```

## Maintenance mensuelle

### 1. Mises à jour système
```bash
# Mise à jour complète
sudo apt update
sudo apt list --upgradable
sudo apt upgrade -y
sudo apt autoremove -y
sudo apt autoclean
```

### 2. Nettoyage système
```bash
# Nettoyer logs anciens (déjà configuré mais vérification)
sudo journalctl --vacuum-time=30d

# Nettoyer cache
sudo apt clean

# Vérifier fichiers temporaires volumineux
sudo find /tmp -size +100M -ls
sudo find /var/log -name "*.log" -size +100M -ls
```

### 3. Vérification sécurité
```bash
# Audit des connexions récentes
last | head -20

# Vérifier packages installés récemment
grep " install " /var/log/apt/history.log | tail -10

# État firewall
sudo ufw status verbose
```

## Maintenance trimestrielle

### 1. Audit complet sécurité
```bash
# Installer lynis pour audit (optionnel)
sudo apt install lynis
sudo lynis audit system
```

### 2. Optimisation performance
```bash
# Analyser tendances long terme
head -1000 /var/log/vps-performance.log | grep "Memory Usage"

# Vérifier paramètres kernel
sysctl vm.swappiness vm.dirty_ratio vm.vfs_cache_pressure
```

### 3. Planification capacité
- Analyser croissance utilisation disque
- Évaluer performance moyenne
- Planifier upgrades si nécessaire

## Procedures d'urgence

### Système à court d'espace disque
```bash
# Identifier gros fichiers
sudo du -sh /var/* | sort -hr | head -10
sudo du -sh /home/* | sort -hr | head -10

# Nettoyage d'urgence
sudo journalctl --vacuum-size=100M
sudo apt clean
sudo find /tmp -type f -mtime +1 -delete
```

### Charge système élevée
```bash
# Identifier processus consommateurs
top -o %CPU
ps aux --sort=-%cpu | head -10

# Analyser I/O
iostat -x 1 5  # Si disponible
```

### Attaque réseau détectée
```bash
# Voir connexions actives
ss -tuln | grep :22
netstat -an | grep :22

# Bannir IP massivement (fail2ban)
sudo fail2ban-client set sshd banip ATTACKER_IP

# Bloquer temporairement tout SSH sauf IP spécifique
sudo ufw deny 22
sudo ufw allow from YOUR_IP to any port 22
```

## Sauvegardes (à implémenter)

### Données critiques à sauvegarder
- **Configuration système:** `/etc/`
- **Logs importants:** `/var/log/`
- **Données utilisateur:** `/home/`
- **Documentation:** `/home/ubuntu/docs/`

### Script de sauvegarde suggéré
```bash
#!/bin/bash
# À créer : /usr/local/bin/backup-vps
DATE=$(date +%Y%m%d_%H%M%S)
tar -czf /tmp/vps-backup-${DATE}.tar.gz \
  /etc/ \
  /home/ubuntu/ \
  /var/log/ \
  --exclude=/var/log/*.gz
```

## Alertes et notifications

### Seuils d'alerte recommandés
- **CPU Load:** > 8 (50% des cores)
- **Mémoire:** > 85%
- **Disque:** > 90%
- **SSH échecs:** > 100/heure

### Configuration d'alertes (à implémenter)
```bash
# Script d'alerte simple (exemple)
#!/bin/bash
LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | awk '{ print $1 }' | sed 's/,//')
if (( $(echo "$LOAD > 8" | bc -l) )); then
    echo "ALERT: High load average $LOAD" | logger -t vps-alert
fi
```

## Checklist maintenance

### Quotidienne (automatique)
- [x] Monitoring système actif
- [x] Logs rotés
- [x] Sécurité SSH surveillée

### Hebdomadaire (manuelle - 10 min)
- [ ] Vérifier rapports monitoring
- [ ] Contrôler logs sécurité  
- [ ] Valider services critiques

### Mensuelle (manuelle - 30 min)
- [ ] Mise à jour système complète
- [ ] Nettoyage fichiers temporaires
- [ ] Audit sécurité basique
- [ ] Vérification tendances performance

### Trimestrielle (manuelle - 1h)
- [ ] Audit sécurité complet
- [ ] Optimisation configuration
- [ ] Planification capacité
- [ ] Mise à jour documentation

## Contacts et ressources

- **Documentation locale:** `/home/ubuntu/docs/`
- **Logs système:** `journalctl`, `/var/log/`
- **Monitoring:** `/var/log/vps-performance.log`
- **Scripts maintenance:** `/usr/local/bin/vps-monitor`
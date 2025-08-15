# Configuration de sécurité

**Dernière mise à jour:** 2025-08-13 14:00 UTC

## Vue d'ensemble

Le VPS est sécurisé avec une approche multicouche :
- Protection SSH avec fail2ban
- Firewall UFW configuré 
- Système maintenu à jour
- Monitoring des intrusions

## SSH Security

### Configuration actuelle
- **Port:** 22 (standard)
- **Authentification:** Mot de passe + clés publiques
- **Root login:** `prohibit-password` (sécurisé)
- **Max auth tries:** 6 (par défaut)

### Protection fail2ban

**Service:** ✅ Actif et configuré  
**Fichier config:** `/etc/fail2ban/jail.local`

```ini
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3        # 3 tentatives max
bantime = 3600      # Ban 1 heure  
findtime = 600      # Fenêtre 10 min
```

### Statistiques de protection

**État actuel (2025-08-13 14:00):**
- IPs bannies actuellement: 1
- IP bannie: 185.93.89.4
- Tentatives bloquées (dernière heure): 38
- Total échecs détectés: 8

### Logs de sécurité

**Localisation:** `/var/log/auth.log`  
**Rotation:** Configurée (weekly, 4 semaines)

**Commandes utiles:**
```bash
# Statut fail2ban
sudo fail2ban-client status sshd

# Voir IPs bannies
sudo fail2ban-client get sshd banip

# Débannir une IP
sudo fail2ban-client set sshd unbanip IP_ADDRESS

# Logs tentatives SSH
grep "Failed password" /var/log/auth.log | tail -20
```

## Firewall (UFW)

### Configuration actuelle
- **État:** ✅ Enabled
- **Politique par défaut:**
  - Incoming: DENY (tout bloqué)
  - Outgoing: ALLOW (tout autorisé)

### Règles actives
```bash
# Règles appliquées
ufw allow ssh        # SSH (port 22) autorisé
```

### Commandes utiles
```bash
# Statut firewall
sudo ufw status verbose

# Ajouter une règle
sudo ufw allow PORT_NUMBER

# Supprimer une règle  
sudo ufw delete allow PORT_NUMBER

# Bloquer une IP spécifique
sudo ufw deny from IP_ADDRESS
```

## Mises à jour sécuritaires

### Dernière mise à jour complète
- **Date:** 2025-08-13 13:57 UTC
- **Packages mis à jour:** 134
- **Mises à jour sécurité:** 87 LTS security updates
- **Nouveau kernel:** 6.11.0-29-generic

### Politique de mise à jour
- **Automatique:** unattended-upgrades configuré
- **Sécurité:** Mises à jour automatiques des patches de sécurité
- **Système:** Mise à jour manuelle mensuelle recommandée

### Commandes maintenance
```bash
# Vérifier mises à jour disponibles
apt list --upgradable

# Mise à jour sécurité seulement
sudo apt upgrade -s | grep -i security

# Mise à jour complète
sudo apt update && sudo apt upgrade -y
```

## Monitoring et alertes

### Script de monitoring sécurité
**Script:** `/usr/local/bin/vps-monitor`  
**Fréquence:** Toutes les 6h  
**Inclut:**
- Comptage tentatives SSH échouées
- Connexions actives
- État général système

### Logs à surveiller

1. **Auth logs:** `/var/log/auth.log`
   - Tentatives de connexion
   - Échecs d'authentification
   - Commandes sudo

2. **System logs:** `journalctl`
   - Erreurs système
   - Services qui échouent
   - Événements suspects

3. **Fail2ban logs:** `journalctl -u fail2ban`
   - Bannissements
   - Configuration
   - Erreurs de service

## Recommandations sécurité

### Immédiat ✅ (Déjà appliqué)
- [x] fail2ban configuré et actif
- [x] UFW firewall activé
- [x] Système à jour
- [x] Monitoring de base en place

### À court terme (optionnel)
- [ ] Configuration clés SSH uniquement (désactiver mot de passe)
- [ ] Changement port SSH (autre que 22)
- [ ] Configuration authentification 2FA
- [ ] Mise en place d'alertes email

### À moyen terme (selon usage)
- [ ] Audit sécurité complet avec lynis
- [ ] Configuration AppArmor/SELinux
- [ ] Certificats SSL/TLS si services web
- [ ] Sauvegarde chiffrée automatique

## Procédures d'urgence

### En cas d'intrusion suspectée
```bash
# 1. Vérifier connexions actives
who
ss -tulpn

# 2. Vérifier processus suspects
ps aux --sort=-%cpu

# 3. Bannir IP suspecte immédiatement
sudo ufw deny from SUSPICIOUS_IP

# 4. Analyser logs
sudo journalctl --since "1 hour ago" | grep -i error
grep "Failed password" /var/log/auth.log | tail -50
```

### Contact et escalation
- **Logs système:** Tout disponible localement
- **Monitoring:** Script vps-monitor actif
- **Support:** Documentation complète dans /home/ubuntu/docs/
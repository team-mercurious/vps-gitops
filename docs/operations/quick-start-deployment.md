# Guide de Démarrage Rapide - Déploiement Automatique

## 🚀 Déployez votre code en 3 étapes

### 1. Pushez votre code
```bash
git push origin main
```

### 2. Attendez (max 2 minutes)
Le système détecte et déploie automatiquement

### 3. Vérifiez votre déploiement
```bash
curl https://api2.gotravelyzer.com/
```

## 📊 Monitoring en temps réel

### Voir l'état général
```bash
/home/ubuntu/check-status.sh
```

### Suivre les déploiements en cours
```bash
tail -f /home/ubuntu/auto-deploy.log
```

### Vérifier les pods
```bash
kubectl get pods -w
```

## 🔧 Commandes utiles

### Déploiement manuel si nécessaire
```bash
kubectl set image deployment/api-gateway api-gateway=ghcr.io/team-mercurious/api-gateway:sha-VOTRE_SHA
```

### Rollback d'urgence
```bash
kubectl rollout undo deployment/api-gateway
```

### Vérifier l'historique
```bash
kubectl rollout history deployment/api-gateway
```

## ⚠️ En cas de problème

### Arrêter temporairement l'auto-deploy
```bash
crontab -e
# Commentez la ligne avec #
```

### Consulter la documentation complète
📖 [Guide complet du déploiement automatique](./automatic-deployment.md)

---
✅ **Votre système est opérationnel 24/7 !**
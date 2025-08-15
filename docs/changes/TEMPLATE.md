# Template de documentation des changements

**Date:** YYYY-MM-DD  
**Heure:** HH:MM UTC  
**Effectué par:** [Nom/Assistant]  
**Durée:** [Temps estimé]

## Objectif
[Description claire de ce qui doit être accompli]

## Contexte
[Pourquoi cette modification est nécessaire]

## Modifications planifiées
- [ ] Action 1
- [ ] Action 2  
- [ ] Action 3

## Pré-requis et vérifications
### Avant intervention
```bash
# Commandes à exécuter pour vérifier l'état initial
```

### Sauvegardes nécessaires
- [ ] Configuration X
- [ ] Données Y
- [ ] État système Z

## Étapes détaillées

### 1. [Nom de l'étape]
**Objectif:** [But de cette étape]

**Commandes:**
```bash
# Commandes exactes avec explications
```

**Vérification:**
```bash
# Comment vérifier que cette étape a réussi
```

**Rollback si échec:**
```bash
# Comment annuler cette étape si problème
```

### 2. [Étape suivante]
[Même structure...]

## Tests et validation
### Tests fonctionnels
- [ ] Test 1: [Description]
- [ ] Test 2: [Description]

### Tests de performance
- [ ] Vérifier charge système
- [ ] Vérifier mémoire
- [ ] Vérifier réseau

### Tests de sécurité
- [ ] Vérifier services exposés
- [ ] Vérifier logs de sécurité
- [ ] Tester fail2ban/firewall

## Résultats obtenus

### Métriques avant/après
| Métrique | Avant | Après | Amélioration |
|----------|-------|-------|--------------|
| [Métrique 1] | [Valeur] | [Valeur] | [%] |
| [Métrique 2] | [Valeur] | [Valeur] | [%] |

### Services impactés
- [Service 1]: [Impact]
- [Service 2]: [Impact]

### Fichiers modifiés
- `/path/to/file1`: [Description modification]
- `/path/to/file2`: [Description modification]

## Problèmes rencontrés
### Problème 1
**Description:** [Explication du problème]  
**Solution:** [Comment résolu]  
**Prévention:** [Comment éviter à l'avenir]

## Actions post-déploiement
- [ ] Monitoring pendant [durée]
- [ ] Vérification logs
- [ ] Mise à jour documentation
- [ ] Communication équipe

## Rollback complet (si nécessaire)
```bash
# Procédure complète pour annuler toutes les modifications
```

## Leçons apprises
- [Leçon 1]
- [Leçon 2]

## Prochaines étapes recommandées
- [ ] [Action future 1]
- [ ] [Action future 2]

---
**Documentation mise à jour:** [Date]  
**Fichiers mis à jour:**
- [Liste des fichiers de documentation modifiés]
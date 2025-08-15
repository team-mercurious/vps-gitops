# Spécifications VPS

## Informations générales

- **Provider:** Nova Clouds
- **Nom d'hôte:** vps-6227e9e1
- **Date de création documentation:** 2025-08-13
- **Dernière vérification:** 2025-08-13 13:58 UTC

## Ressources matérielles

### CPU
- **Processeurs:** 16 cores
- **Architecture:** x86_64 (Linux 6.11.0-19-generic)

### Mémoire
- **RAM totale:** 15.6 GB (15985112 kB)
- **Swap:** Non configuré (0B)
- **Utilisation typique:** ~5.5% (excellente disponibilité)

### Stockage
- **Disque principal:** /dev/sda1 - 155GB
- **Utilisation actuelle:** 2.3GB (2%)
- **Espace libre:** 152GB
- **Boot:** /dev/sda13 (989MB) - 7% utilisé
- **EFI:** /dev/sda15 (105MB) - 6% utilisé

## Système d'exploitation

- **Distribution:** Ubuntu 24.10 (Oracular)
- **Kernel actuel:** 6.11.0-19-generic
- **Kernel installé:** 6.11.0-29-generic (redémarrage nécessaire)
- **Architecture:** amd64

## Réseau

- **Interface:** Gérée par systemd-networkd
- **IPv4:** Configuration automatique
- **IPv6:** Supporté
- **DNS:** systemd-resolved

## Virtualisation

- **Type:** QEMU/KVM
- **Guest Agent:** Actif (qemu-guest-agent)
- **Outils VM:** open-vm-tools installé
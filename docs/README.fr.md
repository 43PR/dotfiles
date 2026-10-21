<div align="center">

## 43PR Desktop

Une configuration Hyprland simple et légère, axée sur la productivité, avec des raccourcis pratiques et facile à personnaliser.

![Hyprland](https://img.shields.io/badge/Hyprland-0.56.2-8b9aaf?style=for-the-badge&labelColor=101418)
[![Discord](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fdiscord.com%2Fapi%2Finvites%2FHQwU9SzHj%3Fwith_counts%3Dtrue&query=%24.approximate_member_count&style=for-the-badge&logo=discord&logoColor=ffffff&label=discord&labelColor=101418&color=7289a8)](https://discord.gg/HQwU9SzHj)
[![YouTube](https://img.shields.io/badge/youtube-subscribe-b05a63?style=for-the-badge&logo=youtube&logoColor=ffffff&labelColor=101418)](https://www.youtube.com/@43PR2)
[![Ko-Fi donate](https://img.shields.io/badge/donate-kofi?style=for-the-badge&logo=ko-fi&logoColor=ffffff&label=ko-fi&labelColor=101418&color=9a6570)](https://ko-fi.com/43pr)

### **[Fonctionnalités](#fonctionnalités)  -  [Raccourcis clavier](#raccourcis-clavier)  -  [Installation](#installation) -  [Mise à jour](#mise-à-jour)**

<p align="center">
  <sub>
    <a href="../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh-CN.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <b>Français</b> · <a href="README.de.md">Deutsch</a>
  </sub>
</p>

</div>

<img width="1920" height="1080" alt="1792462138" src="https://github.com/user-attachments/assets/10324a99-1038-431f-9f64-0183e2e04276" />

<details>
<summary><b>C'est quoi ? Débutant ?</b></summary>

### C'est quoi ?

Il s'agit d'une configuration de bureau complète et personnalisable pour Linux (barre, lanceur d'applications, paramètres, sélecteur de fonds d'écran, écran de verrouillage, menu d'alimentation, etc.). Elle repose sur **Hyprland** (gestionnaire de fenêtres) et **Quickshell** (ce qui sert à créer la barre et les menus).

### De quoi ai-je besoin ?

- Une **distribution Linux basée sur Arch** : Arch, CachyOS, EndeavourOS, Manjaro, etc.
- Une **installation majoritairement propre**. Les configurations existantes remplacées sont sauvegardées automatiquement.

Je recommande CachyOS aux débutants : https://youtu.be/eo9MejbzWto

Vous pouvez ignorer la partie configuration de la vidéo, elle est désormais automatisée. Lancez simplement la commande d'installation.

### Est-ce difficile à utiliser ?

Pas vraiment. Presque tout passe par un raccourci clavier, avec des alternatives à la souris :

- `Super + I` ouvre les paramètres - clic du milieu sur l'horloge

La liste complète se trouve dans [Raccourcis clavier](#raccourcis-clavier). Vous pouvez aussi survoler les éléments de la barre pour voir leurs actions, et faire un clic droit sur l'horloge pour ouvrir les paramètres de la barre.

### Que dois-je savoir avant d'installer ?

- Déconnectez-vous puis reconnectez-vous une fois l'installateur terminé.
- Les fonds d'écran ne sont pas inclus dans l'installation. Téléchargez-en quelques-uns et placez-les dans `Pictures/Wallpapers`.

### Quelque chose ne marche pas, où demander ?

Rejoignez le [Discord](https://discord.gg/HQwU9SzHj).

</details>

## Fonctionnalités

- **Quickshell rapide et léger** — Composants de bureau optimisés pour être rapides et faciles à personnaliser.
- **Barre supérieure** — Barre personnalisable avec menu des paramètres et raccourcis rapides.
- **Paramètres** — Système, réseau, bluetooth, affichage, audio, stockage, thèmes, et plus encore.
- **Sélecteur de fonds d'écran et couleurs dynamiques** — Sélecteur de fonds d'écran personnalisé avec génération automatique des couleurs à partir du fond d'écran.
- **Thèmes prédéfinis** — Monochrome, Nord, Tokyo Night et d'autres thèmes populaires, avec la possibilité de créer les vôtres.
- **Lanceur d'applications** — Recherche d'applications avec **Rofi**, historique du presse-papiers et contrôle de l'opacité.
- **Zsh + Starship** — Shell personnalisable avec autosuggestions et historique.
- **Notes et rappels** — Notes rapides, tâches et rappels.
- **Menu d'alimentation** — Menu d'alimentation personnalisable.
- **Hyprlock** — Écran de verrouillage personnalisé.
- **Spotify + Spicetify** — Thème personnalisé basé sur **text - darkthemer** (modifié).

> Tous les programmes: [packages.txt](../packages.txt)

### Sélecteur de fonds d'écran

Je n'y ai fait que quelques modifications. Montrez-lui un peu d'amour : [hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper)

## Raccourcis clavier

Faites un clic droit sur l'horloge pour ouvrir les paramètres de la barre. Survolez les éléments pour voir leurs actions. Pour fermer les composants, utilisez la touche Échap ou le même raccourci.

| Raccourci | Action |
| --- | --- |
| `Super + T` | Terminal |
| `Super + Q` | Fermer la fenêtre active |
| `Super + D` | Lanceur d'applications |
| `Super + Space` | Basculer en fenêtre flottante |
| `Super + F` | Basculer en plein écran |
| `Super + 1, 2, 3..` | Changer d'espace de travail |
| `Super + Shift + 1, 2..` | Déplacer la fenêtre vers un espace de travail |
| `Super + E` | Gestionnaire de fichiers |
| `Super + B` | Navigateur |
| `Super + V` | Historique du presse-papiers |
| `Super + I` | Menu des paramètres |
| `Super + S` | Actions rapides |
| `Super + O` | Changer l'opacité |
| `Super + C` | Notes et rappels |
| `Super + W` | Sélecteur de fonds d'écran |
| `Super + Shift + C` | Sélecteur de couleur |
| `Super + Molette de la souris` | Zoom avant/arrière |
| `Super + Shift + W` | Afficher/masquer la barre |
| `Super + Grave` | Menu de déconnexion |
| `Super + Tab` | Verrouiller l'écran |
| `Super + N` | Notifications |
| `Super + R` | Activer/désactiver l'enregistreur d'écran |
| `Delete` | Capture d'écran complète |
| `SHIFT + Delete` | Capture d'une zone sélectionnée |

> [!note]
>
> Déplacez et redimensionnez les fenêtres avec Super + glisser avec le bouton gauche/droit de la souris.
>
> Tous les raccourcis: [.config/hypr/keybinds.lua](../.config/hypr/keybinds.lua)

---
## Installation

**LISEZ TOUT**

Fonctionne sur Arch, CachyOS, EndeavourOS, Manjaro, etc.

Conçu principalement pour une installation propre (les fichiers de configuration existants qui sont remplacés seront sauvegardés automatiquement).

**Installez d'abord git, puis utilisez la commande suivante et poursuivez l'installation jusqu'à la fin**

```bash
sudo pacman -S git
```

```bash
git clone https://github.com/43PR/dotfiles.git
cd dotfiles
chmod +x install.sh
./install.sh
```

Une fois l'installation terminée, déconnectez-vous puis reconnectez-vous.

Téléchargez des fonds d'écran et placez-les dans Pictures/Wallpapers. Sélecteur de fonds d'écran : Super + W.

> [!important]
> **Ne déplacez pas et ne supprimez pas le dépôt dotfiles après l'installation.**
>
> Cette configuration utilise des **liens symboliques (symlinks)** qui pointent vers des fichiers à l'intérieur du dépôt cloné. Si vous déplacez ou supprimez le dépôt, ces liens seront rompus.
>
> Si vous déplacez le dépôt, exécutez simplement :
>
> ```bash
> ./install.sh
> ```
>
> L'installateur mettra automatiquement à jour les liens existants pour qu'ils pointent vers le nouvel emplacement.

---
## Mise à jour

Si vous n'avez pas déplacé le dossier du dépôt/dotfiles, exécutez :

```bash
cd dotfiles
git pull
./update.sh
```

Autres options : `--dry-run` (aperçu des changements), `--skip-packages`, `--skip-theme`.

Les dotfiles sont liés par symlinks, donc `git pull` met directement à jour vos configurations actives.

Vous pouvez consulter les rappels affichés à la fin de l'exécution.

> [!tip]
> Si des fichiers Quickshell (`.qml`) ont changé lors du pull, exécutez :
>
> ```bash
> ./update.sh --restart-shell
> ```
>
> pour redémarrer Quickshell automatiquement.

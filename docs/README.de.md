<div align="center">

## 43PR Desktop

Ein einfaches, leichtgewichtiges Hyprland-Setup mit Fokus auf Produktivität, praktischen Tastenkürzeln und einfacher Anpassbarkeit.

![Hyprland](https://img.shields.io/badge/Hyprland-0.56.2-8b9aaf?style=for-the-badge&labelColor=101418)
[![Discord](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fdiscord.com%2Fapi%2Finvites%2FHQwU9SzHj%3Fwith_counts%3Dtrue&query=%24.approximate_member_count&style=for-the-badge&logo=discord&logoColor=ffffff&label=discord&labelColor=101418&color=7289a8)](https://discord.gg/HQwU9SzHj)
[![YouTube](https://img.shields.io/badge/youtube-subscribe-b05a63?style=for-the-badge&logo=youtube&logoColor=ffffff&labelColor=101418)](https://www.youtube.com/@43PR2)
[![Ko-Fi donate](https://img.shields.io/badge/donate-kofi?style=for-the-badge&logo=ko-fi&logoColor=ffffff&label=ko-fi&labelColor=101418&color=9a6570)](https://ko-fi.com/43pr)

### **[Funktionen](#funktionen)  -  [Tastenkürzel](#tastenkürzel)  -  [Installation](#installation) -  [Aktualisieren](#aktualisieren)**

<p align="center">
  <sub>
    <a href="../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh-CN.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <b>Deutsch</b>
  </sub>
</p>

</div>

<img width="1920" height="1080" alt="1792462138" src="https://github.com/user-attachments/assets/10324a99-1038-431f-9f64-0183e2e04276" />

<details>
<summary><b>Was ist das? Anfänger?</b></summary>

### Was ist das?

Das ist ein vollständiges, anpassbares Desktop-Setup für Linux (Leiste, App-Starter, Einstellungen, Hintergrundbild-Auswahl, Sperrbildschirm, Ausschaltmenü usw.). Es basiert auf **Hyprland** (Fenstermanager) und **Quickshell** (damit werden die Leiste und die Menüs erstellt).

### Was brauche ich dafür?

- Eine **Arch-basierte Linux-Distribution**: Arch, CachyOS, EndeavourOS, Manjaro usw.
- Eine **weitgehend saubere Installation**. Bestehende Konfigurationen, die ersetzt werden, werden automatisch gesichert.

Für Anfänger empfehle ich CachyOS: https://youtu.be/eo9MejbzWto

Den Konfigurationsabschnitt des Videos kannst du überspringen, er ist jetzt automatisiert. Führe einfach den Installationsbefehl aus.

### Ist es schwer zu bedienen?

Nicht wirklich. Fast alles läuft über Tastenkürzel, mit Alternativen für die Maus:

- `Super + I` öffnet die Einstellungen - Mittelklick auf die Uhr

Die vollständige Liste findest du unter [Tastenkürzel](#tastenkürzel). Du kannst außerdem mit der Maus über Elemente der Leiste fahren, um ihre Aktionen zu sehen, und mit einem Rechtsklick auf die Uhr die Leisteneinstellungen öffnen.

### Was sollte ich vor der Installation wissen?

- Melde dich ab und wieder an, sobald der Installer fertig ist.
- Hintergrundbilder sind nicht in der Installation enthalten. Lade welche herunter und lege sie in `Pictures/Wallpapers` ab.

### Etwas funktioniert nicht, wo frage ich nach?

Tritt dem [Discord](https://discord.gg/HQwU9SzHj) bei.

</details>

## Funktionen

- **Schnelles & leichtgewichtiges Quickshell** — Optimierte Desktop-Komponenten, die schnell und leicht anpassbar sind.
- **Obere Leiste** — Anpassbare Leiste mit Einstellungsmenü und Schnellzugriffen.
- **Einstellungen** — System, Netzwerk, Bluetooth, Anzeige, Audio, Speicher, Themes und mehr.
- **Hintergrundbild-Auswahl & dynamische Farben** — Eigene Hintergrundbild-Auswahl mit automatischer Farbgenerierung aus dem Hintergrundbild.
- **Vorgefertigte Themes** — Monochrome, Nord, Tokyo Night und weitere beliebte Themes, mit Unterstützung für eigene.
- **App-Starter** — App-Suche mit **Rofi**, Zwischenablage-Verlauf und Deckkraft-Steuerung.
- **Zsh + Starship** — Anpassbare Shell mit Autovorschlägen und Verlauf.
- **Notizen & Erinnerungen** — Schnelle Notizen, Aufgaben und Erinnerungen.
- **Ausschaltmenü** — Anpassbares Ausschaltmenü.
- **Hyprlock** — Eigener Sperrbildschirm.
- **Spotify + Spicetify** — Eigenes Theme auf Basis von **text - darkthemer** (modifiziert).

> Alle Programme: [packages.txt](../packages.txt)

### Hintergrundbild-Auswahl

Ich habe nur ein paar Anpassungen daran vorgenommen. Gib ihm etwas Liebe: [hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper)

## Tastenkürzel

Klicke mit der rechten Maustaste auf die Uhr, um die Leisteneinstellungen zu öffnen. Fahre mit der Maus über Elemente, um Aktionen zu sehen. Zum Schließen von Komponenten drücke Esc oder verwende dasselbe Tastenkürzel.

| Tastenkürzel | Aktion |
| --- | --- |
| `Super + T` | Terminal |
| `Super + Q` | Aktives Fenster schließen |
| `Super + D` | App-Starter |
| `Super + Space` | Schwebendes Fenster umschalten |
| `Super + F` | Vollbild umschalten |
| `Super + 1, 2, 3..` | Arbeitsbereich wechseln |
| `Super + Shift + 1, 2..` | Fenster in Arbeitsbereich verschieben |
| `Super + E` | Dateimanager |
| `Super + B` | Browser |
| `Super + V` | Zwischenablage-Verlauf |
| `Super + I` | Einstellungsmenü |
| `Super + S` | Schnellaktionen |
| `Super + O` | Deckkraft wechseln |
| `Super + C` | Notizen & Erinnerungen |
| `Super + W` | Hintergrundbild-Auswahl |
| `Super + Shift + C` | Farbwähler |
| `Super + Mausrad` | Vergrößern/Verkleinern |
| `Super + Shift + W` | Leiste ein-/ausblenden |
| `Super + Grave` | Abmeldemenü |
| `Super + Tab` | Bildschirm sperren |
| `Super + N` | Benachrichtigungen |
| `Super + R` | Bildschirmaufnahme umschalten |
| `Delete` | Screenshot (Vollbild) |
| `SHIFT + Delete` | Screenshot (Bereich auswählen) |

> [!note]
>
> Verschiebe und ändere die Größe von Fenstern mit Super + Ziehen mit der linken/rechten Maustaste.
>
> Alle Tastenkürzel: [.config/hypr/keybinds.lua](../.config/hypr/keybinds.lua)

---
## Installation

**BITTE ALLES LESEN**

Funktioniert unter Arch, CachyOS, EndeavourOS, Manjaro usw.

Hauptsächlich für eine saubere Installation gedacht (bestehende Konfigurationsdateien, die ersetzt werden, werden automatisch gesichert).

**Installiere zuerst git, verwende dann den nächsten Befehl und setze die Installation fort, bis sie abgeschlossen ist**

```bash
sudo pacman -S git
```

```bash
git clone https://github.com/43PR/dotfiles.git
cd dotfiles
chmod +x install.sh
./install.sh
```

Melde dich nach Abschluss der Installation ab und wieder an.

Lade Hintergrundbilder herunter und verschiebe sie nach Pictures/Wallpapers. Hintergrundbild-Auswahl: Super + W.

> [!important]
> **Verschiebe oder lösche das dotfiles-Repository nach der Installation nicht.**
>
> Dieses Setup verwendet **symbolische Links (Symlinks)**, die auf Dateien im geklonten Repository zeigen. Wenn du das Repository verschiebst oder löschst, werden diese Links ungültig.
>
> Wenn du das Repository verschiebst, führe einfach Folgendes aus:
>
> ```bash
> ./install.sh
> ```
>
> Der Installer aktualisiert die bestehenden Symlinks automatisch, sodass sie auf den neuen Speicherort zeigen.

---
## Aktualisieren

Wenn du den Repository-/dotfiles-Ordner nicht verschoben hast, führe aus:

```bash
cd dotfiles
git pull
./update.sh
```

Weitere Optionen: `--dry-run` (Änderungen vorab anzeigen), `--skip-packages`, `--skip-theme`.

Die Dotfiles sind per Symlink verknüpft, daher aktualisiert `git pull` direkt deine aktiven Konfigurationen.

Am Ende des Durchlaufs kannst du die ausgegebenen Hinweise prüfen.

> [!tip]
> Wenn sich beim Pull Quickshell-Dateien (`.qml`) geändert haben, führe aus:
>
> ```bash
> ./update.sh --restart-shell
> ```
>
> um Quickshell automatisch neu zu starten.

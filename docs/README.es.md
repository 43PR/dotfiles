<div align="center">

## 43PR Desktop

Una configuración de Hyprland simple y ligera, enfocada en la productividad, con atajos prácticos y fácil de personalizar.

![Hyprland](https://img.shields.io/badge/Hyprland-0.56.2-8b9aaf?style=for-the-badge&labelColor=101418)
[![Discord](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fdiscord.com%2Fapi%2Finvites%2FHQwU9SzHj%3Fwith_counts%3Dtrue&query=%24.approximate_member_count&style=for-the-badge&logo=discord&logoColor=ffffff&label=discord&labelColor=101418&color=7289a8)](https://discord.gg/HQwU9SzHj)
[![YouTube](https://img.shields.io/badge/youtube-subscribe-b05a63?style=for-the-badge&logo=youtube&logoColor=ffffff&labelColor=101418)](https://www.youtube.com/@43PR2)
[![Ko-Fi donate](https://img.shields.io/badge/donate-kofi?style=for-the-badge&logo=ko-fi&logoColor=ffffff&label=ko-fi&labelColor=101418&color=9a6570)](https://ko-fi.com/43pr)

### **[Características](#características)  -  [Atajos](#atajos-de-teclado)  -  [Instalación](#instalación) -  [Actualización](#actualización)**

<p align="center">
  <sub>
    <a href="../README.md">English</a> · <b>Español</b> · <a href="README.ru.md">Русский</a> · <a href="README.zh-CN.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a>
  </sub>
</p>

</div>

<img width="1920" height="1080" alt="1792462138" src="https://github.com/user-attachments/assets/10324a99-1038-431f-9f64-0183e2e04276" />

<details>
<summary><b>¿Qué es esto? ¿Eres principiante?</b></summary>

### ¿Qué es esto?

Es una configuración de escritorio completa y personalizable para Linux (barra, lanzador de aplicaciones, ajustes, selector de fondos de pantalla, pantalla de bloqueo, menú de apagado, etc.). Está construida sobre **Hyprland** (gestor de ventanas) y **Quickshell** (con lo que se crean la barra y los menús).

### ¿Qué necesito para usarlo?

- Una **distribución de Linux basada en Arch**: Arch, CachyOS, EndeavourOS, Manjaro, etc.
- Una **instalación limpia** en su mayoría. Las configuraciones existentes que se reemplacen se respaldan automáticamente.

Recomiendo CachyOS para principiantes: https://youtu.be/eo9MejbzWto

Puedes saltarte la sección de configuración del video, ahora está automatizada. Solo ejecuta el comando de instalación.

### ¿Es difícil de usar?

No mucho. Casi todo es un atajo de teclado, con alternativas para el mouse:

- `Super + I` abre los ajustes - clic central en el reloj

La lista completa está en [Atajos de teclado](#atajos-de-teclado). También puedes pasar el cursor sobre los elementos de la barra para ver sus acciones, y hacer clic derecho en el reloj para abrir los ajustes de la barra.

### ¿Qué debo saber antes de instalar?

- Cierra sesión y vuelve a iniciarla cuando el instalador termine.
- Los fondos de pantalla no vienen incluidos en la instalación. Descarga algunos y colócalos en `Pictures/Wallpapers`.

### Algo falló, ¿dónde pregunto?

Únete al [Discord](https://discord.gg/HQwU9SzHj).

</details>

## Características

- **Quickshell rápido y ligero** — Componentes de escritorio optimizados para ser rápidos y fáciles de personalizar.
- **Barra superior** - Barra personalizable con menú de ajustes y accesos rápidos.
- **Ajustes** — Sistema, red, bluetooth, pantalla, audio, almacenamiento, temas y más.
- **Selector de fondos y colores dinámicos** — Selector de fondos de pantalla personalizado con generación automática de colores a partir del fondo.
- **Temas predefinidos** — Monochrome, Nord, Tokyo Night y otros populares, con soporte para crear los tuyos.
- **Lanzador de aplicaciones** — Búsqueda de aplicaciones con **Rofi**, historial del portapapeles y control de opacidad.
- **Zsh + Starship** — Shell personalizable con autosugerencias e historial.
- **Notas y recordatorios** — Notas rápidas, tareas y recordatorios.
- **Menú de apagado** — Menú de apagado personalizable.
- **Hyprlock** — Pantalla de bloqueo personalizada.
- **Spotify + Spicetify** — Tema personalizado basado en **text - darkthemer** (modificado).

> Todos los programas: [packages.txt](../packages.txt)

### Selector de fondos de pantalla

Le hice unos ajustes. Dale algo de cariño: [hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper)

## Atajos de teclado

Haz clic derecho en el reloj para abrir los ajustes de la barra. Pasa el cursor sobre los elementos para ver sus acciones. Para cerrar los componentes usa la tecla Esc o el mismo atajo.

| Atajo                   | Acción                           |
| -----------             | -------------------------------- |
| `Super + T`             | Terminal                         |
| `Super + Q`             | Cerrar la ventana activa         |
| `Super + D`             | Lanzador de aplicaciones         |
| `Super + Space`         | Alternar ventana flotante        |
| `Super + F`             | Alternar pantalla completa       |
| `Super + 1, 2, 3..`     | Cambiar de espacio de trabajo    |
| `Super + Shift + 1, 2..`| Mover ventana a otro espacio     |
| `Super + E`             | Gestor de archivos               |
| `Super + B`             | Navegador                        |
| `Super + V`             | Historial del portapapeles       |
| `Super + I`             | Menú de ajustes                  |
| `Super + S`             | Acciones rápidas                 |
| `Super + O`             | Cambiar opacidad                 |
| `Super + C`             | Notas y recordatorios            |
| `Super + W`             | Selector de fondos de pantalla   |
| `Super + Shift + C`     | Selector de color                |
| `Super + Rueda del mouse` | Acercar/alejar                 |
| `Super + Shift + W`     | Mostrar/ocultar la barra         |
| `Super + Grave`         | Menú de cierre de sesión         |
| `Super + Tab`           | Bloquear pantalla                |
| `Super + N`             | Notificaciones                   |
| `Super + R`             | Activar/desactivar grabador de pantalla |
| `Delete`                | Captura de pantalla completa     |
| `SHIFT + Delete`        | Captura de un área seleccionada  |

> [!note]
>
> Mueve y redimensiona ventanas con Super + arrastrar con el botón izquierdo/derecho del mouse.
>
> Todos los atajos: [.config/hypr/keybinds.lua](../.config/hypr/keybinds.lua)

---
## Instalación

**LEE TODO**

Funciona en Arch, CachyOS, EndeavourOS, Manjaro, etc.

Está pensado principalmente para una instalación limpia (los archivos de configuración existentes que se reemplacen se respaldarán automáticamente).

**Primero instala git, luego usa el siguiente comando y continúa con la instalación hasta que termine**

```bash
sudo pacman -S git   
```

```bash
git clone https://github.com/43PR/dotfiles.git
cd dotfiles
chmod +x install.sh
./install.sh
```

Cuando la instalación termine, cierra sesión y vuelve a iniciarla.

Descarga y mueve los fondos de pantalla a Pictures/Wallpapers. Selector de fondos: Super + W.

> [!important]
> **No muevas ni borres el repositorio dotfiles después de la instalación.**
>
> Esta configuración usa **enlaces simbólicos (symlinks)** que apuntan a archivos dentro del repositorio clonado. Si mueves o borras el repositorio, esos enlaces se romperán.
>
> Si cambias el repositorio de lugar, simplemente ejecuta:
>
> ```bash
> ./install.sh
> ```
>
> El instalador actualizará automáticamente los enlaces existentes para que apunten a la nueva ubicación.

---
## Actualización

Si no moviste la carpeta del repositorio/dotfiles, ejecuta:

```bash
cd dotfiles
git pull
./update.sh
```

Otras opciones: `--dry-run` (previsualizar cambios), `--skip-packages`, `--skip-theme`.

Los dotfiles están enlazados con symlinks, así que `git pull` actualiza directamente tus configuraciones activas.

Puedes revisar los recordatorios que se muestran al final de la ejecución.

> [!tip]
> Si algún archivo de Quickshell (`.qml`) cambió con el pull, ejecuta:
>
> ```bash
> ./update.sh --restart-shell
> ```
>
> para reiniciar Quickshell automáticamente.

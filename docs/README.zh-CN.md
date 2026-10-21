<div align="center">

## 43PR Desktop

一个简单、轻量的 Hyprland 配置，专注于效率、实用的快捷键，并且易于自定义。

![Hyprland](https://img.shields.io/badge/Hyprland-0.56.2-8b9aaf?style=for-the-badge&labelColor=101418)
[![Discord](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fdiscord.com%2Fapi%2Finvites%2FHQwU9SzHj%3Fwith_counts%3Dtrue&query=%24.approximate_member_count&style=for-the-badge&logo=discord&logoColor=ffffff&label=discord&labelColor=101418&color=7289a8)](https://discord.gg/HQwU9SzHj)
[![YouTube](https://img.shields.io/badge/youtube-subscribe-b05a63?style=for-the-badge&logo=youtube&logoColor=ffffff&labelColor=101418)](https://www.youtube.com/@43PR2)
[![Ko-Fi donate](https://img.shields.io/badge/donate-kofi?style=for-the-badge&logo=ko-fi&logoColor=ffffff&label=ko-fi&labelColor=101418&color=9a6570)](https://ko-fi.com/43pr)

### **[功能](#功能)  -  [快捷键](#快捷键)  -  [安装](#安装) -  [更新](#更新)**

<p align="center">
  <sub>
    <a href="../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <b>中文</b> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a>
  </sub>
</p>

</div>

<img width="1920" height="1080" alt="1792462138" src="https://github.com/user-attachments/assets/10324a99-1038-431f-9f64-0183e2e04276" />

<details>
<summary><b>这是什么？新手？</b></summary>

### 这是什么？

这是一套适用于 Linux 的完整、可自定义的桌面配置（状态栏、应用启动器、设置、壁纸选择器、锁屏、电源菜单等）。它基于 **Hyprland**（窗口管理器）和 **Quickshell**（用于构建状态栏和菜单）。

### 运行它需要什么？

- 一个**基于 Arch 的 Linux 发行版**：Arch、CachyOS、EndeavourOS、Manjaro 等。
- 尽量是**干净的系统安装**。被替换的现有配置会自动备份。

新手我推荐 CachyOS：https://youtu.be/eo9MejbzWto

视频中的配置部分可以跳过，现在已经自动化了。直接运行安装命令即可。

### 难用吗？

不难。几乎所有操作都有键盘快捷键，同时也有鼠标替代方式：

- `Super + I` 打开设置 - 鼠标中键点击时钟

完整列表见[快捷键](#快捷键)。你也可以把鼠标悬停在状态栏元素上查看其功能，右键点击时钟可打开状态栏设置。

### 安装前需要了解什么？

- 安装程序完成后，请注销并重新登录。
- 壁纸不包含在安装中。请自行下载一些壁纸并放到 `Pictures/Wallpapers`。

### 出问题了，去哪里提问？

加入 [Discord](https://discord.gg/HQwU9SzHj)。

</details>

## 功能

- **快速轻量的 Quickshell** — 经过优化的桌面组件，运行快速，易于自定义。
- **顶部状态栏** — 可自定义的状态栏，带有设置菜单和快捷入口。
- **设置** — 系统、网络、蓝牙、显示、音频、存储、主题等。
- **壁纸选择器与动态配色** — 自定义壁纸选择器，可根据壁纸自动生成配色。
- **预设主题** — Monochrome、Nord、Tokyo Night 等热门主题，并支持创建自己的主题。
- **应用启动器** — 基于 **Rofi** 的应用搜索、剪贴板历史和透明度控制。
- **Zsh + Starship** — 可自定义的 Shell，支持自动建议和历史记录。
- **笔记与提醒** — 快速笔记、任务和提醒。
- **电源菜单** — 可自定义的电源菜单。
- **Hyprlock** — 自定义锁屏。
- **Spotify + Spicetify** — 基于 **text - darkthemer** 的自定义主题（已修改）。

> 所有程序: [packages.txt](../packages.txt)

### 壁纸选择器

我只是做了一些调整。欢迎支持它：[hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper)

## 快捷键

右键点击时钟可打开状态栏设置。将鼠标悬停在元素上可查看操作。要关闭组件，请按 Esc 键或再次使用相同的快捷键。

| 快捷键 | 操作 |
| --- | --- |
| `Super + T` | 终端 |
| `Super + Q` | 关闭当前窗口 |
| `Super + D` | 应用启动器 |
| `Super + Space` | 切换浮动窗口 |
| `Super + F` | 切换全屏 |
| `Super + 1, 2, 3..` | 切换工作区 |
| `Super + Shift + 1, 2..` | 将窗口移动到工作区 |
| `Super + E` | 文件管理器 |
| `Super + B` | 浏览器 |
| `Super + V` | 剪贴板历史 |
| `Super + I` | 设置菜单 |
| `Super + S` | 快捷操作 |
| `Super + O` | 切换透明度 |
| `Super + C` | 笔记与提醒 |
| `Super + W` | 壁纸选择器 |
| `Super + Shift + C` | 取色器 |
| `Super + 鼠标滚轮` | 放大/缩小 |
| `Super + Shift + W` | 显示/隐藏状态栏 |
| `Super + Grave` | 注销菜单 |
| `Super + Tab` | 锁屏 |
| `Super + N` | 通知 |
| `Super + R` | 切换屏幕录制 |
| `Delete` | 全屏截图 |
| `SHIFT + Delete` | 区域截图 |

> [!note]
>
> 使用 Super + 鼠标左键/右键拖动来移动和调整窗口大小。
>
> 所有快捷键: [.config/hypr/keybinds.lua](../.config/hypr/keybinds.lua)

---
## 安装

**请完整阅读**

适用于 Arch、CachyOS、EndeavourOS、Manjaro 等。

主要面向全新安装（被替换的现有配置文件会自动备份）。

**请先安装 git，然后使用下面的命令，并持续安装直到完成**

```bash
sudo pacman -S git
```

```bash
git clone https://github.com/43PR/dotfiles.git
cd dotfiles
chmod +x install.sh
./install.sh
```

安装完成后，请注销并重新登录。

下载壁纸并移动到 Pictures/Wallpapers。壁纸选择器：Super + W。

> [!important]
> **安装后请勿移动或删除 dotfiles 仓库。**
>
> 此配置使用**符号链接（symlink）**，指向克隆仓库内的文件。如果移动或删除仓库，这些链接就会失效。
>
> 如果你移动了仓库，只需运行：
>
> ```bash
> ./install.sh
> ```
>
> 安装程序会自动更新现有的符号链接，使其指向新位置。

---
## 更新

如果你没有移动仓库/dotfiles 文件夹，请运行：

```bash
cd dotfiles
git pull
./update.sh
```

其他选项：`--dry-run`（预览更改）、`--skip-packages`、`--skip-theme`。

dotfiles 通过符号链接连接，因此 `git pull` 会直接更新你正在使用的配置。

你可以查看运行结束时打印的提醒。

> [!tip]
> 如果 pull 后有 Quickshell（`.qml`）文件发生变化，请运行：
>
> ```bash
> ./update.sh --restart-shell
> ```
>
> 以自动重启 Quickshell。

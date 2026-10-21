<div align="center">

## 43PR Desktop

Uma configuração Hyprland simples e leve, focada em produtividade, com atalhos práticos e fácil de personalizar.

![Hyprland](https://img.shields.io/badge/Hyprland-0.56.2-8b9aaf?style=for-the-badge&labelColor=101418)
[![Discord](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fdiscord.com%2Fapi%2Finvites%2FHQwU9SzHj%3Fwith_counts%3Dtrue&query=%24.approximate_member_count&style=for-the-badge&logo=discord&logoColor=ffffff&label=discord&labelColor=101418&color=7289a8)](https://discord.gg/HQwU9SzHj)
[![YouTube](https://img.shields.io/badge/youtube-subscribe-b05a63?style=for-the-badge&logo=youtube&logoColor=ffffff&labelColor=101418)](https://www.youtube.com/@43PR2)
[![Ko-Fi donate](https://img.shields.io/badge/donate-kofi?style=for-the-badge&logo=ko-fi&logoColor=ffffff&label=ko-fi&labelColor=101418&color=9a6570)](https://ko-fi.com/43pr)

### **[Recursos](#recursos)  -  [Atalhos de teclado](#atalhos-de-teclado)  -  [Instalação](#instalação) -  [Atualização](#atualização)**

<p align="center">
  <sub>
    <a href="../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh-CN.md">中文</a> · <a href="README.ja.md">日本語</a> · <b>Português</b> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a>
  </sub>
</p>

</div>

<img width="1920" height="1080" alt="1792462138" src="https://github.com/user-attachments/assets/10324a99-1038-431f-9f64-0183e2e04276" />

<details>
<summary><b>O que é isto? Sou iniciante?</b></summary>

### O que é isto?

Esta é uma configuração de desktop completa e personalizável para Linux (barra, lançador de aplicativos, configurações, seletor de papéis de parede, tela de bloqueio, menu de energia, etc.). Ela é construída sobre o **Hyprland** (gerenciador de janelas) e o **Quickshell** (com o qual a barra e os menus são feitos).

### O que preciso para usar?

- Uma **distribuição Linux baseada em Arch**: Arch, CachyOS, EndeavourOS, Manjaro, etc.
- Uma **instalação praticamente limpa**. As configurações existentes que forem substituídas são copiadas automaticamente como backup.

Recomendo o CachyOS para iniciantes: https://youtu.be/eo9MejbzWto

Você pode pular a parte de configuração do vídeo, agora ela é automática. Basta executar o comando de instalação.

### É difícil de usar?

Nem um pouco. Quase tudo é um atalho de teclado, com alternativas para o mouse:

- `Super + I` abre as configurações - clique com o botão do meio no relógio

A lista completa está em [Atalhos de teclado](#atalhos-de-teclado). Você também pode passar o cursor sobre os elementos da barra para ver o que eles fazem e clicar com o botão direito no relógio para abrir as configurações da barra.

### O que devo saber antes de instalar?

- Saia da sessão e entre novamente quando o instalador terminar.
- Os papéis de parede não vêm incluídos na instalação. Baixe alguns e coloque-os em `Pictures/Wallpapers`.

### Algo deu errado, onde pergunto?

Entre no [Discord](https://discord.gg/HQwU9SzHj).

</details>

## Recursos

- **Quickshell rápido e leve** — Componentes de desktop otimizados para serem rápidos e fáceis de personalizar.
- **Barra superior** — Barra personalizável com menu de configurações e atalhos rápidos.
- **Configurações** — Sistema, rede, bluetooth, tela, áudio, armazenamento, temas e mais.
- **Seletor de papéis de parede e cores dinâmicas** — Seletor de papéis de parede personalizado com geração automática de cores a partir do papel de parede.
- **Temas predefinidos** — Monochrome, Nord, Tokyo Night e outros populares, com suporte para criar os seus próprios.
- **Lançador de aplicativos** — Busca de aplicativos com **Rofi**, histórico da área de transferência e controle de opacidade.
- **Zsh + Starship** — Shell personalizável com autossugestões e histórico.
- **Notas e lembretes** — Notas rápidas, tarefas e lembretes.
- **Menu de energia** — Menu de energia personalizável.
- **Hyprlock** — Tela de bloqueio personalizada.
- **Spotify + Spicetify** — Tema personalizado baseado em **text - darkthemer** (modificado).

> Todos os programas: [packages.txt](../packages.txt)

### Seletor de papéis de parede

Fiz apenas alguns ajustes nele. Dê uma força: [hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper)

## Atalhos de teclado

Clique com o botão direito no relógio para abrir as configurações da barra. Passe o cursor sobre os elementos para ver as ações. Para fechar os componentes, use a tecla Esc ou o mesmo atalho.

| Atalho | Ação |
| --- | --- |
| `Super + T` | Terminal |
| `Super + Q` | Fechar a janela ativa |
| `Super + D` | Lançador de aplicativos |
| `Super + Space` | Alternar janela flutuante |
| `Super + F` | Alternar tela cheia |
| `Super + 1, 2, 3..` | Trocar de área de trabalho |
| `Super + Shift + 1, 2..` | Mover janela para outra área de trabalho |
| `Super + E` | Gerenciador de arquivos |
| `Super + B` | Navegador |
| `Super + V` | Histórico da área de transferência |
| `Super + I` | Menu de configurações |
| `Super + S` | Ações rápidas |
| `Super + O` | Alternar opacidade |
| `Super + C` | Notas e lembretes |
| `Super + W` | Seletor de papéis de parede |
| `Super + Shift + C` | Seletor de cores |
| `Super + Roda do mouse` | Aumentar/diminuir zoom |
| `Super + Shift + W` | Mostrar/ocultar a barra |
| `Super + Grave` | Menu de logout |
| `Super + Tab` | Bloquear tela |
| `Super + N` | Notificações |
| `Super + R` | Ligar/desligar gravador de tela |
| `Delete` | Captura de tela inteira |
| `SHIFT + Delete` | Captura de área selecionada |

> [!note]
>
> Mova e redimensione janelas com Super + arrastar com o botão esquerdo/direito do mouse.
>
> Todos os atalhos: [.config/hypr/keybinds.lua](../.config/hypr/keybinds.lua)

---
## Instalação

**LEIA TUDO**

Funciona no Arch, CachyOS, EndeavourOS, Manjaro, etc.

Destina-se principalmente a uma instalação limpa (os arquivos de configuração existentes que forem substituídos serão copiados automaticamente como backup).

**Primeiro instale o git, depois use o próximo comando e continue a instalação até que ela termine**

```bash
sudo pacman -S git
```

```bash
git clone https://github.com/43PR/dotfiles.git
cd dotfiles
chmod +x install.sh
./install.sh
```

Quando a instalação terminar, saia da sessão e entre novamente.

Baixe e mova os papéis de parede para Pictures/Wallpapers. Seletor de papéis de parede: Super + W.

> [!important]
> **Não mova nem apague o repositório dotfiles após a instalação.**
>
> Esta configuração usa **links simbólicos (symlinks)** que apontam para arquivos dentro do repositório clonado. Se você mover ou apagar o repositório, esses links vão quebrar.
>
> Se você mudar o repositório de lugar, basta executar:
>
> ```bash
> ./install.sh
> ```
>
> O instalador atualizará automaticamente os links existentes para apontar para o novo local.

---
## Atualização

Se você não moveu a pasta do repositório/dotfiles, execute:

```bash
cd dotfiles
git pull
./update.sh
```

Outras opções: `--dry-run` (pré-visualizar alterações), `--skip-packages`, `--skip-theme`.

Os dotfiles usam links simbólicos, então `git pull` atualiza diretamente as suas configurações em uso.

Você pode conferir os lembretes exibidos no final da execução.

> [!tip]
> Se algum arquivo do Quickshell (`.qml`) mudou no pull, execute:
>
> ```bash
> ./update.sh --restart-shell
> ```
>
> para reiniciar o Quickshell automaticamente.

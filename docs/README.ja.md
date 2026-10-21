<div align="center">

## 43PR Desktop

生産性、実用的なキーバインド、カスタマイズのしやすさを重視した、シンプルで軽量なHyprland環境です。

![Hyprland](https://img.shields.io/badge/Hyprland-0.56.2-8b9aaf?style=for-the-badge&labelColor=101418)
[![Discord](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fdiscord.com%2Fapi%2Finvites%2FHQwU9SzHj%3Fwith_counts%3Dtrue&query=%24.approximate_member_count&style=for-the-badge&logo=discord&logoColor=ffffff&label=discord&labelColor=101418&color=7289a8)](https://discord.gg/HQwU9SzHj)
[![YouTube](https://img.shields.io/badge/youtube-subscribe-b05a63?style=for-the-badge&logo=youtube&logoColor=ffffff&labelColor=101418)](https://www.youtube.com/@43PR2)
[![Ko-Fi donate](https://img.shields.io/badge/donate-kofi?style=for-the-badge&logo=ko-fi&logoColor=ffffff&label=ko-fi&labelColor=101418&color=9a6570)](https://ko-fi.com/43pr)

### **[機能](#機能)  -  [キーバインド](#キーバインド)  -  [インストール](#インストール) -  [アップデート](#アップデート)**

<p align="center">
  <sub>
    <a href="../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh-CN.md">中文</a> · <b>日本語</b> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a>
  </sub>
</p>

</div>

<img width="1920" height="1080" alt="1792462138" src="https://github.com/user-attachments/assets/10324a99-1038-431f-9f64-0183e2e04276" />

<details>
<summary><b>これは何？初心者の方へ</b></summary>

### これは何？

Linux向けの、フルカスタマイズ可能なデスクトップ環境です（バー、アプリランチャー、設定、壁紙セレクター、ロック画面、電源メニューなど）。**Hyprland**（ウィンドウマネージャー）と、バーやメニューの作成に使われている**Quickshell**の上に構築されています。

### 何が必要ですか？

- **Archベースの Linux ディストリビューション**：Arch、CachyOS、EndeavourOS、Manjaro など。
- ほぼ**クリーンインストール**の状態。置き換えられる既存の設定は自動的にバックアップされます。

初心者にはCachyOSをおすすめします：https://youtu.be/eo9MejbzWto

動画の設定セクションは、現在は自動化されているため飛ばして構いません。インストールコマンドを実行するだけです。

### 使うのは難しいですか？

いいえ、それほどではありません。ほとんどの操作はキーボードショートカットで行え、マウスでの代替手段もあります：

- `Super + I` で設定を開く - 時計を中クリック

完全な一覧は[キーバインド](#キーバインド)にあります。バーの要素にカーソルを合わせると何ができるかが表示され、時計を右クリックするとバーの設定が開きます。

### インストール前に知っておくことは？

- インストーラーの終了後、ログアウトして再度ログインしてください。
- 壁紙はインストールに含まれていません。いくつかダウンロードして `Pictures/Wallpapers` に置いてください。

### うまく動かないときは、どこで質問すればいいですか？

[Discord](https://discord.gg/HQwU9SzHj) に参加してください。

</details>

## 機能

- **高速・軽量なQuickshell** — 高速で、カスタマイズしやすいように最適化されたデスクトップコンポーネント。
- **トップバー** — 設定メニューとクイックショートカット付きのカスタマイズ可能なバー。
- **設定** — システム、ネットワーク、Bluetooth、ディスプレイ、オーディオ、ストレージ、テーマなど。
- **壁紙セレクター＆ダイナミックカラー** — 壁紙から自動的に配色を生成する、独自の壁紙セレクター。
- **プリセットテーマ** — Monochrome、Nord、Tokyo Night などの人気テーマを用意。独自テーマの作成にも対応。
- **アプリランチャー** — **Rofi** によるアプリ検索、クリップボード履歴、透過度の調整。
- **Zsh + Starship** — オートサジェストと履歴に対応した、カスタマイズ可能なシェル。
- **メモ＆リマインダー** — クイックメモ、タスク、リマインダー。
- **電源メニュー** — カスタマイズ可能な電源メニュー。
- **Hyprlock** — カスタムロック画面。
- **Spotify + Spicetify** — **text - darkthemer** をベースにした（改変済みの）カスタムテーマ。

> すべてのプログラム: [packages.txt](../packages.txt)

### 壁紙セレクター

少し手を加えただけです。ぜひ応援してください：[hyprquickpaper](https://github.com/iamsurjog/hyprquickpaper)

## キーバインド

時計を右クリックするとバーの設定が開きます。要素にカーソルを合わせるとアクションが表示されます。コンポーネントを閉じるにはEscキーを押すか、同じキーバインドを使ってください。

| キーバインド | アクション |
| --- | --- |
| `Super + T` | ターミナル |
| `Super + Q` | アクティブなウィンドウを閉じる |
| `Super + D` | アプリランチャー |
| `Super + Space` | フローティングウィンドウの切り替え |
| `Super + F` | フルスクリーンの切り替え |
| `Super + 1, 2, 3..` | ワークスペースの切り替え |
| `Super + Shift + 1, 2..` | ウィンドウをワークスペースに移動 |
| `Super + E` | ファイルマネージャー |
| `Super + B` | ブラウザ |
| `Super + V` | クリップボード履歴 |
| `Super + I` | 設定メニュー |
| `Super + S` | クイックアクション |
| `Super + O` | 透過度の切り替え |
| `Super + C` | メモ＆リマインダー |
| `Super + W` | 壁紙セレクター |
| `Super + Shift + C` | カラーピッカー |
| `Super + マウスホイール` | 拡大／縮小 |
| `Super + Shift + W` | バーの表示切り替え |
| `Super + Grave` | ログアウトメニュー |
| `Super + Tab` | 画面ロック |
| `Super + N` | 通知 |
| `Super + R` | 画面録画の切り替え |
| `Delete` | 全画面スクリーンショット |
| `SHIFT + Delete` | 範囲選択スクリーンショット |

> [!note]
>
> Super + 左/右マウスドラッグでウィンドウを移動・リサイズできます。
>
> すべてのキーバインド: [.config/hypr/keybinds.lua](../.config/hypr/keybinds.lua)

---
## インストール

**必ず全部お読みください**

Arch、CachyOS、EndeavourOS、Manjaro などで動作します。

主にクリーンインストールを想定しています（置き換えられる既存の設定ファイルは自動的にバックアップされます）。

**まず git をインストールし、次のコマンドを実行して、完了するまでインストールを続けてください**

```bash
sudo pacman -S git
```

```bash
git clone https://github.com/43PR/dotfiles.git
cd dotfiles
chmod +x install.sh
./install.sh
```

インストールが完了したら、ログアウトして再度ログインしてください。

壁紙をダウンロードして Pictures/Wallpapers に移動してください。壁紙セレクター：Super + W。

> [!important]
> **インストール後に dotfiles リポジトリを移動・削除しないでください。**
>
> この環境は、クローンしたリポジトリ内のファイルを指す**シンボリックリンク（symlink）**を使用しています。リポジトリを移動または削除すると、これらのリンクが壊れます。
>
> リポジトリを移動した場合は、次を実行するだけです：
>
> ```bash
> ./install.sh
> ```
>
> インストーラーが既存のシンボリックリンクを新しい場所を指すように自動で更新します。

---
## アップデート

リポジトリ／dotfiles フォルダーを移動していない場合は、次を実行します：

```bash
cd dotfiles
git pull
./update.sh
```

その他のオプション：`--dry-run`（変更のプレビュー）、`--skip-packages`、`--skip-theme`。

dotfiles はシンボリックリンクされているため、`git pull` で実際に使用中の設定が直接更新されます。

実行の最後に表示されるリマインダーを確認できます。

> [!tip]
> pull で Quickshell の（`.qml`）ファイルが変更された場合は、次を実行します：
>
> ```bash
> ./update.sh --restart-shell
> ```
>
> Quickshell を自動的に再起動します。

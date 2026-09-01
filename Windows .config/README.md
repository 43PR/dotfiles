## Windows Customization

A collection of the customizations, tools, configs, and tweaks I use to customize Windows.

You can copy the configuration files for YASB and Komorebi directly from this repository.

Note: The Komorebi configuration is still rough and may contain bugs or unfinished parts. Feel free to skip that section if you just want the other customizations.

YASB — Custom status bar
Komorebi — Tiling window manager configuration
WHKD — Keyboard shortcuts for Komorebi
Spicetify — Spotify customization
Wallpaper picker — Python-based wallpaper tool

### Windows Keybinds

Some useful Windows shortcuts:

Shortcut	Action
Win + A	Open Quick Settings
Ctrl + Win + D	Create a new virtual desktop
Win + Tab	Open Task View
Ctrl + Win + ← / →	Switch virtual desktops
Win + 1, 2, 3...	Open/switch to applications on the taskbar
Alt + Tab	Switch between windows


### Windhawk

https://windhawk.net/

Installed Mods
Windows 11 Taskbar Styler > SimplyTransparent
Windows 11 Start Menu Styler > LiquidGlass Legacy
Windows 11 Notification Center Styler > TranslucentShell
Windows 11 File Explorer Styler > Translucent Explorer11
Translucent Windows > No configuration changes are needed. Just turn on and off.
Taskbar tray system icon tweaks
Taskbar Clock Customization

> After installing programs in the terminal close an reopen it

### Cava

Install Cava using WinGet Run:
winget install karlstav.cava
command: cava

### Btop

Install btop:
winget install --id aristocratos.btop4win -e
command: btop

### YASB status bar

Install it with WinGet:
winget install --id AmN.yasb

After installing:

Open YASB.
Select Get Started.
Select Komorebi or don't if you won't use it.
Choose the components/features you want.
Editing the Configuration

The YASB configuration is located at:

C:\Users\<YOUR_USERNAME>\.config\yasb\config.yaml

You can bookmark this location.
Edit the configuration with: VSCodium, Notepad or any other text editor

Autostart
Enable Auto Start from the YASB taskbar tray icon.
You can also reload the YASB bar from the same tray menu after editing the files.

### Wallpaper Picker

The wallpaper picker requires Python and Pillow.
Install from
https://www.python.org/downloads/windows/

During installation:

Enable Add python.exe to PATH.
Click Install.
2. Install Pillow

Open a terminal and run:

pip install Pillow

3. Copy the YASB Folder

Copy the yasb folder from this repository into:

C:\Users\<YOUR_USERNAME>\.config\

Reload yasb. If it doesn't work, make sure the folder is in the correct location and that the username/path matches your Windows installation.



### Spicetify

Installation. Run the following command in PowerShell:

iwr -useb https://raw.githubusercontent.com/spicetify/cli/main/install.ps1 | iex

The default Spicetify directory should be:

C:\Users\<YOUR_USERNAME>\AppData\Local\spicetify

Open a terminal without administrator privileges and run:

spicetify backup apply

You can install the theme from the  marketplace (text by darkthemer) or just copy the folder from the Themes folder from the repository 

Close Spotify completely.

Replace the corresponding files with the ones from the repository.
https://github.com/43PR/dotfiles/tree/main/.config/spicetify/Themes/text

Make sure the theme folder is named: text

Then run:

spicetify apply

If something goes wrong and you want to return to the original Spotify setup:

spicetify restore backup




### Komorebi + WHKD

The Komorebi configuration is still a work in progress and may have bugs or require additional adjustments. If you don't need a tiling window manager, I recommend skipping this section.

Install Komorebi
winget install --id LGUG2Z.komorebi

Install WHKD

WHKD handles the keyboard shortcuts:

winget install --id LGUG2Z.whkd

Start Komorebi

Run:

komorebic start

Create the WHKD Configuration

Create the configuration file:

New-Item -ItemType File -Force "$HOME\.config\whkdrc"


Open it with Notepad:

notepad "$HOME\.config\whkdrc"


The WHKD configuration used by this setup is included in the repository.

Copy the appropriate configuration into the file and save it.

Then start WHKD:

whkd

Create the Komorebi Configuration

Create the configuration file:

notepad "$HOME\.config\komorebi.json"


The Komorebi configuration is also included in this repository.

Set the Komorebi Config Path

For the current PowerShell session:

$env:KOMOREBI_CONFIG_HOME = "C:\Users\<YOUR_USERNAME>\.config"


To permanently set it for your user account:

[Environment]::SetEnvironmentVariable(
    "KOMOREBI_CONFIG_HOME",
    "C:\Users\<YOUR_USERNAME>\.config",
    "User"
)


Replace <YOUR_USERNAME> with your Windows username.

Start Komorebi With the Config
komorebi --config "C:\Users\<YOUR_USERNAME>\.config\komorebi.json"


If you need to restart Komorebi:

komorebic stop
komorebi --config "C:\Users\<YOUR_USERNAME>\.config\komorebi.json"
komorebic start


Enable movement animations:

komorebic animation enable --animation-type movement

Autostart

To start WHKD and the other components automatically when Windows starts:

Press Win + R.
Enter:
shell:startup

Add the following startup files:
start-whkd.bat
start-whkd.vbs


These files are included in the repository.

Troubleshooting

If something doesn't work, check the following first:

Make sure paths use your actual Windows username instead of <YOUR_USERNAME>.
Make sure configuration files are inside the correct .config directory.
Restart YASB after modifying its configuration.
Make sure Spotify is completely closed before replacing Spicetify files.
Run Spicetify commands without administrator privileges unless specifically required.
If Komorebi behaves unexpectedly, remember that its configuration is still a work in progress.

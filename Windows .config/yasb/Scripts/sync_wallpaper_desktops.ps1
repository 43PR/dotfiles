<#
sync_wallpaper_desktops.ps1
-------------------------------------------------------------------
Windows 11 lets each virtual desktop keep its own "Picture" wallpaper
override. Once any desktop has one, setting a new wallpaper (via
YASB, Settings, etc.) only updates the *currently active* desktop -
the others silently keep their old picture.

This clears the stored per-desktop override so every desktop falls
back to the shared wallpaper you just set, then restarts Explorer
to force the desktops to re-read it.

Wire this into YASB as a `run_after` command on the wallpapers
widget so it runs automatically every time you pick a new wallpaper:

    run_after:
      - "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\User\\.config\\yasb\\scripts\\sync_wallpaper_desktops.ps1\""

Note: restarting Explorer causes a brief (~1-2s) taskbar/desktop-icon
flicker. YASB itself runs as a separate process and is unaffected.
If you'd rather avoid the flicker, remove the restart at the bottom
and just re-run this script manually after switching to each desktop
once - Explorer picks up the cleared override the next time it draws
that desktop.
-------------------------------------------------------------------
#>

$basePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops\Desktops"

if (Test-Path $basePath) {
    Get-ChildItem -Path $basePath | ForEach-Object {
        $key = $_.PSPath
        if (Get-ItemProperty -Path $key -Name "Wallpaper" -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $key -Name "Wallpaper" -ErrorAction SilentlyContinue
            Write-Output "Cleared override: $($_.PSChildName)"
        }
    }
} else {
    Write-Output "No per-desktop wallpaper overrides found."
}

# Force Explorer (taskbar + desktop) to reload so the change is
# visible on every virtual desktop immediately, not just on next
# switch.
Stop-Process -Name explorer -Force
Start-Sleep -Milliseconds 500
Start-Process explorer

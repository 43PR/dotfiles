import Quickshell

// Entry point. Quickshell always loads this file first.
// Everything visible lives in its own component file next to this one;
// this file just mounts them under one ShellRoot.
ShellRoot {
    VolumeOsd {}
    SettingsWindow {}
}

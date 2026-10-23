#!/usr/bin/env python3
# .config/43pr/bin/theme.py
"""43PR theme controller: presets + Matugen -> one semantic palette -> app files."""
import argparse, colorsys, fcntl, json, os, re, shutil, subprocess, sys, tempfile, tomllib
from contextlib import contextmanager
from pathlib import Path

HOME = Path.home()
CFG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "43pr"
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "43pr"
ROOT = CFG / "43pr"
THEMES = ROOT / "themes"
TARGETS = ROOT / "targets.toml"
MATUGEN_CFG = CFG / "matugen" / "config.toml"
MATUGEN_OUT = CACHE / "matugen" / "semantic.json"
PALETTE = CACHE / "palette.json"
STATE = STATE_DIR / "state.json"

# GTK theme names used when syncing light/dark.
#   "auto" -> "Adwaita-dark" for dark if that theme is installed (Arch: the
#             gnome-themes-extra package), otherwise plain "Adwaita" (dark is then
#             a variant set via gtk-application-prefer-dark-theme in settings.ini).
#   None   -> leave gtk-theme untouched.
# Or put your own theme names here.
GTK_THEME_DARK = "auto"
GTK_THEME_LIGHT = "Adwaita"

# Generated folder-icon theme: a thin overlay on Papirus holding only recolored
# folder icons (see generate_icons). theme.py switches icon-theme itself.
# Two names, alternated on every run: GTK only reloads icons on a real name change.
ICON_NAMES = ("43pr-icons-a", "43pr-icons-b")
ICON_ROOT = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share")) / "icons"
ICON_BASE_DARK = "Papirus-Dark"
ICON_BASE_LIGHT = "Papirus-Light"
ICON_ACCENT_KEYS = ("accent", "primary", "gtk_accent")   # first key present in the palette wins
GTK_RELOAD = HOME / ".config/hypr/scripts/gtk-reload.sh"

HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
NAME = re.compile(r"^[A-Za-z0-9._-]+$")
TOKEN = re.compile(r"\{\{\s*([A-Za-z0-9_]+)((?:\s*\|\s*[a-z0-9]+(?:=[0-9a-fA-Fx.]+)?)*)\s*\}\}")
IMG_EXT = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp"}


def die(msg):
    print(f"theme: {msg}", file=sys.stderr)
    sys.exit(1)


def warn(msg):
    print(f"theme: warning: {msg}", file=sys.stderr)


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.43pr-tmp")
    tmp.write_text(text)
    os.replace(tmp, path)


@contextmanager
def lock():
    CACHE.mkdir(parents=True, exist_ok=True)
    with open(CACHE / "lock", "w") as f:
        fcntl.flock(f, fcntl.LOCK_EX)   # serialises rapid wallpaper changes
        yield


def load_toml(p):
    with open(p, "rb") as f:
        return tomllib.load(f)


def load_state():
    try:
        return json.loads(STATE.read_text())
    except Exception:
        return {}


def save_state(st):
    atomic_write(STATE, json.dumps(st, indent=2))


def current_mode():
    return os.environ.get("MATUGEN_MODE") or load_state().get("mode_appearance", "dark")


# ---------- GTK / portal sync ----------

def set_ini_key(path, key, value):
    """Set key=value under [Settings] in a GTK settings.ini, creating it if needed."""
    text = path.read_text() if path.is_file() else "[Settings]\n"
    line = f"{key}={value}"
    if re.search(rf"(?m)^{re.escape(key)}=.*$", text):
        text = re.sub(rf"(?m)^{re.escape(key)}=.*$", line, text)
    elif re.search(r"(?m)^\[Settings\]\s*$", text):
        text = re.sub(r"(?m)^\[Settings\]\s*$", f"[Settings]\n{line}", text, count=1)
    else:
        text = text.rstrip("\n") + f"\n[Settings]\n{line}\n"
    atomic_write(path, text)


def sync_gtk_ini(dark):
    """GTK3 ignores color-scheme; it follows prefer-dark-theme from settings.ini."""
    for d in ("gtk-3.0", "gtk-4.0"):
        try:
            set_ini_key(CFG / d / "settings.ini",
                        "gtk-application-prefer-dark-theme", int(dark))
        except Exception as e:
            warn(f"could not update {d}/settings.ini: {e}")


def gtk_theme_installed(name):
    """True if a GTK3 theme called `name` exists in the standard theme dirs."""
    data = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share"))
    dirs = [Path("/usr/share/themes"), Path("/usr/local/share/themes"),
            HOME / ".themes", data / "themes"]
    return any((d / name / "gtk-3.0").is_dir() for d in dirs)


def resolve_gtk_theme(dark):
    name = GTK_THEME_DARK if dark else GTK_THEME_LIGHT
    if name == "auto":
        return "Adwaita-dark" if dark and gtk_theme_installed("Adwaita-dark") else "Adwaita"
    return name


def set_gtk_color_scheme(value):
    """Sync GTK/libadwaita/portal color-scheme with our appearance mode.
    Never raises; failures only produce warnings."""
    sync_gtk_ini(value == "dark")
    if not shutil.which("gsettings"):
        warn("gsettings not found; skipping GTK color-scheme sync")
        return
    dark = value == "dark"
    settings = [("color-scheme", "prefer-dark" if dark else "prefer-light")]
    gtk_theme = resolve_gtk_theme(dark)
    if gtk_theme:
        settings.append(("gtk-theme", gtk_theme))
    for key, val in settings:
        try:
            r = subprocess.run(
                ["gsettings", "set", "org.gnome.desktop.interface", key, val],
                stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=5)
            if r.returncode != 0:
                warn(f"gsettings {key} failed: {r.stderr.strip()}")
        except Exception as e:
            warn(f"gsettings {key} failed: {e}")


def palette_appearance(pal, hint=None):
    """'light' or 'dark' for a palette. A preset may set appearance = "light"|"dark";
    otherwise it's inferred from the background color's luminance."""
    if hint in ("dark", "light"):
        return hint
    h = (pal.get("gtk_bg") or pal.get("bg") or "#000000").lstrip("#")[:6]
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return "light" if lum > 0.5 else "dark"


def sync_appearance(st, pal, hint=None):
    """Record the effective appearance in state and sync GTK to it."""
    mode = palette_appearance(pal, hint)
    st["mode_appearance"] = mode
    set_gtk_color_scheme(mode)
    return mode


# ---------- palettes ----------

def merged(colors):
    """Overlay onto default so presets/matugen may omit keys."""
    base = dict(load_toml(THEMES / "default.toml")["colors"])
    base.update(colors)
    bad = {k: v for k, v in base.items() if not (isinstance(v, str) and HEX.match(v))}
    if bad:
        raise ValueError(f"invalid colors: {bad}")
    return {k: v.lower() for k, v in base.items()}


def preset_path(name):
    if name == "43pr-default":
        name = "default"
    if not NAME.match(name):
        die(f"invalid preset name: {name!r}")
    p = THEMES / f"{name}.toml"
    if not p.is_file():
        die(f"no such preset: {name} (looked in {THEMES})")
    return p


def preset_palette(name):
    return merged(load_toml(preset_path(name)).get("colors", {}))


# ---------- scheme-type auto-selection ----------

def _find_hex(node, keys=("primary", "source_color", "seed")):
    """Best-effort search for a seed hex color in matugen's dry-run JSON,
    whose exact shape isn't guaranteed across versions/flags."""
    if isinstance(node, str) and HEX.match(node):
        return node
    if isinstance(node, dict):
        for k in keys:
            if k in node:
                found = _find_hex(node[k], keys)
                if found:
                    return found
        for v in node.values():
            found = _find_hex(v, keys)
            if found:
                return found
    return None


def pick_scheme_type(hexcolor, low_sat_threshold=0.12):
    r, g, b = (int(hexcolor.lstrip("#")[i:i + 2], 16) / 255 for i in (0, 2, 4))
    _, _, s = colorsys.rgb_to_hls(r, g, b)
    return "scheme-neutral" if s < low_sat_threshold else "scheme-tonal-spot"


def probe_scheme_type(path):
    """Never raises; falls back to scheme-tonal-spot on any failure."""
    try:
        probe = subprocess.run(
            ["matugen", "image", str(path), "--source-color-index", "0",
             "--dry-run", "--json", "hex", "-q"],
            stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30)
        data = json.loads(probe.stdout)
        seed = _find_hex(data)
        if seed:
            return pick_scheme_type(seed)
        warn("could not find a seed color in matugen's dry-run output; using scheme-tonal-spot")
    except Exception as e:
        warn(f"scheme-type probe failed ({e}); using scheme-tonal-spot")
    return "scheme-tonal-spot"


# ---------- matugen ----------

def from_wallpaper(path):
    if not shutil.which("matugen"):
        raise RuntimeError("matugen is not installed")

    scheme_type = os.environ.get("MATUGEN_TYPE") or probe_scheme_type(path)

    MATUGEN_OUT.parent.mkdir(parents=True, exist_ok=True)
    MATUGEN_OUT.unlink(missing_ok=True)   # never trust a stale file
    cmd = ["matugen", "image", str(path), "-c", str(MATUGEN_CFG),
           "-m", current_mode(),
           "-t", scheme_type,
           "--source-color-index", "0", "-q"]
    r = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(f"matugen failed: {(r.stderr or r.stdout).strip()}")
    if not MATUGEN_OUT.is_file():
        raise RuntimeError(f"matugen produced no {MATUGEN_OUT}")
    return merged(json.loads(MATUGEN_OUT.read_text()))


# ---------- folder icons + live GTK reload ----------

HEX6 = re.compile(r"#[0-9a-fA-F]{6}\b")


def _hex_hls(c):
    h = c.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return colorsys.rgb_to_hls(r, g, b)


def _hls_hex(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h % 1.0, min(1.0, max(0.0, l)), min(1.0, max(0.0, s)))
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def icon_base_dir(dark):
    data = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share"))
    roots = [data / "icons", HOME / ".icons", Path("/usr/local/share/icons"), Path("/usr/share/icons")]
    for name in (ICON_BASE_DARK if dark else ICON_BASE_LIGHT, "Papirus"):
        for root in roots:
            if (root / name / "index.theme").is_file():
                return root / name
    return None


def gsettings_get(key):
    if not shutil.which("gsettings"):
        return ""
    try:
        r = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", key],
                           stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=5)
        return r.stdout.strip().strip("'")
    except Exception:
        return ""


def set_icon_theme(name):
    """Point gsettings and both settings.ini files at the freshly generated theme."""
    for d in ("gtk-3.0", "gtk-4.0"):
        try:
            set_ini_key(CFG / d / "settings.ini", "gtk-icon-theme-name", name)
        except Exception as e:
            warn(f"could not update {d}/settings.ini: {e}")
    if shutil.which("gsettings"):
        try:
            subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", name],
                           stdin=subprocess.DEVNULL, capture_output=True, timeout=5)
        except Exception as e:
            warn(f"gsettings icon-theme failed: {e}")


def generate_icons(pal, dark):
    """Write the inactive ICON_NAMES theme: Papirus' folder-blue* icons recolored to the palette accent.
    Hue is replaced, saturation/lightness are scaled relative to the icon's main
    blue, so shading and the neutral highlights survive. The system theme is
    only read, never modified."""
    accent = next((pal[k] for k in ICON_ACCENT_KEYS if k in pal), None)
    if not accent:
        warn(f"no accent key found in palette (tried {ICON_ACCENT_KEYS}); folder icons unchanged")
        return 0
    base = icon_base_dir(dark)
    if not base:
        warn("Papirus icon theme not found; folder icons unchanged")
        return 0
    places = sorted(d for d in base.glob("*/places")
                    if d.is_dir() and re.fullmatch(r"\d+x\d+", d.parent.name))
    sources = {f: f.read_text() for d in places for f in d.glob("folder-blue*.svg")
               if f.is_file() and not f.is_symlink()}
    counts = {}
    for text in sources.values():
        for c in HEX6.findall(text):
            counts[c.lower()] = counts.get(c.lower(), 0) + 1
    sat = [(n, c) for c, n in counts.items() if _hex_hls(c)[2] > 0.3]
    if not sat:
        warn(f"no folder-blue*.svg with saturated colors under {base}; folder icons unchanged")
        return 0
    _, ref_l, ref_s = _hex_hls(max(sat)[1])      # the icon's main blue
    ah, al, a_s = _hex_hls(accent)

    def recolor(m):
        h, l, s = _hex_hls(m.group(0))
        w = min(1.0, s / ref_s)                  # 0 for greys/whites, 1 for the main blue
        return _hls_hex(ah if s > 0.05 else h, l + (al - ref_l) * w, s * a_s / ref_s)

    active = gsettings_get("icon-theme")          # write the one that is NOT in use
    name = ICON_NAMES[1] if active == ICON_NAMES[0] else ICON_NAMES[0]
    dest = ICON_ROOT / name
    tmp = ICON_ROOT / (name + ".43pr-tmp")
    shutil.rmtree(tmp, ignore_errors=True)
    written, dirs = 0, []
    for d in places:
        rel = d.relative_to(base).as_posix()
        out = tmp / rel
        out.mkdir(parents=True)
        for f in d.iterdir():
            if not f.name.startswith("folder-blue") and not f.is_symlink():
                continue
            if f.is_symlink():                    # folder.svg -> folder-blue.svg etc.
                target = os.readlink(f)
                if "/" not in target and target.startswith("folder-blue"):
                    os.symlink(target, out / f.name)
                    written += 1
            elif f.name in {p.name for p in sources if p.parent == d}:
                (out / f.name).write_text(HEX6.sub(recolor, sources[f]))
                written += 1
        dirs.append(rel)
    index = ["[Icon Theme]", f"Name={name}", "Comment=Generated by 43pr theme.py",
             f"Inherits={base.name}", "Directories=" + ",".join(dirs), ""]
    for rel in dirs:
        index += [f"[{rel}]", f"Size={rel.split('x')[0]}", "Context=Places", "Type=Fixed", ""]
    (tmp / "index.theme").write_text("\n".join(index))
    shutil.rmtree(dest, ignore_errors=True)
    os.replace(tmp, dest)
    if shutil.which("gtk-update-icon-cache"):
        subprocess.run(["gtk-update-icon-cache", "-q", "-f", "-t", str(dest)],
                       stdin=subprocess.DEVNULL, capture_output=True, timeout=30)
    set_icon_theme(name)
    return written


def reload_gtk(dark=None):
    """Make running GTK apps (Thunar...) re-read CSS and icons. Never raises.

    Must be called AFTER all gsettings/settings.ini syncing is finished, and the
    intended gtk-theme is passed to the script explicitly so it never has to
    guess it from (possibly half-toggled) live state."""
    if not GTK_RELOAD.is_file():
        return
    cmd = ["bash", str(GTK_RELOAD)]
    if dark is None:
        dark = load_state().get("mode_appearance", "dark") == "dark"
    theme = resolve_gtk_theme(dark)
    if theme:
        cmd.append(theme)
    try:
        subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, timeout=15)
    except Exception as e:
        warn(f"gtk reload failed: {e}")


# ---------- rendering ----------

def render(text, pal, where):
    def sub(m):
        key, chain = m.group(1), m.group(2)
        if key not in pal:
            raise ValueError(f"{where}: unknown color '{key}'")
        v = pal[key]
        for f in (x.strip() for x in chain.split("|") if x.strip()):
            fname, _, arg = f.partition("=")
            if fname == "strip":
                v = v.lstrip("#")
            elif fname == "alpha" and arg:
                v = v.lstrip("#")[:6]
                v = "#" + v + arg.lower()
            elif fname == "rgb":
                h = v.lstrip("#")[:6]
                v = ", ".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))
            elif fname == "rgba" and arg:
                h = v.lstrip("#")[:6]
                r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
                v = f"{r}, {g}, {b}, {arg}"
            elif fname == "hex8" and arg:
                v = v.lstrip("#")[:6] + arg.lower()
            else:
                raise ValueError(f"{where}: bad filter '{f}'")
        return v
    result = TOKEN.sub(sub, text)
    leftover = re.search(r"\{\{.*?\}\}", result)
    if leftover:
        raise ValueError(f"{where}: malformed template token: {leftover.group(0)}")
    return result


def apply_palette(pal):
    """Render templates, regenerate icons, run reload hooks.
    NOTE: does not reload GTK; callers do that once, after GTK sync (reload_gtk)."""
    targets = load_toml(TARGETS) if TARGETS.exists() else {}
    CACHE.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".stage-", dir=CACHE))
    hooks = []
    render_vars = dict(pal)
    try:
        staged = []
        for name, t in targets.items():           # 1. render everything first
            src, dst = Path(t["input"]).expanduser(), Path(t["output"]).expanduser()
            f = stage / name
            f.write_text(render(src.read_text(), render_vars, name))
            staged.append((f, dst))
            if t.get("reload") and t["reload"] not in hooks:
                hooks.append(t["reload"])
        for f, dst in staged:                      # 2. only then replace files
            dst.parent.mkdir(parents=True, exist_ok=True)
            tmp = dst.with_name(f".{dst.name}.43pr-tmp")
            shutil.copyfile(f, tmp)
            os.replace(tmp, dst)
        atomic_write(PALETTE, json.dumps(pal, indent=2))
    finally:
        shutil.rmtree(stage, ignore_errors=True)
    try:                                           # folder icons follow the accent
        generate_icons(pal, palette_appearance(pal) == "dark")
    except Exception as e:
        warn(f"icon theme generation failed: {e}")
    for h in hooks:                                # 3. reload consumers last
        try:
            r = subprocess.run(h, stdin=subprocess.DEVNULL, capture_output=True, timeout=10)
            benign = bool(h) and Path(h[0]).name == "pkill" and r.returncode == 1  # no process matched
            if r.returncode != 0 and not benign:
                warn(f"reload {h} exited {r.returncode}")
        except Exception as e:
            warn(f"reload {h} failed: {e}")


def ensure_fallback():
    if not PALETTE.exists():
        try:
            apply_palette(preset_palette("default"))
        except Exception as e:
            warn(f"could not apply fallback: {e}")


# ---------- commands ----------

def cmd_wallpaper(a):
    p = Path(a.path).expanduser()
    p = (p if p.is_absolute() else Path.cwd() / p).resolve()
    if not p.is_file():
        die(f"not a file: {p}")
    if p.suffix.lower() not in IMG_EXT:
        die(f"unsupported image type: {p.suffix}")
    if not os.access(p, os.R_OK):
        die(f"not readable: {p}")
    with lock():
        st = load_state()
        if not st.get("colorgen", True):
            st["wallpaper"] = str(p)          # remember it for when it's turned back on
            save_state(st)
            print("theme: color generation is off; wallpaper recorded only")
            return
        pinned = False
        try:
            pdata = load_toml(preset_path(st["preset"])) if st.get("mode") == "preset" else {}
            pinned = bool(pdata.get("override", False))
            if pinned:
                pal = merged(pdata.get("colors", {}))
                print(f"theme: preset '{st['preset']}' is pinned; keeping it")
            else:
                pal = from_wallpaper(p)
                st["mode"] = "wallpaper"
            apply_palette(pal)
            if pinned:
                sync_appearance(st, pal, pdata.get("appearance"))
        except Exception as e:
            ensure_fallback()
            die(f"theme unchanged: {e}")
        st["wallpaper"] = str(p)
        save_state(st)
        reload_gtk(st.get("mode_appearance", "dark") == "dark")   # after all GTK sync
    print("theme: applied from", "preset" if pinned else "wallpaper")


def cmd_preset(a):
    with lock():
        try:
            data = load_toml(preset_path(a.name))
            pal = merged(data.get("colors", {}))
            apply_palette(pal)
        except Exception as e:
            ensure_fallback()
            die(f"theme unchanged: {e}")
        st = load_state()
        st.update(mode="preset", preset="default" if a.name == "43pr-default" else a.name)
        mode = sync_appearance(st, pal, data.get("appearance"))   # light/dark GTK follows the preset
        save_state(st)
        reload_gtk(mode == "dark")                                # after all GTK sync
    print(f"theme: preset '{a.name}' applied")


def cmd_auto(a):
    """Back to wallpaper-driven mode, re-generating from the last wallpaper."""
    st = load_state()
    wp = st.get("wallpaper")
    if not wp:
        die("no wallpaper recorded yet; pick one first")
    a.path = wp
    st["mode"] = "wallpaper"
    save_state(st)
    cmd_wallpaper(a)


def cmd_apply(a):
    """Re-render templates from the current palette (or default on first run)."""
    with lock():
        try:
            pal = json.loads(PALETTE.read_text()) if PALETTE.exists() else preset_palette("default")
            apply_palette(merged(pal))
            mode = load_state().get("mode_appearance", "dark")
            set_gtk_color_scheme(mode)   # first run / install
            reload_gtk(mode == "dark")   # after all GTK sync
        except Exception as e:
            die(f"apply failed: {e}")
    print("theme: re-rendered")


def cmd_mode(a):
    if a.value not in ("dark", "light"):
        die("mode must be 'dark' or 'light'")
    st = load_state()
    st["mode_appearance"] = a.value
    save_state(st)
    set_gtk_color_scheme(a.value)             # sync GTK/libadwaita/portal color-scheme
    wp = st.get("wallpaper")
    if st.get("mode") == "wallpaper" and wp:
        cmd_wallpaper(argparse.Namespace(path=wp))   # reloads GTK itself
    else:
        with lock():
            reload_gtk(a.value == "dark")
        print(f"theme: mode set to {a.value} (no wallpaper active; will apply on next 'wallpaper' or 'auto')")


def cmd_colorgen(a):
    """Enable/disable wallpaper-driven color generation."""
    if a.value not in ("on", "off"):
        die("colorgen must be 'on' or 'off'")
    with lock():
        st = load_state()
        st["colorgen"] = (a.value == "on")
        save_state(st)
    if a.value == "on" and load_state().get("wallpaper"):
        cmd_auto(a)    # regenerate from the last wallpaper right away
    else:
        print(f"theme: color generation {a.value}")


def cmd_list(a):
    st = load_state()
    for p in sorted(THEMES.glob("*.toml")):
        d = load_toml(p)
        mark = "*" if st.get("mode") == "preset" and st.get("preset") == p.stem else " "
        pin = " [pinned]" if d.get("override") else ""
        print(f"{mark} {p.stem:<16}{pin} {d.get('description', '')}")


def cmd_new(a):
    if not NAME.match(a.name):
        die(f"invalid preset name: {a.name!r}")
    dst = THEMES / f"{a.name}.toml"
    if dst.exists():
        die(f"already exists: {dst}")
    if a.source == "current":
        if not PALETTE.exists():
            die("no current palette yet")
        colors = json.loads(PALETTE.read_text())
    else:
        colors = preset_palette(a.source)
    lines = [f'name = "{a.name}"', f'description = "copied from {a.source}"',
             "override = false", "", "[colors]"]
    lines += [f'{k} = "{v}"' for k, v in colors.items()]
    atomic_write(dst, "\n".join(lines) + "\n")
    print(f"theme: created {dst}")


def cmd_status(a):
    print("state:  ", json.dumps(load_state()))
    print("palette:", PALETTE, "(exists)" if PALETTE.exists() else "(missing)")
    print("matugen:", shutil.which("matugen") or "NOT INSTALLED")


def cmd_toggle(a):
    st = load_state()
    current = st.get("mode_appearance", "dark")
    cmd_mode(argparse.Namespace(value="light" if current == "dark" else "dark"))


def main():
    ap = argparse.ArgumentParser(prog="theme.py")
    sp = ap.add_subparsers(dest="cmd", required=True)
    s = sp.add_parser("wallpaper"); s.add_argument("path"); s.set_defaults(f=cmd_wallpaper)
    s = sp.add_parser("preset"); s.add_argument("name"); s.set_defaults(f=cmd_preset)
    s = sp.add_parser("default"); s.set_defaults(f=cmd_preset, name="default")
    s = sp.add_parser("auto"); s.set_defaults(f=cmd_auto)
    s = sp.add_parser("apply"); s.set_defaults(f=cmd_apply)
    s = sp.add_parser("mode"); s.add_argument("value"); s.set_defaults(f=cmd_mode)
    s = sp.add_parser("colorgen"); s.add_argument("value"); s.set_defaults(f=cmd_colorgen)
    s = sp.add_parser("list"); s.set_defaults(f=cmd_list)
    s = sp.add_parser("new"); s.add_argument("name")
    s.add_argument("source", nargs="?", default="default"); s.set_defaults(f=cmd_new)
    s = sp.add_parser("status"); s.set_defaults(f=cmd_status)
    s = sp.add_parser("toggle"); s.set_defaults(f=cmd_toggle)
    a = ap.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
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
    for h in hooks:                                # 3. reload consumers last
        try:
            r = subprocess.run(h, stdin=subprocess.DEVNULL, capture_output=True, timeout=10)
            if r.returncode != 0:
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
        pinned = False
        try:
            pinned = st.get("mode") == "preset" and \
                load_toml(preset_path(st["preset"])).get("override", False)
            if pinned:
                pal = preset_palette(st["preset"])
                print(f"theme: preset '{st['preset']}' is pinned; keeping it")
            else:
                pal = from_wallpaper(p)
                st["mode"] = "wallpaper"
            apply_palette(pal)
        except Exception as e:
            ensure_fallback()
            die(f"theme unchanged: {e}")
        st["wallpaper"] = str(p)
        save_state(st)
    print("theme: applied from", "preset" if pinned else "wallpaper")


def cmd_preset(a):
    with lock():
        try:
            apply_palette(preset_palette(a.name))
        except Exception as e:
            ensure_fallback()
            die(f"theme unchanged: {e}")
        st = load_state()
        st.update(mode="preset", preset="default" if a.name == "43pr-default" else a.name)
        save_state(st)
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
        except Exception as e:
            die(f"apply failed: {e}")
    print("theme: re-rendered")


def cmd_mode(a):
    if a.value not in ("dark", "light"):
        die("mode must be 'dark' or 'light'")
    st = load_state()
    st["mode_appearance"] = a.value
    save_state(st)
    wp = st.get("wallpaper")
    if st.get("mode") == "wallpaper" and wp:
        cmd_wallpaper(argparse.Namespace(path=wp))
    else:
        print(f"theme: mode set to {a.value} (no wallpaper active; will apply on next 'wallpaper' or 'auto')")


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
    s = sp.add_parser("list"); s.set_defaults(f=cmd_list)
    s = sp.add_parser("new"); s.add_argument("name")
    s.add_argument("source", nargs="?", default="default"); s.set_defaults(f=cmd_new)
    s = sp.add_parser("status"); s.set_defaults(f=cmd_status)
    s = sp.add_parser("toggle"); s.set_defaults(f=cmd_toggle)
    a = ap.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()

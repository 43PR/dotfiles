pragma Singleton
import QtQuick
import Quickshell

// ─────────────────────────────────────────────────────────────────────────────
// IconTune.qml — one place for every icon / text nudge on the bar.
//
// Put this file next to Theme.qml (same folder as Bar.qml) and use it from Bar.qml
// as `IconTune.resolve(moduleId, vertical, variant)`.
//
// HOW IT WORKS
//   table[moduleId] holds up to three groups:
//       all → applied on both bar orientations
//       h   → horizontal bar (position top / bottom)
//       v   → vertical bar   (position left / right)
//   Merge order (later wins): defaults → table["*"] → table[id] → table[id + "." + variant]
//   Inside one entry: `all` is applied first, then `h` or `v`.
//   Anything you leave out keeps its default (0 / 1 / null).
//
// FIELDS (px unless noted; +x = right, +y = down, on both orientations)
//   x, y            move icon AND text together (layout size is unchanged)
//   iconX, iconY    move ONLY the icon (glyph, ring gauge, drawn icon)
//   ringIconY       like iconY but only while a ring gauge is shown (null = same as iconY)
//   textX, textY    move ONLY the text / number
//   glyphSize       ADDED to the glyph font size the module already has
//   textSize        ADDED to the text font size the module already has
//   ringSize        ADDED to the ring gauge diameter
//   scaleX, scaleY  stretch the icon visually (1 = none); layout size is unchanged
//   rotation        rotate the icon, degrees clockwise
//   spacing         ADDED to the gap between icon and text
//   pad             ADDED to the module's own padding along the bar (module width on
//                   horizontal bars, a small part of the module height on vertical ones)
//
// VARIANTS
//   A module can pass a variant name (Bar.qml uses "star" for brightness / night light when
//   the STARS icon set is on). Entries named "<id>.<variant>" override the base entry.
//
// DEFAULTS BELOW reproduce the current Bar.qml behaviour, plus the 1 px upward nudges added
// for volume, notifications, power, network, bluetooth and clock. Set a value to 0 to undo it.
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    readonly property var defaults: ({
        x: 0, y: 0,
        iconX: 0, iconY: 0, ringIconY: null,
        textX: 0, textY: 0,
        glyphSize: 0, textSize: 0, ringSize: 0,
        scaleX: 1, scaleY: 1, rotation: 0,
        spacing: 0, pad: 0,
        trayScale: 0.9,
        taskScale: 0.9
    })
    readonly property var table: ({
        // Applied to every module first. Example: "*": { all: { y: 0 } }
        "*": {},
        // ── generic icon buttons (text glyphs) ──
        notif:    { h: { x: -1, y: 0.5, textY: -1 },            v: { x: -1, textY: 0 } },
        wall:     { h: { x: -1, y: 0 },                         v: {} },
        settings: { h: { x: -1, y: 0 },                         v: { x: -1 } },
        power:    { h: { x: -1, y: 1, textY: -1 },              v: { x: -1, textY: 0 } },
        // ── clock (text only) ──
        clock:    { h: { y: 1, textY: -1 },              v: {} },
        // ── network / bluetooth ──
        net:      { h: { x: -1, y: 1, iconY: -1 },              v: { x: -1, iconY: 0 } },
        bt:       { all: { scaleX: 1.2 },
                    h: { x: -1, y: 1, iconY: -1 },              v: { x: -1, iconY: 0 } },
        // ── meters ──
        volume:   { h: { y: 1.25, iconY: -1, textY: -1 }, v: { x: -1, iconY: 0, textY: -1 } },
        // iconY applies to the plain glyph / drawn icon; ringIconY to the ring gauge
        battery:  { h: { y: 1.25, iconY: -1.25, ringIconY: 0, textY: -1 },
                    v: { textY: -1 } },
        bright:   { h: { y: 0 },                         v: { x: -1 } },
        night:    { h: { y: 0 },                         v: { x: -1 } },
        // ── system tray arrow ──
        tray:     { all: { glyphSize: -1 } },
        // STARS icon set: glyph is 2 px smaller than the sun / moon
        "bright.star": { all: { glyphSize: -2 } },
        "night.star":  { all: { glyphSize: -2 } }
    })
    // ───────────────────────── Colours ─────────────────────────
    // Every icon colour role lives here. Bar.qml asks IconTune.color(moduleId, role).
    //   Lookup: colors[moduleId][role] → colors["*"][role] → colorDefaults[role] → colorDefaults.normal
    //   A value is a Theme colour name (see theme() below), a literal like "#ff5555",
    //   or [name, alpha] for a translucent one, e.g. ["accent", 0.35].
    //
    // ROLES
    //   normal / active / warning   icon colour in the default, active (e.g. night light on)
    //                               and warning (low battery, muted, disconnected) states
    //   ringTrack / ringArc / ringWarn   ring gauge background, level arc, level arc in warning
    //   pressed / activeBg / warnBg      state-layer fill behind the icon (press / active / warning)
    //   taskActive                       focused app icon in the open-apps module
    //   net:  ok / off            bt: off / connected / idle     (set by the module's `tone`)
    readonly property var colorDefaults: ({
        normal: "text", active: "accent", warning: "danger",
        ringTrack: ["accent2", 0.2], ringArc: "accent2", ringWarn: "danger",
        pressed: ["accent", 0.35], activeBg: ["accent", 0], warnBg: ["danger", 0.16],
        taskActive: "accent2"
    })
    readonly property var colors: ({
        // Applied to every module first. Example: "*": { normal: "text" }
        "*": {},
        net: { ok: "text", off: "textDim" },
        bt:  { off: "text", connected: "text", idle: "accent" },
        night: { active: "text" }
    })
    // Theme colour by name. Add a case here to expose another Theme colour.
    function theme(name) {
        switch (name) {
        case "bg":      return Theme.bg;
        case "text":    return Theme.text;
        case "textDim": return Theme.textDim;
        case "accent":  return Theme.accent;
        case "accent2": return Theme.accent2;
        case "danger":  return Theme.danger;
        case "border":  return Theme.border;
        default:        return name;     // literal colour such as "#ff5555"
        }
    }
    function color(id, role) {
        const spec = (colors[id] ?? {})[role] ?? colors["*"][role]
                  ?? colorDefaults[role] ?? colorDefaults.normal;
        return Array.isArray(spec) ? Qt.alpha(theme(spec[0]), spec[1]) : theme(spec);
    }
    // Returns one flat object with every field for this module + orientation.
    function resolve(id, vertical, variant) {
        const side = vertical ? "v" : "h";
        const out = Object.assign({}, defaults);
        const layers = [table["*"], table[id], variant ? table[id + "." + variant] : undefined];
        for (const e of layers) {
            if (!e) continue;
            Object.assign(out, e.all ?? {}, e[side] ?? {});
        }
        return out;
    }
}
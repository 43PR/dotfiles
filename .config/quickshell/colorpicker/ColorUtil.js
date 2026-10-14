.pragma library

function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
function pad(n) { var s = Math.round(n).toString(16); return s.length < 2 ? "0" + s : s; }
function hex(c) { return ("#" + pad(c.r) + pad(c.g) + pad(c.b)).toUpperCase(); }

function rgbToHsl(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    var mx = Math.max(r, g, b), mn = Math.min(r, g, b);
    var l = (mx + mn) / 2, h = 0, s = 0, d = mx - mn;
    if (d > 0) {
        s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
        if (mx === r) h = (g - b) / d + (g < b ? 6 : 0);
        else if (mx === g) h = (b - r) / d + 2;
        else h = (r - g) / d + 4;
        h *= 60;
    }
    return { h: h, s: s * 100, l: l * 100 };
}

function hslToRgb(h, s, l) {
    h = ((h % 360) + 360) % 360; s /= 100; l /= 100;
    var c = (1 - Math.abs(2 * l - 1)) * s;
    var x = c * (1 - Math.abs((h / 60) % 2 - 1));
    var m = l - c / 2, r = 0, g = 0, b = 0;
    if (h < 60) { r = c; g = x; }
    else if (h < 120) { r = x; g = c; }
    else if (h < 180) { g = c; b = x; }
    else if (h < 240) { g = x; b = c; }
    else if (h < 300) { r = x; b = c; }
    else { r = c; b = x; }
    return { r: Math.round((r + m) * 255), g: Math.round((g + m) * 255), b: Math.round((b + m) * 255) };
}

function format(c, kind) {
    if (kind === "rgb") return "rgb(" + c.r + ", " + c.g + ", " + c.b + ")";
    if (kind === "hsl") {
        var q = rgbToHsl(c.r, c.g, c.b);
        return "hsl(" + Math.round(q.h) + ", " + Math.round(q.s) + "%, " + Math.round(q.l) + "%)";
    }
    return hex(c);
}

// Accepts #RRGGBB, #RGB, rgb(r,g,b), hsl(h,s%,l%). Returns {r,g,b} or null.
function parse(str) {
    str = String(str).trim();
    var m = /^#?([0-9a-f]{6})$/i.exec(str);
    if (m) { var n = parseInt(m[1], 16); return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 }; }
    m = /^#?([0-9a-f])([0-9a-f])([0-9a-f])$/i.exec(str);
    if (m) return { r: parseInt(m[1] + m[1], 16), g: parseInt(m[2] + m[2], 16), b: parseInt(m[3] + m[3], 16) };
    m = /^rgba?\(\s*(\d+)[\s,]+(\d+)[\s,]+(\d+)/i.exec(str);
    if (m) return { r: clamp(+m[1], 0, 255), g: clamp(+m[2], 0, 255), b: clamp(+m[3], 0, 255) };
    m = /^hsla?\(\s*(-?[\d.]+)(?:deg)?[\s,]+([\d.]+)%?[\s,]+([\d.]+)%?/i.exec(str);
    if (m) return hslToRgb(+m[1], clamp(+m[2], 0, 100), clamp(+m[3], 0, 100));
    return null;
}

function readable(c) {
    return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) / 255 > 0.6 ? "#000000" : "#ffffff";
}

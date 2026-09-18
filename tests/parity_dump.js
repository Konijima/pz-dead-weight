// Loads the maquette's real geometry + anim.js in Node and dumps sample()
// at fixed timestamps for both directions, so Lua can be checked against the
// actual browser code, not a re-typed copy of it.
const fs = require("fs");
const path = require("path");
const root = path.join(__dirname, "..", "docs", "maquettes", "v2");

global.window = global;
const geo = JSON.parse(fs.readFileSync(path.join(root, "assets", "geometry.json"), "utf8"));
window.WS_GEO = geo;

const animSrc = fs.readFileSync(path.join(root, "js", "anim.js"), "utf8");
// anim.js is an IIFE that reads window.WS_GEO and sets window.WSAnim; eval in
// this global context so it behaves exactly as it does in the browser.
eval(animSrc);

const A = window.WSAnim;
const times = [0, 50, 100, 140, 200, 260, 500, 900, 1060, 1200, 1800, 2460];
const target = 62.7;

const rows = [];
for (const mode of ["on", "off"]) {
    for (const t of times) {
        const s = A.sample(mode, t, target);
        rows.push([mode, t, s.alpha, s.dy, s.angle, s.reading, s.visible ? 1 : 0].join("\t"));
    }
}
console.log(rows.join("\n"));

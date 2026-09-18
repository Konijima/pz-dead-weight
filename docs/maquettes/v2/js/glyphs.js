// Draws text from Project Zomboid's own bitmap font pages (zomboidLarge,
// UI-scale 4x for the numerals, 2x for the unit). No desktop font is used
// anywhere in a readout. Tinting mirrors Lua's drawTexture(..., r, g, b, a).
(function () {
  var atlas = null, sets = null, tinted = {};

  function load(cb) {
    fetch('v2/assets/glyphs.json').then(function (r) { return r.json(); })
      .then(function (j) {
        sets = j;
        var im = new Image();
        im.onload = function () { atlas = im; cb(); };
        im.src = 'v2/assets/glyphs.png';
      });
  }

  // One pre-tinted copy of the atlas per colour: the slices are then blitted
  // 1:1, so every glyph stays pixel-exact (no scaling, no smoothing).
  function tint(key, rgb) {
    if (tinted[key]) return tinted[key];
    var c = document.createElement('canvas');
    c.width = atlas.width; c.height = atlas.height;
    var g = c.getContext('2d');
    g.drawImage(atlas, 0, 0);
    g.globalCompositeOperation = 'source-in';
    g.fillStyle = 'rgb(' + rgb[0] + ',' + rgb[1] + ',' + rgb[2] + ')';
    g.fillRect(0, 0, c.width, c.height);
    tinted[key] = c;
    return c;
  }

  function measure(setName, text) {
    var s = sets[setName].glyphs, w = 0;
    for (var i = 0; i < text.length; i++) {
      var g = s[text[i]];
      if (g) w += g.xa;
    }
    return w;
  }

  // x = left edge, y = BASELINE, both in readout-local pixels.
  function draw(ctx, setName, text, x, y, rgb, alpha) {
    var set = sets[setName], src = tint(setName + rgb.join('_'), rgb), pen = x;
    var prev = ctx.globalAlpha;
    ctx.globalAlpha = prev * (alpha === undefined ? 1 : alpha);
    ctx.imageSmoothingEnabled = false;
    for (var i = 0; i < text.length; i++) {
      var g = set.glyphs[text[i]];
      if (!g) continue;
      if (g.w > 0 && g.h > 0) {
        ctx.drawImage(src, g.sx, g.sy, g.w, g.h,
          Math.round(pen + g.xo), Math.round(y - set.base + g.yo), g.w, g.h);
      }
      pen += g.xa;
    }
    ctx.globalAlpha = prev;
    ctx.imageSmoothingEnabled = true;
  }

  function info(setName) { return sets[setName]; }

  window.WSGlyphs = { load: load, draw: draw, measure: measure, info: info };
})();

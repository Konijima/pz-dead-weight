// The two readouts. Everything here is a texture blit, a rotated texture blit
// or an axis-aligned rectangle: the set of primitives PZ's Lua UI offers.
(function () {
  var G = window.WS_GEO, A = window.WSAnim, T = {};
  var snap = Math.round;                 // pixel snapping only, never a value
  var CREAM = [238, 232, 216], DIM = [152, 146, 130];

  function loadTextures(cb) {
    var names = ['plate', 'beam', 'poise', 'slab'], left = names.length;
    names.forEach(function (n) {
      var im = new Image();
      im.onload = function () { T[n] = im; if (--left === 0) cb(); };
      im.src = 'v2/assets/' + n + '.png';
    });
  }

  function graduation(c, w) {
    var t = G.track, active = A.bandOf(w);
    for (var k = G.weight.min; k <= G.weight.max + 0.001; k += t.minorEvery) {
      var major = (k % t.majorEvery === 0) || k === G.weight.min || k === G.weight.max;
      c.fillStyle = major ? 'rgba(48,42,31,0.95)' : 'rgba(74,66,50,0.72)';
      c.fillRect(snap(A.mapX(k)) - (major ? 1 : 0), t.tickBaseY - (major ? t.majorH : t.minorH),
        major ? 2 : 1, major ? t.majorH : t.minorH);
    }
    G.bands.forEach(function (b, i) {
      var x0 = snap(A.mapX(A.lower(i))), x1 = snap(A.mapX(b.upTo));
      var on = b === active;
      c.globalAlpha = on ? 1 : 0.40;
      c.fillStyle = 'rgb(' + b.colour.join(',') + ')';
      c.fillRect(x0, t.bandY, x1 - x0, t.bandH);
      if (on) {
        c.fillRect(x0, t.bandY - 2, x1 - x0, t.bandH + 4);
        c.fillStyle = 'rgba(28,24,18,0.85)';
        c.fillRect(x0 - 1, t.bandY - 3, x1 - x0 + 2, 1);
        c.fillRect(x0 - 1, t.bandY + t.bandH + 2, x1 - x0 + 2, 1);
      }
      c.globalAlpha = 1;
      if (i) { c.fillStyle = 'rgba(40,35,26,0.9)'; c.fillRect(x0, t.bandY - 3, 1, t.bandH + 3); }
    });
    c.fillStyle = 'rgba(40,35,26,0.55)';
    c.fillRect(snap(A.mapX(G.weight.min)), t.bandY + t.bandH, t.w + 1, 1);
  }

  function numeral(c, w, unit, alpha) {
    var s = G.slab, val = A.fmt(w, unit);
    var nw = WSGlyphs.measure('num', val), uw = WSGlyphs.measure('unit', unit);
    var x = snap(s.x + (s.w - (nw + 9 + uw)) / 2), base = s.y + 32;
    WSGlyphs.draw(c, 'num', val, x, base, CREAM, alpha);
    WSGlyphs.draw(c, 'unit', unit, x + nw + 9, base, DIM, alpha);
  }

  function beamHead(c, st, unit) {
    var b = G.beam, p = G.poise, s = G.slab, band = A.bandOf(st.reading);
    c.save();
    c.globalAlpha = st.alpha;
    c.translate(0, st.dy);
    c.drawImage(T.plate, 0, 0);
    graduation(c, st.reading);
    c.save();
    c.translate(b.pivotX, b.pivotY);
    c.rotate(st.angle * Math.PI / 180);
    c.drawImage(T.beam, 0, -b.h / 2);
    c.restore();
    var L = A.mapX(st.reading) - b.pivotX, a = st.angle * Math.PI / 180;
    c.drawImage(T.poise, snap(b.pivotX + L * Math.cos(a) - p.w / 2),
      snap(b.pivotY + L * Math.sin(a) - p.h / 2));
    var st2 = G.stops;          // the two stops the beam tip floats between
    c.fillStyle = 'rgba(214,208,188,0.92)';
    c.fillRect(st2.x, b.pivotY - st2.gap - 1, st2.w, 2);
    c.fillRect(st2.x, b.pivotY + st2.gap - 1, st2.w, 2);
    c.fillStyle = 'rgba(214,208,188,0.30)';
    c.fillRect(st2.x + st2.w, b.pivotY - st2.gap - 1, 1, st2.gap * 2 + 2);
    c.drawImage(T.slab, s.x, s.y);
    c.fillStyle = 'rgb(' + band.colour.join(',') + ')';
    c.fillRect(s.x, s.y, s.w, 2);
    numeral(c, st.reading, unit, 1);
    c.restore();
  }

  function nativePanel(c, st, unit) {
    var p = G.panel, band = A.bandOf(st.reading), val = A.fmt(st.reading, unit);
    c.save();
    c.globalAlpha = st.alpha;
    c.translate(0, st.dy);
    c.fillStyle = 'rgba(0,0,0,0.74)';
    c.fillRect(0, 0, p.w, p.h);
    c.strokeStyle = 'rgba(255,255,255,0.13)';
    c.lineWidth = 1;
    c.strokeRect(0.5, 0.5, p.w - 1, p.h - 1);
    c.fillStyle = 'rgb(' + band.colour.join(',') + ')';
    c.fillRect(0, 0, 3, p.h);
    var nw = WSGlyphs.measure('num', val), uw = WSGlyphs.measure('unit', unit);
    var x = snap(3 + (p.w - 3 - (nw + 9 + uw)) / 2);
    WSGlyphs.draw(c, 'num', val, x, 38, CREAM, 1);
    WSGlyphs.draw(c, 'unit', unit, x + nw + 9, 38, DIM, 1);
    c.restore();
  }

  window.WSDraw = { load: loadTextures, beamHead: beamHead, panel: nativePanel, tex: T };
})();

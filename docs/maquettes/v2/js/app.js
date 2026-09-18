// Page wiring. Both frames and every filmstrip cell are sampled from
// WSAnim.sample(); there is no second copy of the motion anywhere.
(function () {
  var G = window.WS_GEO, A = window.WSAnim, S = window.WSScene;
  var frames = [];

  function anchor(kind) {
    var o = kind === 'beam' ? G.offset : G.panel;
    return { x: S.CX + o.dx, y: S.CY + o.dy,
      w: kind === 'beam' ? G.readout.w : G.panel.w,
      h: kind === 'beam' ? G.readout.h : G.panel.h };
  }

  function unit(f) { return f.unit; }

  function paint(f, tOverride, unitOverride) {
    var c = f.ctx, a = anchor(f.kind);
    c.setTransform(1, 0, 0, 1, 0, 0);
    S.draw(c, a.x, a.y);
    var t = tOverride === undefined ? (performance.now() - f.t0) : tOverride;
    if (f.mode === 'idle') return;
    var st = A.sample(f.mode, t, f.weight);
    if (!st.visible) { f.mode = 'idle'; return; }
    c.save();
    c.translate(a.x, a.y);
    if (f.kind === 'beam') window.WSDraw.beamHead(c, st, unitOverride || unit(f));
    else window.WSDraw.panel(c, st, unitOverride || unit(f));
    c.restore();
  }

  function loop() {
    frames.forEach(function (f) { paint(f); });
    requestAnimationFrame(loop);
  }

  function crop(f, mode, t, u) {
    var a = anchor(f.kind), pad = 26;
    var save = [f.mode, f.t0];
    f.mode = mode;
    paint(f, t, u);
    f.mode = save[0]; f.t0 = save[1];
    var o = document.createElement('canvas');
    o.width = a.w + pad * 2; o.height = a.h + pad * 2;
    o.getContext('2d').drawImage(f.canvas, a.x - pad, a.y - pad,
      o.width, o.height, 0, 0, o.width, o.height);
    return o;
  }

  function buildStrip(f) {
    var T = A.T, cells = [
      ['apparition', 'on', 60, null], ['bascule', 'on', 200, null],
      ['glissement', 'on', 700, null], ['stabilisation', 'on', 1180, null],
      ['stable kg', 'on', T.onEnd, 'kg'], ['stable lb', 'on', T.onEnd, 'lb'],
      ['retrait', 'off', 180, null]
    ];
    var host = document.getElementById('strip-' + f.kind);
    host.innerHTML = '';
    cells.forEach(function (cell) {
      var fig = document.createElement('figure');
      var cv = crop(f, cell[1], cell[2], cell[3]);
      cv.className = 'cell';
      var cap = document.createElement('figcaption');
      cap.innerHTML = '<b>' + cell[0] + '</b><span>' +
        (cell[1] === 'on' ? 'montee' : 'descente') + ' t = ' + cell[2] + ' ms</span>';
      fig.appendChild(cv); fig.appendChild(cap);
      host.appendChild(fig);
    });
  }

  function makeFrame(kind) {
    var cv = document.getElementById('frame-' + kind);
    var f = { kind: kind, canvas: cv, ctx: cv.getContext('2d'), weight: G.weight.start,
      unit: 'kg', mode: 'idle', t0: 0 };
    try { f.unit = localStorage.getItem('ws_unit_' + kind) || 'kg'; } catch (e) {}
    cv.addEventListener('click', function (ev) {
      var r = cv.getBoundingClientRect(), a = anchor(kind);
      var x = (ev.clientX - r.left) * 1920 / r.width;
      var y = (ev.clientY - r.top) * 1080 / r.height;
      if (f.mode === 'idle') return;
      if (x < a.x || x > a.x + a.w || y < a.y || y > a.y + a.h) return;
      f.unit = f.unit === 'kg' ? 'lb' : 'kg';
      try { localStorage.setItem('ws_unit_' + kind, f.unit); } catch (e) {}
      buildStrip(f);
    });
    frames.push(f);
    return f;
  }

  window.WSApp = { frames: frames, makeFrame: makeFrame, buildStrip: buildStrip,
    paint: paint, loop: loop, anchor: anchor, crop: crop };
})();

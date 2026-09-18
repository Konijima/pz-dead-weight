// Boot: load the game glyph atlas and the baked textures, then wire the page.
(function () {
  var G = window.WS_GEO, A = window.WSAnim, App = window.WSApp;

  function put(id, v) {
    var el = document.getElementById(id);
    if (el) el.textContent = v;
  }

  function fillSpecs() {
    var T = A.T, b = G.beam;
    put('s-size', G.readout.w + ' x ' + G.readout.h + ' px');
    put('s-off', '+' + G.offset.dx + ' px en x, ' + G.offset.dy + ' px en y');
    put('s-plate', G.plate.w + ' x ' + G.plate.h);
    put('s-beam', b.len + ' x ' + b.h + ', pivot local ' + b.pivotX + ' / ' + b.pivotY +
      ', rotation max ' + b.maxDeg + ' deg');
    put('s-poise', G.poise.w + ' x ' + G.poise.h);
    put('s-stops', G.stops.w + ' x ' + G.stops.h);
    put('s-slab', G.slab.w + ' x ' + G.slab.h);
    put('s-track', 'x0 = ' + G.track.x0 + ', largeur = ' + G.track.w +
      ' px pour ' + G.weight.min + ' a ' + G.weight.max + ' kg');
    put('s-tim', T.appear + ' / ' + T.tipDur + ' / ' + T.hold + ' / ' + T.slide +
      ' / ' + T.settle + ' ms, total ' + T.onEnd + ' ms');
    put('s-off2', T.offFall + ' + ' + T.offFade + ' ms, total ' + T.offEnd + ' ms');
    put('s-damp', 'A(t) = -' + b.maxDeg + ' * exp(-t / ' + T.tau +
      ' ms) * cos(2*pi*' + T.freq + '*t)');
    put('s-psize', G.panel.w + ' x ' + G.panel.h + ' px');
    put('s-poff', '+' + G.panel.dx + ' px en x, ' + G.panel.dy + ' px en y');
    var ni = WSGlyphs.info('num'), ui = WSGlyphs.info('unit');
    put('s-font', 'zomboidLarge (Noto Sans SemiBold) : chiffres depuis ' + ni.source +
      ', unite depuis ' + ui.source);
    put('s-fonth', 'chiffre "8" = ' + ni.glyphs['8'].h + ' px de haut, avance ' +
      ni.glyphs['8'].xa + ' px; unite "k" = ' + ui.glyphs.k.h + ' px');
  }

  function wire(f) {
    var k = f.kind;
    document.getElementById('on-' + k).onclick = function () {
      f.mode = 'on'; f.t0 = performance.now(); App.buildStrip(f);
    };
    document.getElementById('off-' + k).onclick = function () {
      if (f.mode === 'idle') return;
      f.mode = 'off'; f.t0 = performance.now();
    };
    var sl = document.getElementById('w-' + k);
    sl.value = f.weight;
    sl.oninput = function () {
      f.weight = parseFloat(sl.value);
      put('wv-' + k, f.weight.toFixed(1) + ' kg');
      if (f.mode === 'on') { f.t0 = performance.now() - A.T.onEnd; }
      App.buildStrip(f);
    };
    put('wv-' + k, f.weight.toFixed(1) + ' kg');
  }

  WSGlyphs.load(function () {
    window.WSDraw.load(function () {
      fillSpecs();
      ['beam', 'panel'].forEach(function (k) {
        var f = App.makeFrame(k);
        wire(f);
        f.mode = 'on';
        f.t0 = performance.now() - A.T.onEnd;    // page opens on the settled state
        App.buildStrip(f);
      });
      App.loop();
      window.WS_READY = true;
    });
  });
})();

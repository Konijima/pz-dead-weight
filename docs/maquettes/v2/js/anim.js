// The single animation model. Both directions and every filmstrip frame are
// sampled from sample() below; nothing is hand posed.
(function () {
  var G = window.WS_GEO;
  var W = G.weight;

  // THE mapping. Poise position, graduation ticks and the painted band zones
  // all go through this one function, in readout-local pixels.
  function mapX(w) {
    var t = (Math.min(W.max, Math.max(W.min, w)) - W.min) / (W.max - W.min);
    return G.track.x0 + t * G.track.w;
  }
  function unmapX(x) {
    var t = (x - G.track.x0) / G.track.w;
    return W.min + t * (W.max - W.min);
  }
  function bandOf(w) {
    for (var i = 0; i < G.bands.length; i++) {
      var b = G.bands[i];
      if (b.inc ? w <= b.upTo : w < b.upTo) return b;
    }
    return G.bands[G.bands.length - 1];
  }
  function lower(i) { return i === 0 ? W.min : G.bands[i - 1].upTo; }

  // Easing, written so a Lua tween can reproduce it literally.
  var ease = {
    outCubic: function (t) { return 1 - Math.pow(1 - t, 3); },
    outQuad: function (t) { return 1 - (1 - t) * (1 - t); },
    inQuad: function (t) { return t * t; },
    inOutCubic: function (t) {
      return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
    }
  };

  var T = {
    appear: 160, tipDur: 140, hold: 120, slide: 800,
    settle: 1400, tau: 340, freq: 2.3,
    offFall: 120, offFade: 220
  };
  T.slideStart = T.tipDur + T.hold;            // 260
  T.settleStart = T.slideStart + T.slide;      // 1060
  T.onEnd = T.settleStart + T.settle;          // 2460
  T.offEnd = T.offFall + T.offFade;            // 340

  function clamp01(v) { return v < 0 ? 0 : v > 1 ? 1 : v; }

  // mode 'on' | 'off'; t in ms from the start of that move; target in kg.
  // Returns everything a renderer needs: no renderer computes its own motion.
  function sample(mode, t, target) {
    var s = { alpha: 1, dy: 0, angle: 0, reading: target, visible: true };
    if (mode === 'off') {
      var f = clamp01(t / T.offFall);
      s.angle = G.beam.maxDeg * ease.outQuad(f);          // tip drops away
      var g = clamp01((t - T.offFall) / T.offFade);
      s.alpha = 1 - ease.inQuad(g);
      s.dy = 8 * ease.inQuad(g);
      s.visible = t < T.offEnd;
      return s;
    }
    s.alpha = ease.outCubic(clamp01(t / T.appear));
    s.dy = 10 * (1 - ease.outCubic(clamp01(t / T.appear)));
    if (t < T.slideStart) {
      s.angle = -G.beam.maxDeg * ease.outQuad(clamp01(t / T.tipDur));
      s.reading = W.min;
    } else if (t < T.settleStart) {
      var p = ease.inOutCubic(clamp01((t - T.slideStart) / T.slide));
      s.angle = -G.beam.maxDeg;
      s.reading = unmapX(mapX(W.min) + (mapX(target) - mapX(W.min)) * p);
    } else {
      var u = (t - T.settleStart) / 1000;                 // seconds
      s.angle = -G.beam.maxDeg * Math.exp(-u * 1000 / T.tau) *
        Math.cos(2 * Math.PI * T.freq * u);
      s.reading = target;
    }
    return s;
  }

  window.WSAnim = {
    mapX: mapX, unmapX: unmapX, bandOf: bandOf, lower: lower,
    sample: sample, T: T, ease: ease,
    fmt: function (kg, unit) {
      return (unit === 'lb' ? kg * 2.20462 : kg).toFixed(1);
    }
  };
})();

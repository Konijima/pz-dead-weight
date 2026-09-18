// Sober stand-in for the game scene: a wall, a floor, the medical scale drawn
// simply, and an abstract character marker standing on its platform. Present
// only so the link between the object and the readout reads.
(function () {
  var CX = 960, CY = 540;

  function floorGrid(c) {
    c.save();
    c.strokeStyle = 'rgba(190,210,200,0.075)';
    c.lineWidth = 1;
    for (var i = -12; i <= 24; i++) {
      c.beginPath();
      c.moveTo(i * 120 - 300, 726); c.lineTo(i * 120 + 700, 1080);
      c.moveTo(i * 120 + 1520, 726); c.lineTo(i * 120 + 520, 1080);
      c.stroke();
    }
    c.restore();
  }

  function scaleObject(c) {
    for (var s = 0; s < 6; s++) {                  // contact shadow on the floor
      c.fillStyle = 'rgba(0,0,0,' + (0.22 - s * 0.034).toFixed(3) + ')';
      c.fillRect(880 - s * 17, 718 + s * 9, 152 + s * 34, 9);
    }
    c.fillStyle = '#121312';                       // platform
    c.fillRect(888, 698, 136, 20);
    c.fillStyle = 'rgba(255,255,255,0.07)';
    for (var i = 0; i < 5; i++) c.fillRect(894 + i * 27, 702, 19, 2);
    c.fillStyle = '#0a0b0a';
    c.fillRect(888, 716, 136, 4);
    c.fillStyle = '#cdc6b2';                       // column
    c.fillRect(905, 464, 12, 236);
    c.fillStyle = 'rgba(0,0,0,0.30)';
    c.fillRect(914, 464, 3, 236);
    c.fillStyle = '#ded7c3';                       // head, seen small
    c.fillRect(869, 438, 76, 26);
    c.fillStyle = 'rgba(0,0,0,0.35)';
    c.fillRect(869, 460, 76, 4);
    c.fillStyle = '#17171a';
    c.fillRect(874, 446, 66, 6);
    c.fillStyle = '#a8a294';
    c.fillRect(909, 443, 5, 12);
  }

  function room(c) {
    c.fillStyle = 'rgba(255,255,255,0.022)';       // wainscot band
    c.fillRect(0, 556, 1920, 164);
    c.fillStyle = 'rgba(0,0,0,0.26)';
    c.fillRect(0, 554, 1920, 2);
    c.fillStyle = '#2b3230';                       // doorway, echoes the sprite
    c.fillRect(1496, 288, 178, 432);
    c.fillStyle = 'rgba(0,0,0,0.30)';
    c.fillRect(1496, 288, 178, 5);
    c.fillRect(1496, 288, 5, 432);
    c.fillStyle = 'rgba(255,255,255,0.05)';
    c.fillRect(1669, 288, 5, 432);
    c.fillStyle = 'rgba(0,0,0,0.22)';
    c.fillRect(1520, 318, 130, 172);
    c.fillRect(1520, 512, 130, 178);
    c.fillStyle = 'rgba(190,210,200,0.022)';       // light spilling on the floor
    c.fillRect(1496, 726, 178, 58);
  }

  function character(c) {
    c.fillStyle = '#5f6a70';
    c.strokeStyle = 'rgba(12,14,15,0.85)';
    c.lineWidth = 2;
    c.beginPath(); c.arc(CX, 472, 17, 0, Math.PI * 2); c.fill(); c.stroke();
    c.beginPath();
    c.moveTo(CX - 23, 502); c.lineTo(CX + 23, 502);
    c.lineTo(CX + 18, 612); c.lineTo(CX - 18, 612);
    c.closePath(); c.fill(); c.stroke();
    [[-16, -3], [4, 17]].forEach(function (p) {
      c.beginPath();
      c.moveTo(CX + p[0], 612); c.lineTo(CX + p[1], 612);
      c.lineTo(CX + p[1] - 1, 700); c.lineTo(CX + p[0] + 1, 700);
      c.closePath(); c.fill(); c.stroke();
    });
  }

  function centreMark(c, ax, ay) {
    c.save();
    c.strokeStyle = 'rgba(214,232,224,0.34)';
    c.lineWidth = 1;
    c.beginPath();
    c.moveTo(CX - 46, CY + 0.5); c.lineTo(CX + 46, CY + 0.5);
    c.moveTo(CX + 0.5, CY - 46); c.lineTo(CX + 0.5, CY + 46);
    c.stroke();
    c.beginPath(); c.arc(CX + 0.5, CY + 0.5, 6, 0, Math.PI * 2); c.stroke();
    c.setLineDash([4, 5]);
    c.strokeStyle = 'rgba(214,232,224,0.22)';
    c.beginPath();
    c.moveTo(CX + 0.5, CY + 0.5); c.lineTo(ax + 0.5, CY + 0.5);
    c.lineTo(ax + 0.5, ay + 0.5);
    c.stroke();
    c.restore();
  }

  function scene(c, anchorX, anchorY) {
    c.fillStyle = '#242b29'; c.fillRect(0, 0, 1920, 726);
    c.fillStyle = 'rgba(0,0,0,0.20)'; c.fillRect(0, 0, 1920, 210);
    c.fillStyle = '#1b1f1e'; c.fillRect(0, 720, 1920, 6);
    c.fillStyle = '#161918'; c.fillRect(0, 726, 1920, 354);
    floorGrid(c);
    room(c);
    scaleObject(c);
    character(c);
    centreMark(c, anchorX, anchorY);
  }

  window.WSScene = { draw: scene, CX: CX, CY: CY };
})();

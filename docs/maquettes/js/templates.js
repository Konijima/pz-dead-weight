// Markup builders for the three HUD directions. Pure DOM strings so the
// same template can be reused full-size in the stage and mini-size in the
// filmstrip crops.

function buildDial(){
  var ticks='';
  var nums=[35,50,65,80,95,110,125];
  for(var i=0;i<nums.length;i++){
    var t=i/(nums.length-1);
    var ang=-108+t*216; // sweep matches band conic gradient
    ticks+='<div class="dial-tick" style="transform:rotate('+ang+'deg)"></div>';
  }
  return '<div class="dial">'+
    '<div class="dial-bands"></div>'+ticks+
    '<div class="dial-face-plate">POIDS</div>'+
    '<div class="dial-needle" id="dial-needle"></div>'+
    '<div class="dial-pivot"></div>'+
    '<div class="unit-tag" id="dial-unit">kg</div>'+
    '</div>';
}

function buildBeam(){
  var ticks='';
  for(var i=0;i<=13;i++){
    ticks+='<div class="beam-tick" style="left:'+(i*20)+'px"></div>';
  }
  return '<div class="beam-unit">'+
    '<div class="beam-post"></div>'+
    '<div class="beam-track">'+ticks+'</div>'+
    '<div class="beam-poise" id="beam-poise"></div>'+
    '<div class="beam-numplate">'+
      '<div class="beam-value" id="beam-value">80</div>'+
      '<div class="beam-unit-tag" id="beam-unit">kg</div>'+
    '</div></div>';
}

function buildNative(){
  return '<div class="native-panel">'+
    '<div class="band-strip" id="native-band"></div>'+
    '<div class="native-value" id="native-value">80</div>'+
    '<div class="native-unit" id="native-unit">KG</div>'+
    '<div class="native-cursor-hint">clic: unite</div>'+
    '</div>';
}

// band color lookup shared by dial hint (implicit via needle position),
// beam and native (explicit strip).
function bandColor(kg){
  if(kg<=50||kg>=100) return 'var(--band-crit)';
  if(kg<=65||kg>=85) return 'var(--band-warn)';
  return 'var(--band-ok)';
}

// needle angle: -108deg (35kg) .. +108deg (125kg), clamped.
function dialAngle(kg){
  var lo=35,hi=125;
  var c=Math.max(lo,Math.min(hi,kg));
  var t=(c-lo)/(hi-lo);
  return (-108+t*216).toFixed(1)+'deg';
}

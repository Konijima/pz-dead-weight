var DIRS=['dial','beam','native'];
var active='dial';
var unit='kg';
var weightKg=80;

function kgToLb(kg){return Math.round(kg*2.20462);}
function displayValue(kg){return unit==='kg'?Math.round(kg):kgToLb(kg);}
function displayUnit(){return unit==='kg'?'kg':'lb';}

function paint(dir,root,kg,u){
  var val=u==='kg'?Math.round(kg):kgToLb(kg);
  var col=bandColor(kg);
  if(dir==='dial'){
    var n=root.querySelector('.dial-needle');
    n.style.transform='translate(-50%,-100%) rotate('+dialAngle(kg)+')';
    root.querySelector('.unit-tag').textContent=u;
  } else if(dir==='beam'){
    var lo=35,hi=130,t=(Math.max(lo,Math.min(hi,kg))-lo)/(hi-lo);
    root.querySelector('.beam-poise').style.left=(20+t*214)+'px';
    root.querySelector('.beam-value').textContent=val;
    root.querySelector('.beam-unit-tag').textContent=u;
  } else if(dir==='native'){
    root.querySelector('.native-value').textContent=val;
    root.querySelector('.native-unit').textContent=u.toUpperCase();
    root.querySelector('.band-strip').style.setProperty('--band-color',col);
  }
}

function mountEl(dir){return document.getElementById('mount-'+dir);}

function initStage(){
  mountEl('dial').innerHTML=buildDial();
  mountEl('beam').innerHTML=buildBeam();
  mountEl('native').innerHTML=buildNative();
  DIRS.forEach(function(d){paint(d,mountEl(d),weightKg,unit);});
  showActive();
}

function showActive(){
  DIRS.forEach(function(d){
    mountEl(d).style.display=(d===active)?'block':'none';
  });
  document.querySelectorAll('.tab-btn').forEach(function(b){
    b.classList.toggle('active',b.dataset.dir===active);
  });
}

function setState(cls){
  var m=mountEl(active);
  m.className='readout-mount st-'+cls;
}

document.getElementById('tabs').addEventListener('click',function(e){
  if(!e.target.dataset.dir)return;
  active=e.target.dataset.dir;showActive();
});
document.getElementById('btn-appear').onclick=function(){setState('appear');};
document.getElementById('btn-settle').onclick=function(){
  setState('settle');
  setTimeout(function(){setState('settled');},1150);
};
document.getElementById('btn-leave').onclick=function(){setState('leave');};
document.getElementById('btn-reset').onclick=function(){
  mountEl(active).className='readout-mount';
};
document.getElementById('btn-unit').onclick=function(){
  unit=(unit==='kg')?'lb':'kg';
  DIRS.forEach(function(d){paint(d,mountEl(d),weightKg,unit);});
};
document.getElementById('weight-range').oninput=function(e){
  weightKg=parseInt(e.target.value,10);
  document.getElementById('weight-value').textContent=weightKg;
  DIRS.forEach(function(d){paint(d,mountEl(d),weightKg,unit);});
};

initStage();
DIRS.forEach(function(d){mountEl(d).className='readout-mount st-settled';});
buildFilmstrips();
buildSpecs();

// Frozen state snapshots per direction, five states, rendered small and
// without transitions so a single screenshot proves every state at once.
var STATE_LABELS=[
  ['appear','Apparition'],['overshoot','Stabilisation (survol)'],
  ['settled-kg','Etabli - kg'],['settled-lb','Etabli - lb'],
  ['leave','Depart']
];

function buildOne(dir){
  var el=document.createElement('div');
  el.className='readout-mount';
  el.style.position='static';
  el.style.transition='none';
  if(dir==='dial')el.innerHTML=buildDial();
  if(dir==='beam')el.innerHTML=buildBeam();
  if(dir==='native')el.innerHTML=buildNative();
  return el;
}

function applyFrozen(dir,el,stateKey){
  var kg=80;
  if(stateKey==='appear'){
    el.style.opacity='0.45';el.style.transform='scale(0.7)';
    paint(dir,el,kg,'kg');
  } else if(stateKey==='overshoot'){
    el.style.opacity='1';el.style.transform='scale(1)';
    paint(dir,el,kg+22,'kg'); // exaggerated to show overshoot pose
    if(dir==='dial')el.querySelector('.dial-face-plate').textContent='POIDS';
  } else if(stateKey==='settled-kg'){
    el.style.opacity='1';el.style.transform='scale(1)';
    paint(dir,el,kg,'kg');
  } else if(stateKey==='settled-lb'){
    el.style.opacity='1';el.style.transform='scale(1)';
    paint(dir,el,kg,'lb');
  } else if(stateKey==='leave'){
    el.style.opacity='0.3';el.style.transform='scale(0.88)';
    paint(dir,el,kg,'kg');
  }
}

function dirTitle(dir){
  return dir==='dial'?'A. Cadran diegetique':
    dir==='beam'?'B. Fleau a curseur':'C. Panneau natif minimal';
}

function buildFilmstrips(){
  var host=document.getElementById('filmstrips');
  DIRS.forEach(function(dir){
    var wrap=document.createElement('div');
    wrap.className='filmstrip';
    var h=document.createElement('h3');h.textContent=dirTitle(dir);
    wrap.appendChild(h);
    var frames=document.createElement('div');frames.className='frames';
    STATE_LABELS.forEach(function(pair){
      var card=document.createElement('div');card.className='frame-card';
      var crop=document.createElement('div');crop.className='crop';
      var inst=buildOne(dir);
      applyFrozen(dir,inst,pair[0]);
      crop.appendChild(inst);
      var lbl=document.createElement('span');lbl.textContent=pair[1];
      card.appendChild(crop);card.appendChild(lbl);
      frames.appendChild(card);
    });
    wrap.appendChild(frames);
    host.appendChild(wrap);
  });
}

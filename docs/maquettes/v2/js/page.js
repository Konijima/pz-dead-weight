// Page chrome only: the 1:1 zoom toggle used for the true scale captures.
(function () {
  var btn = document.getElementById('zoom-toggle');
  var state = document.getElementById('zoom-state');
  function apply(mode) {
    document.body.dataset.zoom = mode;
    btn.textContent = mode === 'one'
      ? 'Revenir a l\'affichage reduit'
      : 'Passer a l\'echelle reelle 1:1';
    state.textContent = mode === 'one'
      ? 'Echelle reelle. Un pixel du cadre vaut un pixel a 1920 x 1080.'
      : 'Affichage reduit a la largeur de la page. Le cadre fait 1920 x 1080 px.';
  }
  btn.onclick = function () {
    apply(document.body.dataset.zoom === 'one' ? 'fit' : 'one');
  };
  window.WSZoom = apply;
})();

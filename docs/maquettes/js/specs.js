function buildSpecs(){
  var host=document.getElementById('specs');
  host.innerHTML=
  '<div class="spec-card"><h3>A. Cadran diegetique</h3><ul>'+
  '<li>Taille : cadran 200x200 px, aiguille 4x70 px.</li>'+
  '<li>Ancrage : centre du cadran a (+260,-233) px du centre ecran.</li>'+
  '<li>Apparition 150 ms (fondu + echelle 0.6-1). Stabilisation 1100 ms, '+
  'courbe a survol (aiguille depasse puis revient). Depart 200 ms.</li>'+
  '<li>Assets a dessiner : cadran.png (fond + graduations + bandes '+
  'imprimees), aiguille.png (rotation texture), moyeu.png.</li>'+
  '<li>Indice de bande : couleur des bandes imprimees sur le cadran, '+
  'pas de texte ajoute.</li></ul></div>'+

  '<div class="spec-card"><h3>B. Fleau a curseur</h3><ul>'+
  '<li>Taille : bloc 300x190 px (rail 260x16, curseur 26x34, plaque '+
  'chiffree 300x100).</li>'+
  '<li>Ancrage : coin haut-gauche a (+140,-360) px du centre ecran.</li>'+
  '<li>Apparition 150 ms (fondu + glissement vertical 8 px). '+
  'Stabilisation 1100 ms, curseur glisse avec survol. Depart 200 ms.</li>'+
  '<li>Assets a dessiner : rail.png, curseur.png, plaque.png (numeral '+
  'via police du jeu, pas une texture).</li>'+
  '<li>Indice de bande : aucun direct (le curseur seul porte le sens); '+
  'a eviter si on veut l\'indice visuel demande.</li></ul></div>'+

  '<div class="spec-card"><h3>C. Panneau natif minimal</h3><ul>'+
  '<li>Taille : 180x96 px, liseret de bande 5 px de large.</li>'+
  '<li>Ancrage : coin haut-gauche a (+190,-310) px du centre ecran.</li>'+
  '<li>Apparition 120 ms (fondu + glissement vertical 6 px). Pas de '+
  'survol (le chiffre defile ou saute au chiffre final en 200-300 ms). '+
  'Depart 150 ms.</li>'+
  '<li>Assets a dessiner : panneau_neuf_tranches.png (fond + bordure), '+
  'reste = rectangles pleins + police du jeu.</li>'+
  '<li>Indice de bande : liseret de couleur a gauche, direct et lisible '+
  'sans texte ajoute.</li></ul></div>'+

  '<div class="spec-card reco"><h3>Recommandation</h3>'+
  '<p><b>1. C - Panneau natif minimal.</b> Le plus proche du vocabulaire '+
  'B42 (panneaux sombres translucides a bordure fine), le moins cher a '+
  'produire (une seule texture nine-slice, le reste en rectangles et '+
  'police du jeu), et le liseret de bande repond exactement a la '+
  'consigne « indice visuel sans texte ajoute ». Risque le plus bas de '+
  'detoner avec le reste du HUD B42.</p>'+
  '<p><b>2. A - Cadran diegetique.</b> Le plus in-fiction (une vraie '+
  'balance a aiguille) et le plus lisible d\'un coup d\'oeil grace aux '+
  'bandes imprimees, mais coute trois textures et une rotation en '+
  'continu ; a garder si le proprietaire veut un objet plus « physique » que '+
  'HUD.</p>'+
  '<p><b>3. B - Fleau a curseur.</b> Le plus long a lire (il faut '+
  'suivre le curseur puis le chiffre) et le moins bon pour l\'indice de '+
  'bande sans ajouter de texte ; a ecarter sauf si l\'ambiance « vieille '+
  'balance de medecin » prime sur la lisibilite.</p></div>';
}

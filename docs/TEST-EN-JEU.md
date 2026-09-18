# Verification en jeu, HUD poids v2

Ordre suggere. Un scale medical est `location_community_medical_01_8` ou
`_9`, en general dans un hopital ou une clinique.

1. **Monter sur la balance.** Se tenir sur la case de la balance, qui est
   praticable (verifie en jeu, 2026-09-18 : la detection ne regarde plus que
   cette case-la). Le releve doit apparaitre en haut a droite du centre de
   l'ecran, sans clic ni menu contextuel.
2. **Regarder le fleau se stabiliser.** Le fleau bascule, le curseur glisse
   jusqu'a la valeur, puis une oscillation amortie le ramene a l'horizontale.
   Comparer au rythme decrit par la maquette (montee en un peu plus de deux
   secondes).
3. **Descendre de la balance.** Le releve doit s'estomper et disparaitre
   rapidement (moins d'une demi-seconde), sans laisser de residu a l'ecran.
4. **Clic gauche sur le releve.** Bascule kg <-> lb. Remonter sur la balance
   pour verifier que la nouvelle unite est utilisee.
5. **Clic droit sur le releve.** Bascule entre le style "tete a fleau" et le
   style "panneau natif". Remonter sur la balance pour verifier le nouveau
   style.
6. **Clic ailleurs a l'ecran.** Un clic hors du rectangle du releve (par
   exemple sur le monde ou un autre element d'UI) doit se comporter
   normalement, comme si le HUD n'etait pas la.
7. **Redemarrer la partie.** L'unite et le style choisis a l'etape 4-5
   doivent avoir survecu (fichier `WeightScale_prefs.ini`).
8. **Changer la resolution.** Depuis les options, changer la resolution
   d'ecran puis remonter sur la balance : le releve doit rester positionne
   par rapport au nouveau centre de l'ecran, pas a l'ancien.
9. **Une deuxieme balance.** Trouver un deuxieme scale medical (autre
   batiment) et repeter l'etape 1 pour verifier que la detection n'est pas
   liee a un objet particulier.
10. **Lancer en Build 41.** Charger le mod sur une installation B41 et
    reprendre les etapes 1 a 3 au minimum. Si le releve ne s'affiche pas du
    tout, ou si le fleau ne tourne pas (reste a plat), c'est attendu si l'une
    des API listees "B41 UNPROVEN" dans `docs/API-COMPAT.md` manque sur ce
    build : noter laquelle semble en cause.

## Ajout 2026-09-18, clic droit

9. **Menus contextuels partout.** Hors de la balance, clic droit sur une
   porte, une fenetre, un meuble, le sol : le menu doit s'ouvrir normalement.
   Puis monter sur la balance et refaire le meme test a cote du releve. Le
   bug corrige ce jour-la tuait TOUS les menus contextuels du jeu des que le
   mod etait actif.
10. **Clic droit sur le releve.** Sur la balance, clic droit dans le releve :
    il change de style (fleau <-> panneau) et aucun menu du monde ne s'ouvre.
    Un pixel a cote du releve doit, lui, ouvrir le menu du monde.

## Ajout 2026-09-18, splitscreen et sons

11. **Deux manettes, deux balances.** Demarrer une partie splitscreen a deux
    joueurs locaux. Chaque joueur monte sur sa propre balance (deux balances
    differentes) : chacun voit son propre releve, avec son propre poids, au
    centre de SA moitie d'ecran (pas celle de l'autre joueur).
12. **Un seul joueur sur la balance.** Splitscreen actif, un seul des deux
    joueurs monte : seul son releve apparait, dans sa moitie d'ecran; rien ne
    s'affiche du cote de l'autre joueur.
13. **Deconnexion/mort en splitscreen.** Le joueur sur la balance quitte la
    partie (ou meurt) pendant que le releve est affiche : son element doit
    disparaitre, sans laisser de residu ni de zone de clic morte.
14. **Position solo inchangee.** Verifier qu'en solo (un seul joueur actif),
    le releve est exactement au meme endroit qu'avant ce changement (centre
    de l'ecran + le decalage de la maquette).
15. **Son en montant.** Monter sur la balance : un court son doit se
    declencher au moment ou le releve commence a apparaitre, une seule fois,
    depuis le joueur qui monte (pas depuis l'autre joueur en splitscreen).
16. **Son en descendant.** Descendre de la balance : un second son, plus
    court, doit se declencher au moment ou le releve commence a partir. Rester
    immobile sur la balance ne doit rejouer aucun son.
17. **Aucun zombie attire.** Avec des zombies a portee d'oreille normale
    (dehors, la nuit), monter et descendre de la balance plusieurs fois : les
    sons ne doivent attirer aucun zombie (`is3D = false`, aucun rayon dans le
    monde).

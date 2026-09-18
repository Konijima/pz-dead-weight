# Verification en jeu, HUD poids v2

Ordre suggere. Un scale medical est `location_community_medical_01_8` ou
`_9`, en general dans un hopital ou une clinique.

1. **Monter sur la balance.** S'approcher et se tenir sur la case de la
   balance (ou la case adjacente si la case de la balance n'est pas
   praticable). Le releve doit apparaitre en haut a droite du centre de
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

# Verification en jeu, HUD poids v2

Ordre suggere. Un scale medical est `location_community_medical_01_8` ou
`_9`, en general dans un hopital ou une clinique.

0. **Verifier quelle copie est testee.** Ecran de choix des mods, ouvrir la
   fiche "Dead Weight" et regarder la ligne Path : si elle pointe vers
   `~/Zomboid/Workshop/DeadWeight/...` (Source "Workshop"), c'est la copie
   STAGEE par `tools/pack-workshop.sh` qui est chargee, pas la copie du
   depot (prouve en jeu le 2026-09-18 : quand les deux portent le meme id,
   le jeu charge la copie stagee). Apres tout changement dans le depot,
   relancer `bash tools/pack-workshop.sh` avant de retester, sinon la
   preuve porte sur du contenu perime.
0bis. **Activer le bon mod.** L'id du mod a change (`WeightScale` ->
   `DeadWeight`), donc une sauvegarde qui avait l'ancien "Weight Scale"
   d'active doit avoir le nouveau "Dead Weight" active a la place: menu des
   mods, decocher "Weight Scale", cocher "Dead Weight". Les deux ne doivent
   jamais tourner ensemble (le vieux mod a base d'objet et son panneau de
   stats complet est retire).
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
   style. Sur le panneau natif, le fond sombre doit couvrir TOUT le nombre
   et l'unite (pas juste la partie gauche), en kg et en lb (corrige le
   2026-09-18, bug ou le fond ne couvrait qu'un bout du texte). Reclic droit
   pour revenir a la tete a fleau.
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

## Ajout 2026-09-18, option de menu contextuel "Step on Scale"

18. **Option en haut de la liste, avec icone.** Clic droit sur la balance
    (ou sur une case adjacente qui la contient) alors qu'on n'est pas dessus :
    "Step on Scale" (EN) / "Monter sur la balance" (FR) doit apparaitre EN
    HAUT de la liste, pas en bas, avec la petite icone dediee, pas l'icone
    generique par defaut.
19. **La marche.** Selectionner l'option : le joueur marche jusqu'a la case
    de la balance (chemin normal, pas de teleportation). A l'arrivee, le
    releve, le style et le son de montee apparaissent tout seuls, sans code
    d'affichage ajoute par l'option elle-meme.
20. **Cachee si deja dessus.** Deja sur la balance, clic droit sur la
    balance elle-meme : l'option "Step on Scale" ne doit pas apparaitre.
21. **Aucun autre menu affecte.** Refaire l'etape "Menus contextuels
    partout" (porte, fenetre, meuble, sol, un autre objet cliquable de
    n'importe quel autre mod) : aucun nouvel item ne doit apparaitre ailleurs
    que sur la balance, et l'ordre des autres options ne doit pas changer.
22. **Splitscreen.** A deux joueurs locaux, chacun clic droit sur SA
    balance : chacun ne voit l'option que pour sa propre balance, et la
    selectionner fait marcher LE BON joueur vers SA propre case, jamais
    l'autre.

## Ajout 2026-09-18, onglet Info : le poids en mots

23. **Ouvrir l'onglet Info.** Touche par defaut, ou menu du personnage :
    la ligne "Weight" ne doit plus montrer un nombre, mais un mot (par
    exemple "Emaciated", "Low Weight", "Normal", "High Weight", "Very High
    Weight" selon le poids actuel).
24. **Mot correct apres un changement de poids.** Utiliser le debug (ou
    manger/jeuner en jeu) pour faire passer le personnage d'une bande de
    poids a une autre, rouvrir l'onglet Info : le mot doit correspondre a la
    nouvelle bande, pas a l'ancienne.
25. **Fleche de tendance bien placee.** Quand le poids monte ou descend
    recemment (fleche affichee a cote du mot), la fleche ne doit jamais
    chevaucher le mot, meme pour les mots les plus longs ("Very High
    Weight").
26. **Les autres nombres intacts.** Sur le meme onglet Info, "Zombies
    Killed", "Survived For" et tout autre nombre doivent continuer a
    s'afficher normalement, y compris si leur valeur est egale au nombre de
    poids qu'on aurait vu avant ce changement.
27. **La balance montre toujours le nombre.** Monter sur une balance
    medicale : le releve du HUD doit continuer a montrer le poids exact en
    kg ou lb, inchange par ce point. Seul l'onglet Info montre desormais un
    mot.
28. **Splitscreen.** A deux joueurs locaux, chacun ouvre son propre onglet
    Info : chacun voit le mot correspondant a SON propre poids, jamais celui
    de l'autre joueur.
29. **Lancer en Build 41.** Ouvrir l'onglet Info sur une installation B41 :
    si l'ecran de personnage differe de celui du client verifie ici, le
    garde-fou doit laisser l'affichage vanilla intact (le nombre reste
    visible) plutot que de planter; noter ce qui a ete observe.

## Ajout 2026-09-18, faire face a la colonne en montant sur la balance

Confirme en jeu, 2026-09-18 : le personnage se tenait sur la balance dos a
la colonne quand il faisait face a `Facing` lui-meme. Le sens correct est
donc l'OPPOSE de `Facing` (N<->S, E<->W), corrige dans `Detect.facingFor`
par une table explicite; ceci corrige et remplace la deduction precedente
("MEME direction que Facing"), qui est maintenant fausse. A verifier :
confirme pour une seule des deux balances placees; l'autre orientation
reste a verifier en jeu.

30. **Marcher dessus et s'arreter, par chaque cote.** Approcher une balance
    par le nord, s'arreter dessus : le personnage doit tourner une seule
    fois pour faire face a la colonne (le cote avec la tete de mesure), pas
    seulement au hasard. Refaire par le sud, l'est et l'ouest (autant de
    balances differentes que la carte en offre) : le personnage tourne
    toujours vers la colonne de CETTE balance, pas vers un point fixe.
31. **Traverser sans s'arreter.** Marcher A TRAVERS la case de la balance
    sans s'y arreter (juste de passage) : le personnage ne doit jamais etre
    tourne de force pendant la traversee.
32. **Se retourner ensuite reste libre.** Une fois arrete sur la balance et
    tourne vers la colonne, tourner volontairement dans une autre direction
    (ou marcher, ou viser) : le mod ne doit jamais reforcer la tete vers la
    colonne tant qu'on reste sur la meme case sans la quitter puis y
    revenir.
33. **Reste desarme apres avoir quitte.** Quitter la case puis y remonter :
    le personnage doit de nouveau tourner une fois vers la colonne (la
    tourne se re-arme uniquement en quittant puis en revenant).
34. **Action du menu contextuel.** Clic droit sur une balance de loin,
    "Step on Scale" : le personnage marche jusqu'a la case, s'arrete, puis
    tourne vers la colonne, sans mouvement de tete parasite pendant la
    marche.
35. **Marche annulee.** Declencher "Step on Scale" puis annuler la marche
    (bouger la souris/cliquer ailleurs, ou tout ce qui interrompt
    ISWalkToTimedAction) avant d'arriver : le personnage ne doit jamais
    tourner vers la balance qu'il n'a pas atteinte.
36. **Vise ou autre action en cours.** Arriver sur la balance en train de
    viser une arme (si possible en jeu) : la tourne ne doit pas se produire
    pendant que le personnage vise; elle peut suivre une fois qu'il arrete.
37. **Splitscreen.** A deux joueurs locaux, chacun monte sur SA propre
    balance en meme temps : chacun tourne vers SA colonne, jamais influence
    par l'autre joueur ni par l'orientation de l'autre balance.
38. **Le HUD est inchange.** Sur chaque cas ci-dessus, le releve du HUD doit
    toujours apparaitre a l'instant ou le joueur monte, exactement comme
    avant cet ajout.

## Ajout 2026-09-18, toutes les langues

39. **Une langue latine, ex. l'allemand.** Options > Langue > Deutsch,
    relancer. Clic droit sur la balance : le libelle doit s'afficher sans
    caractere casse ("Auf die Waage steigen", accents/trema corrects).
    Monter sur la balance et ouvrir l'onglet Info : le mot "Normal" doit
    s'afficher normalement.
40. **Une langue cyrillique, ex. le russe.** Options > Langue > Russian,
    relancer. Meme verification : le libelle du menu contextuel et le mot
    de l'onglet Info doivent s'afficher en cyrillique lisible, sans carres
    ni points d'interrogation (signe d'un mauvais jeu de caracteres).
41. **Une langue asiatique, ex. le coreen ou le japonais.** Options >
    Langue > Korean (ou Japanese), relancer. Meme verification : les
    ideogrammes/hangeul doivent s'afficher lisibles, pas en carres vides.
42. **Note pour cette machine :** aucune installation B41 disponible ici;
    les etapes 39-41 ne couvrent que B42. Si une install B41 devient
    disponible, refaire ces trois etapes dessus et noter tout caractere
    casse par langue (verifierait alors la table de `LANG_CHARSET` dans
    `tools/gen-translate.py`, marquee UNPROVEN pour B41 dans
    `docs/API-COMPAT.md`).

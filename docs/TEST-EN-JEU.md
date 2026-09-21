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
    exemple "Emaciated", "Underweight", "Normal", "Overweight", "Obese"
    selon le poids actuel). Le mot ne doit JAMAIS etre une cle brute du
    genre "IGUI_..." (bug du 2026-09-18 : "Normal" s'affichait comme
    "IGUI_WeightScale_Normal" quand la traduction n'atterrissait pas dans le
    bon fichier).
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

## Ajout 2026-09-20, la balance lit tout le monde, le docteur regarde

Avant de tester : reconstruire la copie Workshop (`tools/pack-workshop.sh`)
ou la retirer (`--clean`), le jeu prefere la copie Workshop a la copie de dev.

43. **Un seul joueur, inchange.** Monter sur la balance seul : releve a
    l'instant, son "on" une seule fois, poids identique a l'ancien
    comportement. Descendre : animation de sortie, son "off" une seule fois.
44. **Un animal sur la balance.** Placer un animal (debug/spawn) sur la case :
    le releve s'affiche avec le poids de l'animal (pas celui d'un humain),
    sans son si le joueur n'est pas sur la case. Un petit animal (poule, lapin)
    doit afficher son vrai poids meme sous 35 kg, poutre au bas de l'echelle.
45. **Un zombie sur la balance.** Poser un zombie immobile sur la case : le
    releve affiche un poids plausible (environ 60 a 90 kg), le meme tant que
    ce zombie reste. Un autre zombie donne en general un autre poids.
46. **Le docteur regarde.** Se tenir a 1 ou 2 cases de la balance (distance de lecture par defaut : 2), dans la meme
    piece, un patient (autre joueur, animal ou zombie) sur la balance : le
    releve du patient s'affiche, sans aucun son. A 2 cases, ou de l'autre
    cote d'une porte dans une autre piece : rien ne s'affiche.
47. **Deux occupants.** Un deuxieme occupant monte sur la balance : la
    poutre glisse vers le nouveau total, sans rejouer l'animation d'entree,
    et sans son. A deux (ou trois) le total n'est pas plafonne : la poutre
    reste au maximum de l'echelle mais le chiffre affiche la vraie somme
    (par exemple 152.4 kg). Quand il descend, le releve revient
    au total restant.
48. **Zombie qui traverse.** Un zombie qui ne fait que traverser la case
    (une fraction de seconde) ne doit pas faire clignoter ni sauter le
    releve.
49. **Sons : vide <-> occupee.** Le son "on" joue chez tout joueur qui voit le
    releve quand la balance passe de vide a occupee (lui-meme qui monte, un
    autre joueur, ou un simple objet pose), a condition qu'il ait vu la
    balance vide avant (s'approcher d'une balance deja occupee est silencieux).
    Aucun son quand un deuxieme occupant arrive ou repart. Le son "off" joue
    chez tout joueur qui voit le releve quand la balance redevient vide. En
    multijoueur, chaque client joue son propre son : rien n'est diffuse.
50. **S'eloigner.** Le docteur qui s'eloigne a plus de 2 cases : le releve
    part tout de suite (animation de sortie, pas de son). Verifier qu'un clic
    droit dans le monde marche partout apres (l'element ne doit plus etre
    enregistre).
51. **Splitscreen.** Joueur 1 sur la balance, joueur 2 a 1 case : les deux
    voient le meme releve dans leur propre moitie d'ecran, seul le joueur 1
    entend le son.
52. **Multijoueur (deux clients).** Le patient monte sur la balance, le
    docteur a 1 case lit un poids. Un meme zombie doit donner le meme poids
    sur les deux clients.
52b. **Multijoueur, poids porte.** Option `WeighCarried` activee, deux
    clients : le patient (sac charge) monte sur la balance, le docteur a
    1 case doit lire le meme total que le patient, a 3 secondes pres.
    Le patient ajoute ou lache un objet : le total des deux clients suit.
    Option desactivee : les deux lisent le poids du corps seul.
52c. **Distance de lecture.** Options de partie, page DeadWeight, "Distance de
    lecture" (0 a 5, defaut 2, quitter et recharger la partie si l'editeur de
    debug ne l'applique pas). A 2 : le docteur lit a 2 cases, pas a 3. A 0 :
    seul celui qui est sur la balance la lit. A 4 : lecture a 4 cases.
52d. **Balance ramassee puis reposee.** Le docteur reste immobile a portee, un
    autre joueur ramasse la balance : le releve part. Il la repose au meme
    endroit ou a un autre a portee : le docteur relit sans bouger (compter
    jusqu'a 1 seconde).
52e. **Deux balances cote a cote.** Poser deux balances adjacentes. Marcher
    directement de l'une sur l'autre : le personnage se tourne vers la colonne
    de la seconde, une seule fois. Un docteur entre les deux (ou a portee des
    deux) lit la plus proche qui a quelque chose a peser : patient sur la
    balance lointaine seulement, il lit celui-la ; les deux occupees, il lit
    la plus proche ; le patient de la plus proche part, il bascule sur
    l'autre. Ramasser la balance lue : il bascule sur l'autre, et revient sur
    la premiere une fois reposee.
52f. **Mur entre le docteur et la balance.** Le docteur immobile a portee lit la
    balance. Construire un mur (ou fermer une porte) entre eux : le releve
    part en moins d'une seconde. Retirer le mur / rouvrir la porte : il
    revient sans bouger. Une fenetre ou une porte ouverte ne cache pas la
    balance. Sur la balance elle-meme, toujours lisible.
53. **Balance ramassee.** Ramasser/deplacer la balance pendant qu'un patient
    est dessus et que le docteur regarde : le releve doit partir, pas rester
    fige.

## Ajout 2026-09-20, option bac a sable "Weigh what you carry"

Option `DeadWeight.WeighCarried` (page "Dead Weight" des options de bac a
sable, desactivee par defaut) : elle ne concerne QUE ce que porte chaque
joueur. Les objets poses sur la plaque comptent et sont releves sur la
plaque dans tous les cas, option activee ou non. A tester en solo d'abord : en multijoueur le
sac des AUTRES joueurs n'est pas releve (relais a venir), seul leur corps.

54. **Option desactivee (defaut).** Monter sur la balance avec un sac
    charge : le releve est exactement celui d'avant (poids du corps seul,
    identique a l'onglet Info en mots). Poser un objet sur la plaque : le
    releve augmente quand meme de son poids (le sol compte toujours).
55. **Option activee, on porte quelque chose.** Activer l'option dans les
    options de bac a sable (nouvelle partie, ou options de la partie en
    cours en debug). Monter sur la balance : le releve = corps + tout ce
    qu'on porte (vetements portes et contenu du sac inclus a 100 %).
    Deposer un objet lourd dans le sac ou le retirer : le releve suit apres
    le meme delai que pour un autre occupant.
56. **Vider le sac au sol.** Debout sur la balance, jeter le contenu du
    sac sur la case : le total ne change pas (l'objet compte maintenant par
    le sol de la case). Le pousser sur une case voisine : le releve baisse.
57. **Objet au sol sur la case.** Poser un objet (un sac charge par exemple)
    sur la case de la balance, en restant dessus : le releve augmente du
    poids de l'objet, contenu du sac compris, une seule fois.
58. **Objet sur la case voisine.** Poser le meme objet sur une case a cote de
    la balance : le releve ne change pas.
58b. **Objet sur la case mais a cote de la plaque.** Poser un objet sur la
    case de la balance, mais visiblement a cote de la plaque (pres d'un coin
    de la case, comme un bidon d'eau pose sur le bord) : il ne compte pas.
    Le poser sur la plaque, au milieu de la case : il compte. Si la zone
    parait trop petite ou trop grande, ajuster `Occupants.plateHalf`.
59. **Objet seul, personne dessus.** Un objet sur la balance sans personne
    dessus : se placer a une case (meme piece) fait apparaitre le releve avec
    le poids de l'objet, comme si quelqu'un y etait, sans son (on arrive apres coup). Poser un
    objet pendant qu'on regarde la balance vide joue le son "on", le reprendre
    joue le son "off". Le
    reprendre ou s'eloigner de plus d'une case : le releve disparait.
60. **Zombie ou animal.** Avec l'option activee, un zombie ou un animal sur la
    balance ne compte que son poids de corps (les objets au sol de la case
    comptent toujours une fois).
61. **Retour a l'option desactivee.** Redesactiver l'option : ce que le
    joueur porte ne compte plus (les objets au sol restent comptes), sans
    redemarrer.
62. **Zone de la plaque, personnage.** Option "Peser toute la case"
    desactivee (defaut). Se tenir dans un coin de la case de la
    balance, a cote de la plaque : pas de releve, pas de son. Marcher jusqu'au
    milieu de la case (la plaque n'est pas au meme endroit selon l'orientation
    de la balance, verifier les deux), sur la plaque : le releve apparait avec
    le son. Ressortir
    de la plaque en restant dans la case : le releve se ferme avec le son de
    sortie. Un zombie ou un animal dans un coin de la case n'est pas pese.
63. **Objet pose sur la plaque.** Avec "Peser ce que l'on porte" activee,
    poser un petit objet sur la plaque : il apparait pose dessus, pas cache
    dessous. Si la hauteur parait fausse, ajuster `Occupants.plateTop`.
64. **Toute la case.** Activer "Peser toute la case" (puis quitter et recharger la partie : l'editeur de debug ne
    rafraichit pas SandboxVars en direct) : se tenir dans un coin de la case
    ou y poser un objet compte comme avant, toute la case pese, et rien n'est
    souleve.
65. **Poser un animal sur la balance (B42).** Prendre un petit animal dans les
    mains (poule, lapin). Clic droit sur la balance : "Poser l'animal sur la
    balance" est en haut du menu. Le choisir : le personnage marche jusqu'a une
    case voisine (pas sur la balance), se tourne vers la balance, pose l'animal, qui apparait sur la plaque
    avec son cri de depose, et le releve affiche son poids d'animal seul (pas
    le sien). Debout sur la balance avec l'animal dans les mains : l'option
    reste, et fait sortir le personnage de la balance avant de poser. Sans
    animal en main : l'option n'apparait pas. L'animal reste immobile sur la plaque
    environ 3,5 secondes (`Menu.holdMs`), puis repart et le releve se ferme.
    Si l'animal s'echappe quand meme : lire console.txt, lignes
    `[DeadWeight] animal held at ...` puis `animal released, put back N times`
    (N > 0 : il a essaye de partir et a ete remis en place). En multijoueur : l'autre joueur voit-il l'animal
    apparaitre ? (non prouve, voir docs/API-COMPAT.md).

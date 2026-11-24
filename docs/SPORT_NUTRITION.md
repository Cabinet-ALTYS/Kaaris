# KAARIS — Entraînement, nutrition et suivi des habitudes

Recherche mise à jour le 23 novembre 2026. Périmètre de la bêta iOS pour adultes. Les modèles ci-dessous servent à programmer des séances et à rédiger les fiches du coach. Le [catalogue iOS](../ios/Kaaris/Knowledge/kaaris-knowledge.json) réunit 18 fiches dans les catégories Musculation, Macronutriments, Micronutriments, Récupération et Objectifs.

## 1. Repères scientifiques

| Sujet | Résultat et limites | Application dans KAARIS |
| --- | --- | --- |
| Activité physique et santé | Pour les adultes de 18 à 64 ans, l’OMS préconise 150 à 300 minutes d’activité aérobie modérée par semaine, ou 75 à 150 minutes d’intensité soutenue, ou une combinaison équivalente. Le renforcement couvre les principaux groupes musculaires au moins deux jours par semaine. | Afficher des repères hebdomadaires et laisser commencer en dessous. Proposer aussi marche, vélo ou autres activités choisies. [OMS, recommandations d’activité physique](https://www.who.int/europe/news-room/fact-sheets/item/physical-activity) |
| Force | La synthèse ACSM 2026 inclut 137 revues et plus de 30 000 participants. Des charges d’environ 80 % du maximum sur une répétition et 2 à 3 séries par exercice peuvent favoriser les gains de force chez l’adulte sain. | Commencer par des charges contrôlables. Proposer le travail lourd aux pratiquants adaptés, sans test maximal imposé. Matériel, bandes et poids du corps font partie du catalogue. [ACSM, synthèse 2026](https://pubmed.ncbi.nlm.nih.gov/41843416/) |
| Prise de muscle | L’ACSM identifie un bénéfice associé à un volume de l’ordre de 10 séries hebdomadaires par groupe musculaire. Le volume adapté varie selon l’expérience et la récupération. L’échec musculaire n’apporte pas d’avantage constant à l’adulte sain moyen. | Construire le volume progressivement. En début de programme, la technique et la présence passent avant un objectif chiffré de séries. [ACSM, repères pratiques 2026](https://acsm.org/resistance-training-guidelines-update-2026/) |
| Répartition des séances | Une méta-analyse de 14 études et 392 participants ne relève pas de différence significative de force ou de croissance musculaire entre séances corps entier et séances par groupes quand le volume est équivalent. | Choisir la répartition selon les créneaux, le matériel et les préférences. Augmenter la fréquence peut raccourcir chaque séance à volume comparable. [Ramos-Campo et al., 2024](https://pubmed.ncbi.nlm.nih.gov/38595233/) |
| Protéines | L’Anses fixe une référence générale de 0,83 g/kg/j chez l’adulte sain. Dans une méta-analyse de 49 études de renforcement, le gain moyen supplémentaire de masse maigre plafonnait autour de 1,62 g/kg/j de protéines totales. Cette estimation reste incertaine à l’échelle individuelle. | Présenter les deux contextes. Auprès d’un adulte sain faisant de la musculation, afficher environ 1,6 g/kg/j comme repère informatif facultatif, avec des exemples alimentaires. [Anses, apports recommandés](https://www.anses.fr/fr/article/proteines-role-sources-et-apports-recommandes), [Morton et al., 2018](https://pubmed.ncbi.nlm.nih.gov/28698222/) |
| Apports et prise de muscle | Dans un essai de huit semaines avec 21 pratiquants randomisés et 17 ayant terminé, un gain de poids plus rapide a principalement été associé à davantage de graisse. La petite taille de l’essai limite sa généralisation. Une méta-analyse indique qu’un déficit énergétique prolongé freine les gains de masse maigre sous renforcement. | Prioriser régularité, progression et apports suffisants. Éviter de prescrire automatiquement un surplus ou d’en promettre les effets. [Helms et al., 2023](https://pubmed.ncbi.nlm.nih.gov/37914977/), [Murphy et Koehler, 2022](https://pubmed.ncbi.nlm.nih.gov/34623696/) |
| Perte de poids | Un déficit énergétique soutenu intervient dans la perte de poids. Le NICE recommande une démarche flexible, équilibrée et accompagnée, et réserve les régimes très restrictifs à des parcours spécialisés. Chez des adultes en surpoids ou avec une obésité, ajouter le renforcement à une intervention alimentaire aide à préserver la masse maigre et à réduire la masse grasse, avec une différence de poids moyen faible et incertaine. | Expliquer le principe. Proposer des gestes tenables, maintenir un renforcement adapté et rendre le suivi du poids facultatif. [NICE, activité physique et alimentation](https://www.nice.org.uk/guidance/ng246/chapter/Physical-activity-and-diet), [Binmahfoz et al., 2025](https://doi.org/10.1136/bmjsem-2024-002363), [HAS, parcours de soins](https://has-sante.fr/jcms/p_3408871/fr/guide-du-parcours-de-soins-surpoids-et-obesite-de-l-adulte) |
| Planification | Une méta-analyse de 35 essais, 5 439 participants, trouve un effet moyen modeste sur l’activité (SMD 0,35, IC à 95 % 0,25 à 0,44). Les résultats sont hétérogènes et le sous-groupe avec mesures objectives est peu concluant. | Prévoir un créneau concret et une solution de repli. Mesurer les séances réellement confirmées. [Peng et al., 2022](https://pmc.ncbi.nlm.nih.gov/articles/PMC9223740/) |
| Relances | Dans l’essai HeartSteps, des suggestions contextuelles de marche ont produit un effet à court terme qui s’est atténué. L’efficacité d’un ton insultant pour les séances de sport reste inconnue. La stigmatisation liée au poids est souvent associée à une moindre activité, selon des études surtout observationnelles. | Mesurer ensemble la confirmation des séances, les reports et les mises en sourdine. Réserver les phrases piquantes consenties aux engagements de planning. [Klasnja et al., 2019](https://doi.org/10.1093/abm/kay067), [Pearl et al., 2021](https://pubmed.ncbi.nlm.nih.gov/34747131/) |

## 2. Modèles de semaines de 2 à 6 séances

Le plan prend en compte la fréquence souhaitée, le niveau déclaré, la durée disponible, les équipements, les mouvements à adapter et les créneaux libres. Les modèles donnent un point de départ. Les jours se déplacent en conservant des intervalles de récupération adaptés. Les volumes et durées proposés sont des réglages de la bêta.

| Séances | Reprise ou début | Régulier | Distribution sur sept jours pour un pratiquant régulier |
| --- | --- | --- | --- |
| 2 | 2 corps entier, 25 à 40 min | 2 corps entier, 40 à 55 min | A · repos · repos · B · repos · repos · repos |
| 3 | 2 corps entier et 1 séance facile, puis 3 corps entier si la récupération est bonne | 3 corps entier, variantes A et B en alternance | A · repos · B · repos · A · repos · repos. Inverser A et B la semaine suivante. |
| 4 | 2 corps entier, 2 séances faciles (marche, cardio modéré, mobilité) | Haut du corps et bas du corps, deux de chaque | Haut A · bas A · repos · haut B · bas B · repos · repos |
| 5 | 2 corps entier et 3 séances faciles. Passer à 3 corps entier si le suivi le justifie. | 4 séances haut et bas, 1 séance facile | Haut A · bas A · repos · haut B · bas B · facile · repos |
| 6 | 2 à 3 corps entier et 3 à 4 activités faciles réparties. Un jour libre. | Par défaut, 4 séances haut et bas, 2 séances faciles. L’option avancée utilise deux cycles poussée, tirage, jambes, avec charges et volumes répartis sur les six jours. | Haut A · bas A · facile · haut B · bas B · facile · repos |

Une séance facile est une activité de 15 à 35 min, choisie pour rester confortable, avec un effort permettant de parler en phrases. Une préférence de 5 ou 6 séances déclenche une proposition de répartition, sans multiplier la charge hebdomadaire par rapport au niveau actuel. En cas d’agenda trop serré, afficher les créneaux réellement disponibles et laisser l’utilisateur valider un ajustement.

### Cycle de progression à proposer

| Quand | Ce que la personne voit | Ce que le plan change |
| --- | --- | --- |
| Semaines 1 et 2 | Choisir une variante et une charge légère. Finir les séries avec l’impression de pouvoir encore faire deux ou trois répétitions propres. | Maintenir peu de séries, le même exercice et des créneaux récupérables. Pour une personne en reprise qui veut 5 ou 6 séances, composer avec deux ou trois renforcements et des séances faciles. |
| Semaines 3 et 4 | Refaire les mouvements et noter charge, répétitions et effort. Un effort très difficile ou une technique qui se dégrade invite à alléger. | Augmenter d’abord les répétitions dans la fourchette. Proposer le plus petit palier de charge après deux expositions maîtrisées. La personne le valide. |
| Bilan | Comparer les séances prévues, terminées et déplacées. Examiner la récupération et la régularité. | Reprendre un créneau réaliste si des séances glissent. Ajuster une variable de difficulté à la fois. Un volume hebdomadaire plus haut se répartit sur les jours disponibles et se construit progressivement. |

Les durées, seuils et phases du tableau sont des choix de produit. Le réglage de l’effort peut rester simple (« il me restait plusieurs répétitions », « encore une ou deux », « aucune »). Une méta-régression exploratoire sur les répétitions en réserve associe une plus grande proximité de l’échec à davantage d’hypertrophie, avec une distance optimale incertaine et des mesures souvent estimées. La force progresse sur une plage d’effort plus large. Une autre méta-régression trouve des rendements décroissants quand le volume augmente et un effet plus incertain de la fréquence sur l’hypertrophie. [Robinson et al., 2024](https://doi.org/10.1007/s40279-024-02069-2), [Pelland et al., 2025](https://pubmed.ncbi.nlm.nih.gov/41343037/), [ACSM, synthèse 2026](https://pubmed.ncbi.nlm.nih.gov/41843416/).

### Exemples d’exercices pour deux séances corps entier

| Mouvement | Séance A | Séance B | Substitution simple |
| --- | --- | --- | --- |
| Travail des jambes | Squat à la coupe | Fente assistée | Presse ou assis-debout sur chaise |
| Hanches | Soulevé de terre roumain aux haltères | Pont fessier | Tirage câble entre les jambes ou pont au sol |
| Poussée | Développé haltères | Pompes inclinées | Développé guidé ou pompes au mur |
| Tirage | Rowing avec appui | Tirage vertical | Élastique fixé sur un point stable |
| Tronc | Gainage latéral court | Insecte mort | Marche avec charge légère, selon le matériel |

Ajouter un échauffement général bref et une série facile par mouvement nouveau. Pour une reprise, démarrer à 1 ou 2 séries de 8 à 12 répétitions sur les mouvements dynamiques, en gardant environ 2 à 3 répétitions possibles en réserve lorsque l’effort peut être évalué. Pour le gainage, utiliser une tenue courte et arrêter dès que la position n’est plus stable. Proposer un temps de repos modulable, par exemple 90 à 180 secondes sur les mouvements principaux. La séance enregistre séries, répétitions et charge réelle. La vidéo de démonstration et la variante doivent rester accessibles pendant l’effort.

### Progression à implémenter

1. Conserver la charge et ajouter des répétitions dans la fourchette prévue tant que le mouvement reste stable et bien toléré.
2. Si toutes les séries atteignent le haut de la fourchette sur deux séances comparables avec une marge d’effort suffisante, proposer le plus petit incrément de charge disponible ou une variante légèrement plus difficile. Revenir ensuite au bas de la fourchette.
3. Si la technique se dégrade ou la récupération est insuffisante, conserver l’effort, retirer une série, réduire la charge ou choisir la variante facile selon le retour de l’utilisateur. Une douleur nouvelle ou inhabituelle déclenche l’arrêt du mouvement et une vérification de la situation.
4. Reprogrammer une séance manquée sur un créneau compatible. Garder un créneau de récupération et préserver l’ordre des séances si l’utilisateur le souhaite.
5. Après une interruption prolongée, proposer une semaine de reprise plus légère. Mettre à jour la fréquence ou l’objectif uniquement après validation.

Sur la fiche, montrer l’objectif prioritaire, le matériel, le temps prévu, les exercices, les alternatives, l’effort et la progression proposée. Le calendrier stocke la séance, le fuseau et le statut. Les actions **J’y suis**, **Terminée**, **Reporter** et **Passer** enregistrent des décisions distinctes. Une séance sans réponse reste **À confirmer**.

## 3. Fiches nutrition à afficher dans l’application

### Une base pour tous les objectifs

**Message.** Compose tes repas avec les aliments que tu peux garder dans ta routine. Pense aux fruits et légumes, légumes secs, céréales complètes et sources de protéines que tu apprécies. Garde de l’eau à portée pendant tes séances.

**Action.** Choisis un changement cette semaine, par exemple ajouter un fruit au petit déjeuner, mettre des lentilles au repas ou prévoir de l’eau avant de partir à la salle.

**En savoir plus.** L’OMS recommande aux adultes au moins 400 g de fruits et légumes et 25 g de fibres alimentaires naturellement présentes dans les aliments par jour. Ces repères peuvent être présentés sans obligation de pesée. [OMS, alimentation saine 2026](https://www.who.int/news-room/fact-sheets/detail/healthy-diet), [Santé publique France, recommandations adultes](https://www.mangerbouger.fr/manger-mieux/a-tout-age-et-a-chaque-etape-de-la-vie/les-recommandations-alimentaires-pour-les-adultes).

### Prendre du muscle

**Message.** Planifie des repas réguliers avec une source de protéines. Les œufs, poissons, laitages, produits à base de soja ou légumes secs peuvent entrer dans ta routine. Observe aussi tes répétitions, tes charges et ta récupération.

**Action.** Choisis deux repas faciles à refaire les jours d’entraînement. Tu peux préparer du yaourt nature avec des flocons d’avoine et un fruit, du riz aux légumes avec du tofu ou des œufs avec du pain complet et des légumes. Ajuste les quantités à ta faim et à ton activité.

**En savoir plus.** Chez les adultes sains en musculation, environ 1,6 g de protéines totales par kilogramme de poids et par jour est un repère issu d’une moyenne de recherche. Les repas habituels peuvent y contribuer et le supplément reste optionnel. En cas de maladie rénale ou d’indication médicale alimentaire, suivre le repère donné par le professionnel qui accompagne l’utilisateur. [Anses, protéines](https://www.anses.fr/fr/article/proteines-role-sources-et-apports-recommandes), [Morton et al.](https://pubmed.ncbi.nlm.nih.gov/28698222/).

### Perdre du poids si c’est l’objectif choisi

**Message.** Garde les séances de renforcement prévues et choisis une habitude alimentaire que tu peux tenir. Au fil des semaines, regarde aussi ton énergie, tes progrès à l’entraînement et la régularité de tes repas.

**Action.** Choisis une action telle que prévoir un repas les jours chargés, ajouter des légumes là où tu en manges peu ou remplacer une boisson sucrée que tu bois souvent par de l’eau. Vérifie après une semaine si l’action colle à ton quotidien.

**En savoir plus.** Une perte de poids durable implique que les apports énergétiques restent en moyenne en dessous des dépenses, avec des besoins et des rythmes qui varient d’une personne à l’autre. La bêta propose des habitudes alimentaires et des repères, avec un objectif de poids purement facultatif. [NICE, recommandations alimentaires](https://www.nice.org.uk/guidance/ng246/chapter/Physical-activity-and-diet), [HAS, accompagnement de l’adulte](https://has-sante.fr/jcms/p_3408871/fr/guide-du-parcours-de-soins-surpoids-et-obesite-de-l-adulte).

### Habitudes facultatives

- **Écran.** Demander une estimation ou lire les données autorisées et indiquer l’origine de la valeur. Proposer des pauses actives ou un objectif choisi. Le temps d’écran et le temps assis sont deux mesures distinctes. L’OMS recommande de limiter la sédentarité sans fixer de seuil universel pour les adultes. [OMS, sédentarité](https://doi.org/10.1136/bjsports-2020-102955).
- **Alcool.** Si l’utilisateur le souhaite, consigner une estimation par verre standard et présenter les repères français de moindre risque, jusqu’à 10 verres par semaine, jusqu’à 2 par jour et des jours sans alcool. Une suspicion de dépendance appelle une orientation adaptée, car arrêter brutalement peut être dangereux. [Santé publique France, alcool](https://www.santepubliquefrance.fr/alcool/comment-reduire-les-risques-de-la-consommation-dalcool), [NHS, dépendance à l’alcool](https://www.nhs.uk/conditions/alcohol-use-disorder/).
- **Tabac ou vape.** Permettre à l’utilisateur de définir son objectif et d’accéder à des ressources d’accompagnement. Traiter les difficultés de sevrage avec un ton neutre. [OMS, aide à l’arrêt du tabac](https://www.who.int/publications/i/item/9789240096431).

### Manger autour d’une séance

**Avant.** Prévois de l’eau et un repas ou une collation que tu digères bien selon l’heure et ta faim. Exemples simples pour une journée chargée. Un fruit et un laitage ou une alternative au soja. Du pain et des œufs. Un repas habituel avec légumes, féculent et source de protéines.

**Pendant.** Sur une séance habituelle de renforcement, garde de l’eau disponible. Adapte la quantité et les pauses à la chaleur, à la durée, à l’effort et à la soif. Les besoins lors d’efforts longs ou intenses demandent une approche spécifique.

**Après.** Reprends tes repas habituels et mets-y une source de protéines. Un adulte actif peut privilégier les quantités et la qualité des apports sur la journée. Les protocoles de récupération rapide concernent surtout des entraînements rapprochés ou prolongés. [Thomas, Erdman et Burke, position commune de nutrition sportive](https://pubmed.ncbi.nlm.nih.gov/26920240/), [Morton et al., protéines et renforcement](https://pubmed.ncbi.nlm.nih.gov/28698222/).

Dans l’app, proposer une seule action nutritionnelle à choisir par semaine, par exemple préparer deux repas faciles, prévoir une gourde ou ajouter une source de protéines à un repas régulier. Le bilan peut demander « Ça tient dans ta semaine ? ». L’utilisateur peut ignorer les cartes nutrition et garder le programme sportif.

### Glucides, lipides et fibres

| Nutriment | Repère applicable | Action simple |
| --- | --- | --- |
| Glucides | Ils apportent de l’énergie à l’effort. L’OMS recommande de privilégier céréales complètes, légumes, fruits et légumineuses. Les stratégies quantifiées de récupération en glucides concernent notamment l’effort prolongé et les entraînements rapprochés. [OMS, glucides 2023](https://www.who.int/publications/i/item/9789240073593), [Thomas, Erdman et Burke, 2016](https://pubmed.ncbi.nlm.nih.gov/26920240/) | Ajouter une portion de féculents que tu digères bien au repas qui suit une séance. |
| Lipides | Prévoir des sources de graisses insaturées. Les huiles de colza, d’olive et de noix, les fruits à coque et les poissons s’intègrent à cette démarche. [OMS, alimentation saine 2026](https://www.who.int/news-room/fact-sheets/detail/healthy-diet), [Santé publique France, recommandations adultes](https://www.mangerbouger.fr/manger-mieux/a-tout-age-et-a-chaque-etape-de-la-vie/les-recommandations-alimentaires-pour-les-adultes) | Ajouter une vinaigrette à l’huile de colza ou d’olive à un repas habituel. |
| Fibres | L’OMS conseille au moins 25 g/j de fibres présentes naturellement et 400 g/j de fruits et légumes chez l’adulte. Augmenter progressivement si les apports sont faibles et boire régulièrement. [OMS, glucides et fibres 2023](https://www.who.int/publications/i/item/9789240073593), [NIDDK, fibres et eau](https://www.niddk.nih.gov/health-information/digestive-diseases/constipation/eating-diet-nutrition) | Ajouter un fruit entier ou une portion de légumes secs à un repas habituel. |

### Micronutriments

Les chiffres sont des références populationnelles pour adultes en bonne santé. L’Anses distingue la référence nutritionnelle pour une population et l’apport satisfaisant estimé lorsque les données disponibles demandent une autre méthode. Les conseils personnalisés dépendent notamment de l’âge, de l’alimentation, de l’état de santé et des traitements. Les fiches expliquent les options alimentaires sans calculer de supplément ni chercher une carence.

| Nutriment | Repère Anses pour l’adulte | Sources et point de vigilance |
| --- | --- | --- |
| Fer | Référence de 11 mg/j chez l’homme adulte, la femme ménopausée et la femme adulte aux pertes menstruelles faibles à modérées. Référence de 16 mg/j en cas de pertes élevées. | Viandes, poissons, légumes secs, céréales et noix. La vitamine C peut favoriser l’absorption du fer non héminique. Un symptôme persistant appelle un avis professionnel. [Anses, fer](https://www.anses.fr/fr/article/references-nutritionnelles-vitamines-mineraux), [NIH ODS, fer](https://ods.od.nih.gov/factsheets/iron-HealthProfessional/) |
| Calcium | Référence de 1 000 mg/j de 18 à 24 ans, puis 950 mg/j à partir de 25 ans. | Laitages, certains légumes verts, légumes secs, eaux calciques ou produits enrichis. Comparer le calcium déclaré sur les boissons végétales. [Anses, calcium](https://www.anses.fr/fr/article/references-nutritionnelles-vitamines-mineraux), [Anses, repères végétariens 2025](https://www.anses.fr/fr/actualite/regimes-vegetariens-effets-sante-reperes-alimentaires) |
| Vitamine D | Apport alimentaire satisfaisant de 15 µg/j. | Poissons gras et jaunes d’œufs. La synthèse cutanée varie notamment avec la saison et la latitude. Renvoyer vers un professionnel pour une évaluation et une éventuelle supplémentation. [Anses, vitamine D](https://www.anses.fr/fr/article/references-nutritionnelles-vitamines-mineraux) |
| Vitamine B12 | Apport satisfaisant de 4 µg/j. | Poissons, viandes, œufs, laitages et aliments enrichis. Une alimentation entièrement végétalienne demande de planifier une source fiable avec un professionnel. [Anses, vitamine B12](https://www.anses.fr/fr/article/references-nutritionnelles-vitamines-mineraux), [Anses, repères végétariens 2025](https://www.anses.fr/fr/actualite/regimes-vegetariens-effets-sante-reperes-alimentaires) |
| Iode | Apport satisfaisant de 150 µg/j. | Produits de la mer, œufs, certains laitages et sel iodé employé avec modération. Les teneurs des algues varient fortement. Les troubles thyroïdiens appellent un avis avant une consommation régulière. [Anses, iode](https://www.anses.fr/fr/article/references-nutritionnelles-vitamines-mineraux), [Anses, algues et risque d’excès d’iode](https://www.anses.fr/fr/system/files?file=NUT2017SA0086.pdf) |

### Hydratation et récupération

- **Eau.** L’EFSA retient environ 2 L/j pour les femmes adultes et 2,5 L/j pour les hommes adultes en conditions tempérées et d’activité modérée, aliments et boissons compris. En séance, rendre l’eau accessible et tenir compte de l’effort, de la chaleur et des pauses. Éviter de convertir la valeur totale en bouteilles à boire. [EFSA, références d’apport en eau 2010](https://efsa.onlinelibrary.wiley.com/doi/10.2903/j.efsa.2010.1459), [ACSM, hydratation et électrolytes](https://acsm.org/9-facts-about-hydration-electrolytes/).
- **Sommeil.** Le consensus AASM et SRS recommande au moins 7 h régulières par nuit chez l’adulte de 18 à 60 ans. Proposer dans l’app une heure de lever relativement régulière, du temps pour dormir et une séance plus facile quand une mauvaise nuit perturbe le mouvement. [Watson et al., consensus AASM et SRS 2015](https://pubmed.ncbi.nlm.nih.gov/26039963/).
- **Charge d’entraînement.** Le coach peut proposer d’enlever une série, baisser la charge, faire une activité facile ou déplacer la séance quand la fatigue perturbe l’exécution. Après une interruption, reprendre graduellement. Un signal d’alerte mérite une consigne d’arrêt et une orientation adaptée. [ACSM, synthèse 2026](https://pubmed.ncbi.nlm.nih.gov/41843416/), [HAS, activité physique et sécurité](https://www.has-sante.fr/jcms/c_2876894/fr/guide-de-promotion-consultation-et-prescription-medicale-d-activite-physique-et-sportive-pour-la-sante-chez-les-adultes), [Assurance Maladie, douleur thoracique urgente](https://www.ameli.fr/assure/sante/themes/douleur-thoracique/reconnaitre-agit-urgence).

## 4. Règles de publication et tests

- Versionner les exercices et fiches avec leur source, leur public, leur date de vérification et leur texte. Chaque version de plan identifie le modèle utilisé. Le moteur applique les règles de progression et le ton choisi avant l’affichage d’une suggestion.
- Prévoir des alternatives et une pause sans pénalité. Un report, une non-réponse et une séance confirmée ont des effets différents sur les relances. Chaque relance vise une décision simple, par exemple « Tu gardes 18 h 30 ou on décale ? ».
- Utiliser le ton neutre sur le poids, l’apparence, la nutrition, les addictions et les symptômes. Un signal de restriction, de compensation par l’exercice ou de trouble alimentaire coupe les objectifs alimentaires chiffrés et renvoie vers une prise en charge adaptée. La grossesse, les restrictions médicales et les traitements sensibles demandent des conseils individualisés par un professionnel. [HAS, troubles des conduites alimentaires](https://www.has-sante.fr/jcms/c_2581436/fr/boulimie-et-hyperphagie-boulimique), [NICE, alimentation](https://www.nice.org.uk/guidance/ng246/chapter/Physical-activity-and-diet).
- Une douleur thoracique, un essoufflement inhabituel, un malaise ou une syncope déclenche l’arrêt de l’effort, la suspension des relances et une orientation adaptée. Un symptôme grave ou en cours doit conduire à proposer les services d’urgence locaux. Utiliser un message prédéfini. [HAS, consultation et activité physique](https://www.has-sante.fr/jcms/c_2876894/fr/guide-de-promotion-consultation-et-prescription-medicale-d-activite-physique-et-sportive-pour-la-sante-chez-les-adultes).
- Vérifier notamment les cas suivants. Un débutant choisit six jours et reçoit une alternance compatible avec sa récupération. Une séance reportée conserve un intervalle de repos. Une mesure de poids omise laisse l’entraînement accessible. Un symptôme d’alerte avec insultes au niveau maximal produit le même message d’arrêt qu’en mode neutre. Le retrait du consentement prend effet sur la prochaine relance.
- Évaluer la bêta sur les séances confirmées et programmées, les reports replanifiés, l’activation et la rétention par niveau de relances, les mises en sourdine et les retours volontaires. Les résultats servent à ajuster le produit. Une comparaison entre niveaux choisis par les utilisateurs ne démontre pas un effet causal du ton.

## 5. Fiches des exercices dans l’app

Dans le détail d’une séance, toucher un exercice ouvre sa fiche. L’installation, le mouvement, la respiration, une erreur fréquente et une adaptation ou une progression sont propres à la variante du plan. Le schéma tourne à la demande, avec pause, lecture normale ou ralentie et sélection des poses. Avec l’option iOS Réduire les animations, seules les poses statiques sont proposées. Le catalogue est local et fonctionne hors ligne.

Les schémas sont des silhouettes dessinées pour illustrer la trajectoire. Par exemple, la fiche « Vélo ou tapis » montre la marche sur tapis et explique aussi le réglage du vélo. Le dessin et les instructions devront être relus avant diffusion publique par une personne qualifiée, notamment les amplitudes, les appuis et les équipements. [ACE, bibliothèque d’exercices](https://www.acefitness.org/resources/everyone/exercise-library/), [ACE, presse à cuisses](https://www.acefitness.org/resources/everyone/exercise-library/154/seated-leg-press/), [ACE, gainage](https://www.acefitness.org/resources/everyone/exercise-library/32/front-plank/), [ACE, pont fessier](https://www.acefitness.org/resources/everyone/exercise-library/49/glute-bridge/).

## 6. Sources et révision du catalogue

Perplexity Search a servi à repérer les publications lors de deux recherches le 20 novembre 2026, puis de quatre recherches ciblées le 23 novembre 2026. Les quatre recherches ont répondu HTTP 200 et renvoyé 40 entrées brutes sur les macronutriments, les micronutriments, l’hydratation et la récupération, et le sport et les objectifs. Les sources retenues sont les publications d’origine et les recommandations officielles consultées. [Perplexity Search API](https://docs.perplexity.ai/docs/search/quickstart).

Le JSON garde un identifiant stable par fiche, une date de revue, des sections courtes et leurs références HTTPS. Revoir les chiffres avec la source d’origine avant de mettre à jour une fiche. Conserver la date des recommandations, le groupe auquel elles s’appliquent et la nature du chiffre. Pour les conseils à tester, préciser s’il s’agit d’un réglage KAARIS, d’une référence populationnelle ou du résultat d’une étude.

## 7. Push/pull et programme personnalisé sur cinq jours — 24 novembre 2026

### Combiner poussées et tirages

Tu peux mettre un développé et un tirage dans la même séance. Avec un volume comparable, la méta-analyse de Ramos-Campo et al. observe des gains moyens de force et de muscle similaires entre séances corps entier et programmes séparés par groupes. Les études sur la fréquence convergent vers un rôle faible ou incertain de la fréquence seule pour la prise de muscle quand le volume est comparable. Répartir les séries sur plusieurs jours aide à tenir le volume et à garder des séances de durée raisonnable. La semaine personnalisée ci-dessous adapte ces résultats issus de formats voisins. [Ramos-Campo et al., 2024](https://pubmed.ncbi.nlm.nih.gov/38595233/), [Schoenfeld et al., 2019](https://pubmed.ncbi.nlm.nih.gov/30558493/), [Pelland et al., en ligne 2025](https://pubmed.ncbi.nlm.nih.gov/41343037/).

Si la séance est courte, alterner un développé avec un tirage peut faire gagner du temps. Les superséries regroupées dans la méta-analyse de 2025 ont donné des gains moyens similaires à des séries classiques, avec une séance plus courte et un effort perçu plus élevé. Commence en séries classiques si tu découvres les exercices. Utilise l’alternance quand tu peux conserver les répétitions et la technique. [Zhang et al., 2025](https://doi.org/10.1007/s40279-025-02176-8).

### Exemple de semaine et exercices du catalogue

| Jour | Priorité | Salle | Haltères | Poids du corps |
| --- | --- | --- | --- | --- |
| Lundi | Pectoraux et triceps A | Développé à la machine | Développé haltères au sol | Pompes inclinées |
| Mardi | Dos et biceps A | Tirage horizontal assis, Tirage vertical poitrine, Curl biceps à la poulie | Rowing haltère unilatéral, Pull-over haltère au sol, Curl biceps avec haltères | Tirage des coudes au sol, Y-T-W au sol. Un élastique ou des haltères permettent d’ajouter un curl. |
| Mercredi | Repos ou activité facile | — | — | — |
| Jeudi | Jambes et abdos | Presse à cuisses, Soulevé de terre roumain avec haltères, Gainage ventral | Goblet squat, Soulevé de terre roumain avec haltères ou Fentes arrière avec haltères, Gainage ventral | Squat au poids du corps, Pont fessier au sol ou Fentes arrière avec appui, Gainage ventral |
| Vendredi | Pectoraux et triceps B | Développé à la machine, Développé épaules à la machine en option | Développé haltères au sol, Développé épaules avec haltères en option | Pompes inclinées et Pompes au mur, prise serrée |
| Samedi | Biceps B | Curl biceps à la poulie | Curl biceps avec haltères | Pour des séries biceps directes, utiliser un élastique ou des haltères. Une variante de curl sans matériel reste à documenter. |
| Dimanche | Repos ou activité facile | — | — | — |

Les développés sollicitent aussi les triceps. Le catalogue salle et haltères peut accueillir ultérieurement une extension triceps dédiée, avec son propre guide. Garde les pompes au mur en prise serrée dans les séances de poussée. Pour les biceps sans matériel, une variante de flexion du coude auto-résistée pourrait être documentée et testée avant d’être intégrée au plan.

### Dosage et récupération

- **Pectoraux.** Commence avec 3 à 4 séries de développé par jour, soit 6 à 8 séries hebdomadaires. Si tu récupères bien et progresses, tu peux te rapprocher d’environ 10 séries hebdomadaires. Ce dernier ordre de grandeur vient de l’ACSM pour la prise de muscle chez l’adulte sain. Les volumes de départ sont des choix de programmation à ajuster. [ACSM, recommandations 2026](https://acsm.org/resistance-training-guidelines-update-2026/).
- **Biceps.** Commence avec 2 à 3 séries de curl par jour, soit 4 à 6 séries directes hebdomadaires. Les tirages du mardi comptent aussi comme travail indirect. Pour les exercices chargés, teste une plage de 8 à 12 répétitions contrôlées et garde d’abord environ 2 à 3 répétitions possibles. Ajuste une seule variable à la fois. Ces valeurs servent de point de départ pour le programme. [ACSM, recommandations 2026](https://pubmed.ncbi.nlm.nih.gov/41843416/), [Pelland et al., séries directes et indirectes](https://pubmed.ncbi.nlm.nih.gov/41343037/).
- **Récupération.** Les deux expositions pectoraux et les deux expositions biceps sont éloignées dans cet exemple. Garde le samedi court et réduis les séries au besoin si les coudes ou les avant-bras fatiguent. Le mardi et le samedi suivent une autre séance du haut du corps, alors surveille la qualité des mouvements. Les essais sur des jours consécutifs suggèrent que la répartition peut rester flexible pour des programmes comparables. [Yang et al., 2018](https://doi.org/10.3389/fphys.2018.00725), [Carvalho et Santos, 2018](https://pubmed.ncbi.nlm.nih.gov/27682004/).
- **Dos et jambes.** Le plan privilégie les bras et les pectoraux. Pour le dos, démarre par 2 à 3 séries de chacun des deux mouvements retenus. Pour les jambes, choisis 2 à 3 séries de chaque mouvement de jambe et ajoute 2 tenues courtes de gainage. Si l’objectif devient plus équilibré, ajoute quelques séries de tirage ou de jambes à un autre créneau selon la récupération. Le repère général ACSM conseille de faire travailler les grands groupes environ deux fois par semaine. [ACSM, recommandations 2026](https://acsm.org/resistance-training-guidelines-update-2026/).

### Recherche Perplexity du 24 novembre

Le service Search a répondu HTTP 200 à trois requêtes avec huit entrées brutes chacune. La recherche push/pull a renvoyé la méta-analyse de Ramos-Campo, celle sur les superséries et un essai aigu sur les séries antagonistes. La recherche volume/fréquence a renvoyé Pelland et la prise de position ACSM, ainsi que des pages d’index PubMed. La recherche récupération a renvoyé les essais sur les jours consécutifs et non consécutifs. La sélection ci-dessus cite les publications directement et laisse les index et les études aiguës hors des conclusions sur la croissance à long terme. [Perplexity Search API](https://docs.perplexity.ai/docs/search/quickstart).

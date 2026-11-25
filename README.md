# KAARIS

Coach sportif gratuit pour iPhone, en français. Choisis un objectif et 2 à 6 séances par semaine. KAARIS prépare les exercices et les créneaux, rappelle les séances et recueille tes pointages.

## Essayer le prototype

Ouvrir `ios/Kaaris.xcodeproj`, choisir le schéma **Kaaris** et lancer sur un simulateur iOS 17 ou ultérieur. Configurer Supabase Auth comme décrit dans le [guide de déploiement](docs/DEPLOIEMENT.md#connexion-au-compte). La connexion est la première étape. Sur les iPhone compatibles, Face ID rouvre le compte après la première connexion. Une compilation Debug accepte `--demo` pour afficher un programme fictif.

- **Plan → Voir les démonstrations** ouvre une bibliothèque de 35 vidéos hors ligne avec Bellami. Le lecteur est également accessible dans chaque fiche, avec 17 vidéos de l’avatar et 18 démonstrations schématiques.
- Le programme de cinq séances associe deux journées pectoraux et triceps, deux biceps, une jambes et abdos et un travail du dos le premier jour biceps. Il utilise les haltères ou les machines et prépare deux semaines de créneaux, puis les complète à l’ouverture de l’app. Les profils existants peuvent l’activer depuis Plan.
- Dans une séance ou depuis Coach, dicte ou écris une adaptation. KAARIS propose une autre durée, un autre matériel, un type de séance, un effort ou un remplacement d’exercice. Tu peux affiner puis confirmer la modification de la séance dans le plan. La dictée reste sur l’iPhone si elle y est disponible. Les réponses variables utilisent la voix française d’iOS.
- Journal hors ligne avec séries, répétitions ou durée, charge facultative, corrections, bilan hebdomadaire et évolution par exercice.
- Onglet Repères avec recherche locale et 18 fiches sourcées sur le sport, la nutrition et la récupération.
- Rappels locaux iOS, notification de test, pause et heures silencieuses. Les réglages affichent les relances en file iOS et leur prochaine échéance. Le langage, la fréquence des relances et la pression sur l’ego se règlent séparément. Un consentement distinct active le ton cru dans les notifications.
- Pointage manuel ou vérification ponctuelle de proximité d’une salle enregistrée sur l’iPhone. Une relance peut ouvrir un appel simulé dans l’app avec la voix française Bellami et des réponses à toucher. Les répliques fixes produites par Eleven v4 fonctionnent hors ligne.
- Les mesures et habitudes sont optionnelles et stockées sur l’iPhone. Le temps d’écran se déclare manuellement.

## État des intégrations

Le flux Google Agenda nécessite l’URL publique de l’API, un client OAuth Google et la configuration Auth Supabase dans `ios/Local.xcconfig`. L’API lit les disponibilités et exporte les séances après validation. Pour la bêta, les modifications ou l’effacement d’événements déjà exportés se font dans Google Agenda. Les changements locaux n’écrasent pas l’événement distant.

Le schéma Supabase est déployé. Les séances et le profil du prototype restent locaux. Le coach en ligne utilise la session KAARIS et peut demander à Gemma 4 de choisir une variante de check-in. Le réglage est désactivé par défaut. Les réponses locales restent disponibles si l’API est absente ou indisponible. Les relances iOS sont locales. Le widget compilé à partir du build 2 ouvre le pointage depuis l’écran verrouillé. La configuration App Groups des deux cibles active l’affichage de la prochaine séance et du compteur. La lecture iOS du temps d’écran dépend de l’autorisation Family Controls.

## Maquettes et documents

- [Bienvenue](brand/maquettes/01-bienvenue.png), [Aujourd’hui](brand/maquettes/02-aujourdhui.png), [Plan](brand/maquettes/03-plan.png), [Coach](brand/maquettes/04-coach.png), [Réglages](brand/maquettes/05-reglages.png).
- [Identité, logo et avatar](brand/IDENTITE.md).
- [Cahier des charges](docs/CAHIER_DES_CHARGES.md).
- [Recherche sport et nutrition](docs/SPORT_NUTRITION.md).
- [Politique de confidentialité](docs/CONFIDENTIALITE.md).
- [Déploiement, variables et tests](docs/DEPLOIEMENT.md).

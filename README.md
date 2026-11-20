# KAARIS

Coach sportif gratuit pour iPhone, en français. Choisis un objectif et 2 à 6 séances par semaine. KAARIS prépare les exercices et les créneaux, rappelle les séances et recueille tes pointages.

## Essayer le prototype

Ouvrir `ios/Kaaris.xcodeproj`, choisir le schéma **Kaaris** et lancer sur un simulateur iOS 17 ou ultérieur. Ajouter l’argument `--demo` au lancement pour afficher un programme fictif sans connecter de compte. En usage normal, renseigner l’onboarding pour créer son programme.

- Plan par objectif, niveau, matériel et durée. Les 35 fiches d’exercice incluent une animation, les consignes de mouvement et de respiration et des pistes de progression.
- Rappels locaux iOS, notification de test, pause et heures silencieuses. Le langage, la fréquence des relances et la pression sur l’ego se règlent séparément. Un consentement distinct active le ton cru dans les notifications.
- Pointage manuel ou vérification ponctuelle de proximité d’une salle enregistrée sur l’iPhone. Une relance peut ouvrir un appel simulé dans l’app avec une voix synthétique française et des réponses à toucher.
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

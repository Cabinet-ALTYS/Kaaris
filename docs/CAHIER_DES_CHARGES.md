# KAARIS — Cahier des charges fonctionnel et technique

Version 0.3 · 23 novembre 2026 · Application gratuite pour iPhone · Français · Adultes

## 1. Objectif et périmètre

Le coach aide à passer d’une intention (« je veux m’entraîner quatre fois par semaine ») à un plan réalisable, des créneaux précis et un bilan honnête à la fin de la semaine. La boucle principale est **Objectif → plan → rappel → séance → journal → ajustement**. Le style peut être direct, provocateur et grossier sur accord explicite. Les actions du coach sont toujours réversibles ou confirmées par la personne.

| Bêta locale et lot progression | Intégrations et extensions |
|---|---|
| Onboarding, objectifs, préférences, séances 2 à 6 fois par semaine, proposition de créneaux, suivi manuel, rappels iOS locaux, bilan et trois curseurs | Google Agenda réel après autorisation OAuth, synchronisation Supabase, service IA auto-hébergé et distribution TestFlight après configuration des accès |
| Interface de check-in et bilan vocal dans l’app | Widget d’écran verrouillé, pointage géographique facultatif, données Temps d’écran après validation Apple et tests sur iPhone |
| Journal modifiable, historique par exercice, bilan de semaine, repères d’entraînement et nutrition embarqués | Synchronisation du journal, adaptation continue et relances distantes APNs après tests de restauration et de fiabilité |

La recette fonctionnelle de la bêta connectée inclut une lecture réelle des disponibilités Google et l’écriture confirmée d’une séance. Un build hors ligne constitue une première étape de test.

## 2. Inscription et profil

- Première ouverture. Présenter la promesse et recueillir la déclaration 18+. Utilisation locale possible. Ajouter un compte Supabase par e-mail lorsque la synchronisation est activée, avec confirmation, gestion des sessions, export et suppression depuis le compte.
- Questionner le but principal (prendre du muscle, perdre du poids, retrouver une routine, gagner en force ou améliorer la condition), le niveau, le nombre de séances (2–6), le matériel, la durée et les créneaux préférés. Autoriser la modification à tout moment. Distinguer cible et fréquence effectivement prévue.
- Taille, poids, alcool, tabac, autres habitudes et temps d’écran estimé sont facultatifs. Autoriser de passer chaque champ. Décrire l’usage avant collecte. Poids et habitudes sensibles restent privés par défaut. L’utilisateur peut effacer chaque valeur et utiliser le plan sans ces champs.
- Demander séparément notifications iOS, langage cru, accès Agenda, localisation et Temps d’écran. Reporter chaque demande de permission au moment où la fonction est déclenchée. Mémoriser la version du consentement et son retrait pour les réglages synchronisés.

## 3. Programmation des entraînements

1. Proposer un plan par niveau, temps, équipement et objectif. Les séances affichent leur durée, l’échauffement, les exercices, séries, fourchettes de répétitions, temps de repos et alternatives. L’ordre et la progression viennent d’un catalogue versionné.
2. Associer un créneau à chaque séance. En mode manuel, l’utilisateur renseigne jours et heures disponibles. En mode Google, intersecter ses préférences, horaires de sommeil et indisponibilités, avec une marge configurable. Respecter le fuseau de la personne et les changements d’heure.
3. Faire vérifier la proposition semaine par semaine. Chaque événement comporte durée, heure locale et libellé neutre. Si les créneaux manquent, afficher le déficit et les créneaux modifiables, sans inventer une disponibilité.
4. Après validation, écrire dans un agenda secondaire dédié. L’écriture est idempotente, liée à l’identifiant de séance, et un nouvel essai reprend les échecs partiels. Revérifier les conflits avant validation. Gérer déconnexion, refus, changement de fuseau, événement déplacé et accès révoqué.
5. L’utilisateur décide **J’y suis**, **Terminée**, **Reporter** ou **Passer**. Une absence de réponse produit « À confirmer ». Un pointage géographique facultatif confirme uniquement la proximité du gymnase à la demande. Le bilan distingue les résultats déclarés, les séances reportées et les séances à confirmer.

### Google Agenda

- OAuth individuel côté serveur, avec navigateur système, état à usage unique et PKCE. Stocker le jeton de rafraîchissement chiffré côté serveur et prévoir révocation côté Google. Restreindre les permissions à la liste des agendas en lecture, aux créneaux occupés et à l’agenda créé par l’app.
- Expérimenter l’adaptateur du [MCP officiel Google Calendar](https://developers.google.com/workspace/calendar/api/guides/configure-mcp-server) dans un environnement privé une fois le projet admis en Developer Preview et les outils vérifiés. La diffusion aux clients dépend de la disponibilité générale ou d’une autorisation Google. Toujours isoler les données et autorisations par compte. Le planificateur valide les arguments et l’accord de l’utilisateur avant toute écriture. [Conditions Developer Preview](https://developers.google.com/workspace/preview)
- L’adaptateur de la bêta utilise [FreeBusy](https://developers.google.com/workspace/calendar/api/v3/reference/freebusy/query), puis la [création d’événements](https://developers.google.com/workspace/calendar/api/v3/reference/events/insert) dans l’agenda dédié. Transmettre au planificateur les plages occupées et le fuseau. Exclure intitulés privés, descriptions et invités du contexte IA.

## 4. Coach, intensité et relances

| Réglage | Échelle et effet |
|---|---|
| Langage | 0 neutre, 1 direct, 2 familier, 3 grossier, 4 très grossier. Les niveaux familiers et crus demandent un accord distinct, désactivé au départ. |
| Relances | 0 aucune, 1 rappel avancé ou pointage à l’heure si le rappel avancé est passé et n’a pas été émis, 2 ajoute le pointage, 3 le suivi, 4 la préparation, 5 une relance supplémentaire. Maximum cinq relances automatiques par jour. |
| Ego | 0 factuel, 1 rappel de l’objectif, 2 défi, 3 rappel de l’engagement formulé par l’utilisateur. Fonctionne indépendamment du langage cru. |

- L’utilisateur peut essayer les niveaux avant de les activer. Exemple neutre « Ta séance commence dans 30 minutes. Tu y vas ? » Exemple cru opt-in « Bouffon, t’avais réservé ce créneau. Tu y vas ou tu le reprogrammes ? »
- Les textes cru et objectif restent par défaut dans l’app. Les notifications écran verrouillé restent discrètes. Horaires silencieux réglables, pause immédiate et bouton de désactivation explicite. Tout changement annule ou replanifie les notifications concernées. Les rappels déjà émis ne sont pas renvoyés en boucle.
- Le coach interpelle sur une action et propose un choix concret. Il évite le dénigrement du corps, les discriminations, les menaces, les boucles de honte et les injonctions à compenser par des restrictions ou de l’exercice. Le ton se désactive à tout moment.
- L’appel simulé s’ouvre au toucher d’une notification de pointage quand l’app est en arrière-plan. Au niveau maximum, un pointage peut ouvrir l’appel lorsque KAARIS est déjà à l’écran. Répondre ou refuser reste possible. Les phrases fixes Bellami sont disponibles hors ligne. Le microphone n’est pas utilisé par la bêta. CallKit et PushKit restent proposés pour un véritable service VoIP. [Apple PushKit](https://developer.apple.com/documentation/pushkit/responding-to-voip-notifications-from-pushkit)
- Widget d’écran verrouillé. Prochaine heure, compteur hebdo et accès au pointage. Employer WidgetKit, contenu neutre et données partagées limitées. [Apple WidgetKit](https://developer.apple.com/design/human-interface-guidelines/widgets)
- Temps d’écran. Estimation volontaire au départ. Automatisation via Family Controls, Device Activity et extensions après autorisation iOS, permission de distribution et vérification des restrictions de transmission. [Apple Family Controls](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)

## 5. Entraînement et nutrition

- Le coach couvre les mouvements principaux, la technique, les substitutions et la progression graduelle. En fréquence élevée, distribuer les sollicitations, varier les groupes et garder des jours légers. Si une série est maîtrisée sur plusieurs séances, proposer une petite progression, conditionnée à la récupération et à l’absence de douleur.
- Repères adultes et explications accessibles. Les décisions produit et les références sont détaillées dans [Sport et nutrition](SPORT_NUTRITION.md). Proposer des aliments et habitudes réalistes, distinguer prise de muscle et variation de poids, et expliquer la différence entre maintien, déficit et surplus. Toute cible chiffrée de la V1 reste un repère éducatif.
- Les valeurs de poids et taille sont facultatives et n’activent aucun diagnostic. En cas de douleur, maladie, suspicion de trouble alimentaire, grossesse, blessure ou traitement, interrompre l’ajustement automatique touchant le cas concerné et orienter vers un professionnel. Réduire l’intensité si fatigue ou douleur incompatibles avec la séance.
- L’onglet Repères fournit des fiches consultables hors ligne avec résumé, explications, liens vers les sources et date de revue. La recherche locale accepte les mots français avec ou sans accents et se combine avec le filtre par catégorie. Les fiches sont révisées sur leurs sources avant toute modification des repères chiffrés.

### Journal, progression et récupération

1. La fiche de séance permet de noter la date réalisée, les séries déclarées, les répétitions ou la durée et, si elle est connue, la charge en kg. Les nombres décimaux français sont acceptés. Les données manquantes restent vides et le pointage rapide est toujours disponible.
2. Enregistrer au plus un journal par identifiant de séance et conserver la relation après fermeture, retour hors ligne ou correction. Les anciennes séances terminées apparaissent dans l’historique avec leurs données disponibles. Une séance ancienne sans séries saisies ne contribue pas aux indicateurs de performance.
3. Depuis Plan, ouvrir le bilan de la semaine et l’historique. Compter les séances terminées selon leur date de réalisation lorsqu’elle est connue. Pour chaque exercice, comparer le même mouvement avec le même matériel et afficher la dernière séance, la meilleure valeur disponible et son évolution. Une tendance exige plusieurs observations comparables.
4. À partir de la fiche d’exercice, lancer ou annuler le repos prescrit. Le décompte se cale sur une échéance absolue pour récupérer le temps écoulé lorsque l’app est suspendue.
5. Pour les prochains lots, proposer un ajustement hebdomadaire à partir de l’assiduité, des séries et des indisponibilités. Présenter le motif, la nouvelle fréquence ou la variation proposée et demander confirmation avant de changer le plan. Les variations de poids et de tour de taille restent facultatives et séparées de la progression de force.

### Démonstrations

- Chaque fiche garde des repères écrits pour l’installation, le mouvement, la respiration et les erreurs courantes. Les démonstrations filmées sont courtes, sous-titrées selon le support et cadrées pour garder les articulations utiles et les deux pieds visibles. Bellami décrit ce qui se passe à l’écran. Le contenu doit rester compréhensible sans son.
- Une démonstration ne remplace la représentation schématique qu’après une vérification du geste, de la correspondance avec la bonne variante, de la lisibilité sur iPhone et des droits de redistribution. Pour un clip généré, vérifier la stabilité du sujet et de la caméra et l’absence de déformation entre départ, effort et retour.
- Le premier lot de production couvre les mouvements les plus présents dans les plans. Squat, tirage, poussée, charnière de hanche et gainage. Identifier chaque ressource par mouvement et variante de matériel, puis tester son indisponibilité et le repli local avant publication.
- Le build 0.2.0 (6) embarque le pilote de squat au poids du corps. L’avatar original présente les appuis en ouverture. Le geste est une prise filmée au ralenti avec légendes et voix off Bellami d’Eleven v4. Le cadrage bas de la prise met l’accent sur les hanches, genoux et appuis. La ressource est distribuée comme montage éducatif, avec crédit dans la fiche. [Prise Mixkit 44438](https://mixkit.co/free-stock-video/woman-and-man-doing-squats-together-in-a-gym-44438/) · [Licence Stock Video Free](https://mixkit.co/license/modal/videoFree/) · [Repères techniques ACE](https://www.acefitness.org/resources/everyone/exercise-library/135/bodyweight-squat/)

## 6. Architecture et données

- **iOS SwiftUI** avec stockage local, UserNotifications, clips Bellami et secours AVSpeechSynthesizer, extension WidgetKit et estimation volontaire du temps d’écran. Séances, journal, progression, fiches et pointage restent utilisables hors ligne. Le catalogue de fiches versionné est embarqué avec l’application et ne dépend pas du compte.
- **Supabase EU** pour Auth et Postgres. Tables de base profil, paramètres/consentement, séances et check-ins. Toutes les lignes exposées sont rattachées à leur propriétaire via RLS. Intégrations Google, données de service et secrets restent côté serveur. Seules les clés client publiables peuvent être embarquées. Schéma versionné, minimisation et suppression en cascade sous contrôle de l’utilisateur.
- **VPS neuf dédié** pour la passerelle d’API, le service Agenda, l’inférence et les tâches de relance distantes futures. HTTPS, clés SSH, accès privé au moteur IA, journalisation sans contenu ni jeton, pré-vérification du tarif TTC et des options de renouvellement, sauvegardes, déploiement et restauration documentés.
- **Moteur IA à poids ouverts** pour reformuler les messages consentis et répondre à partir des fiches. Le plan, les dates, les limites de relance et les événements sont gérés par le code. Accès du modèle limité à des actions autorisées et à un contexte réduit. Gabarits locaux si moteur indisponible. Mesurer débit, latence, empreinte mémoire et qualité du français avant de fixer le modèle.
- **Budget** 100 € autorisés pour l’infrastructure de départ. Vérifier séparément le total à payer et les renouvellements. Dépôt et Supabase existants à réutiliser. Aucun achat intégré ou abonnement client.

Pour la synchronisation, traiter la paire compte–séance comme clé d’unicité du journal. Les séries gardent un identifiant stable, une position, une unité et les valeurs connues. Appliquer les changements atomiquement par séance et rendre les reprises idempotentes. Vérifier côté serveur la propriété de la séance avant toute lecture ou écriture. Tester des modifications concurrentes et la restauration avant d’activer la synchronisation des journaux. Les données saisies dans le journal local ne partent pas vers le moteur IA.

## 7. Écrans

1. Accueil et onboarding. Promesse, déclaration adulte, objectif, fréquence, entrées facultatives et consentement au ton.
2. Aujourd’hui. Avatar, prochaine séance, pointage, accès au check-in.
3. Plan. Semaine, séance détaillée, choix des créneaux, saisie des séries, bilan et évolution par exercice.
4. Coach. Question du jour, bilan rapide et lecture vocale sur action.
5. Repères. Recherche et catégories pour les fiches sport, nutrition et récupération, avec leurs sources.
6. Réglages. Objectif, fréquence, curseurs, heures calmes, permissions, agenda et confidentialité.

## 8. Recette et livraison

| Cas | Résultat attendu |
|---|---|
| Objectif 2, 4 ou 6, puis redémarrage | Préférences conservées, plan cohérent, possibilité de déplacer chaque séance |
| Agenda avec collision ou accès révoqué | Créneau refusé ou erreur explicite, mode manuel disponible |
| Répétition de la validation Google | Une séance correspond à un événement, le succès partiel est récupérable |
| Consentement refusé ou retiré | Ton neutre ou familier selon réglage, aucun contenu cru dans les notifications futures |
| Relances coupées, pointage, ou séance reportée | Suppression des rappels futurs concernés |
| Deux comptes distincts | Lecture et modification transverses bloquées |
| Hors ligne puis retour réseau | Historique local accessible et reprise sans doublon |
| Ancienne séance terminée sans séries, puis correction d’une séance saisie | La première reste dans l’historique. La seconde reste unique et la correction se voit dans le bilan après redémarrage. |
| Charge `12,5`, poids du corps et exercice sur une autre machine | La virgule est acceptée. Le bilan garde séparés les équipements et les unités. |
| Recherche `proteines`, filtre et ouverture hors ligne | La fiche correspondante s’ouvre depuis l’app. Ses liens sources s’ouvrent lorsque le réseau est disponible. |
| Repos démarré, app en arrière-plan puis rouverte | Le temps affiché correspond à l’échéance initiale. |
| Présence inconnue | Afficher « À confirmer » et proposer le pointage |
| Signature, upload et traitement Apple | Identifier le build dans App Store Connect, vérifier son groupe TestFlight et tester sur iPhone |

Le nom **KAARIS** est le nom de travail. Le personnage, les visuels et la voix sont originaux. Vérifier les droits sur le nom avant distribution sous cette marque et utiliser un nom indépendant si nécessaire. [App Review Guidelines, §5.2](https://developer.apple.com/app-store/review/guidelines/#intellectual-property)

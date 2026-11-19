# KAARIS — Cahier des charges fonctionnel et technique

Version 0.1 · 19 novembre 2026 · Application gratuite pour iPhone · Français · Adultes

## 1. Objectif et périmètre

Le coach aide à passer d’une intention (« je veux m’entraîner quatre fois par semaine ») à un plan réalisable, des créneaux précis et un bilan honnête à la fin de la semaine. La boucle principale est **Objectif → plan → agenda → rappel → pointage → ajustement**. Le style peut être direct, provocateur et grossier sur accord explicite. Les actions du coach sont toujours réversibles ou confirmées par la personne.

| Premier build bêta | Intégrations et extensions |
|---|---|
| Onboarding, objectifs, préférences, séances 2 à 6 fois par semaine, proposition de créneaux, suivi manuel, rappels iOS locaux, bilan et trois curseurs | Google Agenda réel après autorisation OAuth, synchronisation Supabase, service IA auto-hébergé et distribution TestFlight après configuration des accès |
| Interface de check-in et bilan vocal dans l’app | Widget d’écran verrouillé, pointage géographique facultatif, données Temps d’écran après validation Apple et tests sur iPhone |
| Repères d’entraînement et nutrition documentés | Chat IA, relances distantes APNs et adaptation continue après tests de charge et de pertinence |

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
- Expérimenter l’adaptateur du [MCP officiel Google Calendar](https://developers.google.com/workspace/calendar/api/guides/configure-mcp-server) dans un environnement privé une fois le projet admis en Developer Preview et les outils vérifiés. La diffusion aux clients dépend de la disponibilité générale ou d’une autorisation Google. [Conditions Developer Preview](https://developers.google.com/workspace/preview) Toujours isoler les données et autorisations par compte. Le planificateur valide les arguments et l’accord de l’utilisateur avant toute écriture.
- L’adaptateur de la bêta utilise [FreeBusy](https://developers.google.com/workspace/calendar/api/v3/reference/freebusy/query), puis la [création d’événements](https://developers.google.com/workspace/calendar/api/v3/reference/events/insert) dans l’agenda dédié. Transmettre au planificateur les plages occupées et le fuseau. Exclure intitulés privés, descriptions et invités du contexte IA.

## 4. Coach, intensité et relances

| Réglage | Échelle et effet |
|---|---|
| Langage | 0 neutre, 1 direct, 2 familier, 3 grossier. Les niveaux crus demandent un accord distinct, désactivé au départ. |
| Relances | 0 aucune, 1 un rappel avant la séance, 2 ajoute le pointage à l’heure prévue, 3 ajoute un rappel de suivi en absence de réponse. Maximum de trois par séance, sous plafond quotidien. |
| Ego | 0 factuel, 1 rappel de l’objectif, 2 défi, 3 rappel de l’engagement formulé par l’utilisateur. Fonctionne indépendamment du langage cru. |

- L’utilisateur peut essayer les niveaux avant de les activer. Exemple neutre « Ta séance commence dans 30 minutes. Tu y vas ? » Exemple cru opt-in « Bouffon, t’avais réservé ce créneau. Tu y vas ou tu le reprogrammes ? »
- Les textes cru et objectif restent par défaut dans l’app. Les notifications écran verrouillé restent discrètes. Horaires silencieux réglables, pause immédiate et bouton de désactivation explicite. Tout changement annule ou replanifie les notifications concernées. Les rappels déjà émis ne sont pas renvoyés en boucle.
- Le coach interpelle sur une action et propose un choix concret. Il évite le dénigrement du corps, les discriminations, les menaces, les boucles de honte et les injonctions à compenser par des restrictions ou de l’exercice. Le ton se désactive à tout moment.
- L’« appel » est un check-in dans l’app, accessible par une notification clairement identifiée. Afficher le coach, les actions répondre/refuser et les questions. Voix synthétique originale, action volontaire avant ouverture du micro, transcription facultative. CallKit et PushKit réservés à un véritable service VoIP. [Apple PushKit](https://developer.apple.com/documentation/pushkit/responding-to-voip-notifications-from-pushkit)
- Widget d’écran verrouillé. Prochaine heure, compteur hebdo et accès au pointage. Employer WidgetKit, contenu neutre et données partagées limitées. [Apple WidgetKit](https://developer.apple.com/design/human-interface-guidelines/widgets)
- Temps d’écran. Estimation volontaire au départ. Automatisation via Family Controls, Device Activity et extensions après autorisation iOS, permission de distribution et vérification des restrictions de transmission. [Apple Family Controls](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)

## 5. Entraînement et nutrition

- Le coach couvre les mouvements principaux, la technique, les substitutions et la progression graduelle. En fréquence élevée, distribuer les sollicitations, varier les groupes et garder des jours légers. Si une série est maîtrisée sur plusieurs séances, proposer une petite progression, conditionnée à la récupération et à l’absence de douleur.
- Repères adultes et explications accessibles. Les décisions produit et les références sont détaillées dans [Sport et nutrition](SPORT_NUTRITION.md). Proposer des aliments et habitudes réalistes, distinguer prise de muscle et variation de poids, et expliquer la différence entre maintien, déficit et surplus. Toute cible chiffrée de la V1 reste un repère éducatif.
- Les valeurs de poids et taille sont facultatives et n’activent aucun diagnostic. En cas de douleur, maladie, suspicion de trouble alimentaire, grossesse, blessure ou traitement, interrompre l’ajustement automatique touchant le cas concerné et orienter vers un professionnel. Réduire l’intensité si fatigue ou douleur incompatibles avec la séance.

## 6. Architecture

- **iOS SwiftUI** avec stockage local, UserNotifications, AVSpeechSynthesizer, futures extensions WidgetKit et Screen Time. Mode déconnecté pour séances et pointage. Synchronisation déclenchée par activité et reprise en cas d’erreur.
- **Supabase EU** pour Auth et Postgres. Tables de base profil, paramètres/consentement, séances et check-ins. Toutes les lignes exposées sont rattachées à leur propriétaire via RLS. Intégrations Google, données de service et secrets restent côté serveur. Seules les clés client publiables peuvent être embarquées. Schéma versionné, minimisation et suppression en cascade sous contrôle de l’utilisateur.
- **VPS neuf dédié** pour la passerelle d’API, le service Agenda, l’inférence et les tâches de relance distantes futures. HTTPS, clés SSH, accès privé au moteur IA, journalisation sans contenu ni jeton, pré-vérification du tarif TTC et des options de renouvellement, sauvegardes, déploiement et restauration documentés.
- **Moteur IA à poids ouverts** pour reformuler les messages consentis et répondre à partir des fiches. Le plan, les dates, les limites de relance et les événements sont gérés par le code. Accès du modèle limité à des actions autorisées et à un contexte réduit. Gabarits locaux si moteur indisponible. Mesurer débit, latence, empreinte mémoire et qualité du français avant de fixer le modèle.
- **Budget** 100 € autorisés pour l’infrastructure de départ. Vérifier séparément le total à payer et les renouvellements. Dépôt et Supabase existants à réutiliser. Aucun achat intégré ou abonnement client.

## 7. Écrans

1. Accueil et onboarding. Promesse, déclaration adulte, objectif, fréquence, entrées facultatives et consentement au ton.
2. Aujourd’hui. Avatar, prochaine séance, pointage, accès au check-in.
3. Plan. Semaine, séance détaillée, choix des créneaux, états des sessions.
4. Coach. Question du jour, bilan rapide et lecture vocale sur action.
5. Réglages. Objectif, fréquence, curseurs, heures calmes, permissions, agenda et confidentialité.

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
| Présence inconnue | Afficher « À confirmer » et proposer le pointage |
| Signature, upload et traitement Apple | Identifier le build dans App Store Connect, vérifier son groupe TestFlight et tester sur iPhone |

Le nom **KAARIS** est le nom de travail. Le personnage, les visuels et la voix sont originaux. Vérifier les droits sur le nom avant distribution sous cette marque et utiliser un nom indépendant si nécessaire. [App Review Guidelines, §5.2](https://developer.apple.com/app-store/review/guidelines/#intellectual-property)

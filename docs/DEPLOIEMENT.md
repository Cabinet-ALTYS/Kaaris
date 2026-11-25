# Déploiement de KAARIS

## État vérifié le 19 novembre 2026

| Composant | État |
|---|---|
| GitHub | Dépôt public [Cabinet-ALTYS/Kaaris](https://github.com/Cabinet-ALTYS/Kaaris). Les secrets restent dans les configurations locales ignorées. |
| Supabase | Projet KAARIS actif en région Paris `eu-west-3`. Migration `20261119080059_kaaris_initial_schema` appliquée et relue. Les six tables existent, toutes avec RLS. |
| Serveur API | Programme Node 24, sans dépendance npm. Tests locaux des échanges HTTP, OAuth, créneaux concurrents et choix des relances. Les fournisseurs sont simulés dans ces tests. |
| Google Agenda | Parcours OAuth et appels REST implémentés. Le client OAuth Google et un callback HTTPS sont requis pour une recette avec un agenda réel. |
| Inférence | Profil llama.cpp pour Gemma 4 E4B IT QAT Q4_0, dimensionné pour un VPS de 8 Go. Démarrage et performances à mesurer sur le serveur. |

Les quatre tables produit sont accessibles uniquement au compte authentifié propriétaire. Les deux tables OAuth sont réservées au rôle serveur. Le contrôle Supabase a relevé deux notices d’absence de politique sur ces tables réservées. Il a aussi signalé la fonction système préexistante `rls_auto_enable()`. Sa signature est `event_trigger` et son déclencheur est présent.

Ne pas mettre de clé privilégiée, de mot de passe de base de données, de coordonnées, d’agenda ou de données de test nominatives dans GitHub. L’identifiant Supabase et la clé publiable peuvent être configurés côté app. Le mot de passe Postgres communiqué dans la conversation doit être renouvelé avant tout accès SQL direct et ne sert pas au parcours API. [Rotation du mot de passe Supabase](https://supabase.com/kb/troubleshooting/how-do-i-reset-my-supabase-database-password-oTs5sB).

## Infrastructure

Réutiliser le projet Supabase existant. Le tarif de calcul affiché pour une instance Micro supplémentaire dans une organisation Pro est de 10 USD par mois, avec 10 USD de crédit de calcul mensuel au niveau de l’organisation. Consulter la facture et la taille du projet pour connaître le coût supplémentaire effectif. [Tarifs Supabase](https://supabase.com/pricing).

Le profil de déploiement cible un VPS OVHcloud Linux x86-64 doté de 4 vCPU, 8 Go de RAM et 75 Go de stockage. Les recettes ci-dessous s’appliquent à une version maintenue d’Ubuntu ou de Debian. [Gamme VPS OVHcloud](https://www.ovhcloud.com/fr/vps/) · [Docker sur Ubuntu](https://docs.docker.com/engine/install/ubuntu/) · [Docker sur Debian](https://docs.docker.com/engine/install/debian/).

Le fichier Gemma 4 E4B IT QAT Q4_0 officiel pèse 5,15 Go. Le profil impose 6 Gio et trois vCPU au conteneur, avec trois threads, une requête à la fois et un contexte de 1 536 jetons. La limite laisse environ 1,2 Gio au-dessus de la taille du fichier pour le cache et les buffers du modèle, ainsi qu’une marge sur le VPS pour Linux, Caddy et l’API. Vérifier la mémoire réelle au démarrage et en charge. Le projecteur multimodal est désactivé, car le coach traite du texte. [Gemma 4 E4B IT QAT](https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf) · [Options du serveur llama.cpp](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md).

## Configuration du serveur

1. Préparer le VPS pour KAARIS et valider l’accès SSH par clé. Installer Docker Engine, Buildx et le plugin Compose depuis le dépôt APT officiel de la distribution. Vérifier `docker version` et `docker compose version`. L’image de l’API fournit Node 24. Pour HTTPS, renseigner un nom public dont les enregistrements DNS pointent vers le VPS, puis vérifier que Caddy peut écouter sur les ports 80 et 443. Préserver l’accès SSH d’administration. [HTTPS automatique de Caddy](https://caddyserver.com/docs/automatic-https).
2. Déployer une copie de travail de la version validée. Dans `server/`, créer `.env` depuis `.env.example` avec des permissions `0600`. Le fichier est ignoré par Git. Garder la copie de récupération des secrets dans le coffre de l’utilisateur.
3. Renseigner `KAARIS_HOST` avec le nom seul et `SUPABASE_URL` avec l’URL HTTPS du projet. Fournir `SUPABASE_PUBLISHABLE_KEY` et `SUPABASE_SECRET_KEY` depuis **Settings → API Keys** de ce projet. Le serveur accepte une clé `sb_secret_…` ou une clé héritée `service_role`. L’app attend une clé `sb_publishable_…`. Renseigner la clé serveur via un canal privé, dans un fichier `.env` restreint. Conserver le port par défaut. [Clés API Supabase](https://supabase.com/docs/guides/getting-started/api-keys).
4. Laisser `GOOGLE_CLIENT_ID` vide pour démarrer l’API et le modèle sans Google Agenda. Pour activer Agenda, préparer un projet Google dédié et un client OAuth de type application Web. Déclarer les utilisateurs autorisés et l’URL exacte `https://<hôte>/v1/google/callback`. Renseigner `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI` et une clé aléatoire de 32 octets encodée en base64 dans `OAUTH_ENCRYPTION_KEY`. Changer cette clé sans migration oblige les utilisateurs à reconnecter leur compte Google.
5. Configurer côté iOS le nom HTTPS de l’API, le projet Auth Supabase et le schéma `kaaris://` utilisé par la session d’authentification système. L’enregistrement de l’URL de retour Google se fait avec l’URL HTTPS de l’API.
6. Démarrer un seul processus API pour la bêta. Les verrous de confirmation et d’inférence sont locaux au processus. Le serveur garde une identité d’événement stable chez Google pour les reprises après incident.
7. Déployer le profil Compose `model` après avoir vérifié le fichier du modèle. La génération du coach reçoit les variantes autorisées, le type de relance et les niveaux choisis. Elle ne reçoit ni agenda, ni poids, ni localisation.

Démarrer l’API avec Caddy, puis vérifier l’obtention du certificat et la réponse.

```sh
cd server
docker compose --profile model config --quiet
docker compose up -d --build
docker compose ps
curl -fsS https://kaaris-api.example.com/healthz
```

Télécharger les poids depuis `server/` sur le VPS. Le script reprend le téléchargement dans un fichier temporaire, vérifie le SHA-256 à la révision officielle épinglée, puis rend le GGUF disponible à llama.cpp.

```sh
sh fetch-model.sh
```

Renseigner `INFERENCE_ORIGIN=http://inference:8080` dans `.env`, puis démarrer le profil. Le serveur llama.cpp écoute uniquement sur le réseau interne de Compose.

```sh
docker compose --profile model up -d --build
docker compose --profile model ps
docker compose --profile model exec -T api node -e 'fetch("http://inference:8080/health", { signal: AbortSignal.timeout(5000) }).then(async r => { console.log(r.status, await r.text()); process.exitCode = r.ok ? 0 : 1; })'
docker stats --no-stream
```

Attendre `200` sur `/health` côté modèle et noter le temps de démarrage ainsi que la RAM consommée. Tester ensuite dix requêtes authentifiées et séquentielles à `/v1/coach/message` avec un consentement actif et des niveaux fictifs non nuls. Relever les latences et la proportion de réponses `source: model`. L’API bascule sur un texte local après six secondes d’attente du modèle. Un résultat `source: template` est aussi possible quand le modèle est occupé ou renvoie un format inattendu.

Si la mémoire manque ou que la latence fait basculer la majorité des requêtes, utiliser le modèle officiel E2B QAT Q4_0 de 3,35 Go. Exécuter `sh fetch-model.sh e2b`, renseigner `KAARIS_MODEL_FILE=gemma-4-E2B_q4_0-it.gguf` et relancer `docker compose --profile model up -d`. Refaire les mêmes mesures. [Gemma 4 E2B IT QAT](https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf).

Pour désactiver l’inférence, vider `INFERENCE_ORIGIN`, recréer l’API avec `docker compose up -d --force-recreate api`, puis arrêter le conteneur du modèle avec `docker compose --profile model stop inference`.

## Connexion au compte

La version iOS utilise directement Supabase Auth. Renseigner `SUPABASE_URL` et `SUPABASE_PUBLISHABLE_KEY` dans `ios/Local.xcconfig`. La présence de `KAARIS_API_URL` active aussi les intégrations du serveur, dont Google Agenda. Le serveur KAARIS ne participe pas à la connexion à l’application.

- **E-mail.** Activer l’inscription et la confirmation des adresses. Ajouter `kaaris://email-confirmed` à la liste des URL de redirection autorisées. Après confirmation, l’utilisateur se connecte dans l’app. Configurer un SMTP transactionnel pour les adresses hors équipe Supabase. [SMTP Supabase](https://supabase.com/docs/guides/auth/auth-smtp)
- **Google.** Déclarer un client OAuth de type Application Web dans Google Auth Platform, avec l’URL de rappel `https://<référence>.supabase.co/auth/v1/callback`. Activer Google dans Supabase Auth et ajouter `kaaris://auth-callback` aux URL de redirection autorisées. L’app utilise PKCE. Le client de connexion n’a besoin que des données d’identité. [Google dans Supabase](https://supabase.com/docs/guides/auth/social-sign-in/auth-google)
- **Apple.** Activer Sign in with Apple sur l’App ID `com.kaariscoach.ios`, signer avec le profil qui inclut la capacité et ajouter cet App ID aux identifiants autorisés dans Supabase Auth. Le flux iOS échange le jeton d’identité et le nonce avec Supabase. [Apple natif dans Supabase](https://supabase.com/docs/guides/auth/social-sign-in/auth-apple)

Recette iPhone. Vérifier l’écran de connexion au premier lancement, l’inscription et la confirmation par e-mail, les deux fournisseurs, puis le retour à l’app via Face ID sur un appareil inscrit. Vérifier la reconnexion en cas de refus, le retour après mise en arrière-plan et le passage d’un compte à l’autre. Les profils sportifs, programmes et journaux sont locaux et distincts par compte. Les anciens profils créés avant la connexion obligatoire restent sur l’appareil sans être associés automatiquement à un compte.

## Contrat API

Toutes les routes privées attendent `Authorization: Bearer <access_token Supabase Auth>`. Les POST de données attendent `Content-Type: application/json`.

| Méthode et route | Entrée et résultat |
|---|---|
| `GET /healthz` | Public. Réponse `{ "status": "ok" }`. |
| `GET /v1/google/status` | `{ available, connected }`. La présence d’une connexion stockée est vérifiée. Les lectures Google vérifient ensuite sa validité réelle. |
| `POST /v1/google/connect` | Sans corps. Retour `{ authorizationUrl }`. État aléatoire et PKCE, expiration en dix minutes, usage unique. |
| `GET /v1/google/callback` | Public. OAuth Google renvoie `code` et `state`. La réponse redirige vers `kaaris://google-connected?status=connected` ou `status=error&code=…`. |
| `DELETE /v1/google/connection` | Révoque l’autorisation et efface les jetons de ce compte, réponse 204. |
| `GET /v1/google/calendars` | `{ calendars: [{ id, title, primary }] }`. L’agenda d’écriture dédié de KAARIS est écarté des choix. |
| `POST /v1/google/freebusy` | `{ calendarIds, timeMin, timeMax, timeZone }`. Retour `{ busy: [{ start, end }], unavailableCalendarIds }`. Jusqu’à dix calendriers et 31 jours. |
| `POST /v1/google/sessions` | `{ sessions: [{ id, title, startsAt, endsAt }], calendarIds, timeZone? }`. Retour `{ sessions: [{ id, status, eventId?, code? }] }`. Jusqu’à 12 séances datées, chacune de 15 à 180 minutes. |
| `POST /v1/coach/message` | `{ event, insultLevel, egoLevel, bluntToneConsented }`. Les niveaux sont des entiers de 0 à 4. Types `reminder`, `check_in`, `missed`, `done`. Retour `{ text, source }`. |
| `GET /v1/voice/status` | `{ available }`. Indique la présence de la configuration serveur ElevenLabs. |
| `POST /v1/voice/check-in` | `{ phase, tone, bluntToneConsented }`. Phases `greeting`, `workout`, `nutrition`, `closing`. Tons `neutral`, `direct` et `intense`. Retour MP3 `audio/mpeg`. |

Les dates sont au format RFC 3339 avec décalage ou suffixe `Z`. Les fuseaux sont des identifiants IANA. Les statuts de confirmation sont `booked`, `conflict` et `error`. Seul `booked` confirme une écriture Google. Si la disponibilité d’un agenda ne peut pas être vérifiée, la réservation échoue pour la séance concernée. En cas de réseau interrompu, reprendre avec les mêmes identifiants de séances. Reconfirmer le créneau si ses horaires ont changé.

Google expose la disponibilité sans contenu d’événement. KAARIS utilise le périmètre `calendar.app.created` pour créer l’agenda secondaire privé d’entraînement et les séances confirmées. Une révocation arrête les accès futurs. Les événements déjà inscrits sont gérés depuis Google Agenda. Avec une application Google externe en mode test et ces scopes, prévoir un renouvellement du consentement au bout de sept jours. [Scopes Calendar](https://developers.google.com/workspace/calendar/api/auth) · [OAuth Web](https://developers.google.com/identity/protocols/oauth2/web-server) · [Expiration des jetons Google](https://developers.google.com/identity/protocols/oauth2#expiration).

Le MCP Google Calendar officiel est en Developer Preview. Son activation demande un projet et un client OAuth déclarés pour un agent IA. Valider ces accès, les paramètres de l’outil et ses scopes avant d’intégrer son adaptateur. Le service actuel utilise Google Calendar REST avec OAuth par compte. [Documentation MCP Google Calendar](https://developers.google.com/workspace/calendar/api/guides/configure-mcp-server).

## Voix du coach

Depuis le build 4, les répliques fixes de l’appel simulé et du pointage utilisent Bellami en local. Les douze extraits Eleven v4 livrés dans l’app correspondent aux quatre phases et aux trois tons configurés dans `server/src/voice.mjs`. Le ton neutre s’applique sans consentement au langage cru. L’appel de test utilise le ton réglé sur l’appareil et reste local.

Pour la synthèse vocale distante, renseigner dans le fichier serveur `.env` restreint `ELEVENLABS_API_KEY` et `ELEVENLABS_VOICE_ID`. Choisir une voix française originale ou une voix de catalogue dont les droits couvrent l’usage de l’app. Réserver la clé au serveur et au périmètre Text to Speech. La valeur par défaut de `ELEVENLABS_MODEL_ID` est `eleven_v4`. `eleven_v3` peut être sélectionné explicitement après une écoute comparative. Recréer le service avec `docker compose up -d --force-recreate api` après modification. [Voix et débit de synthèse](https://elevenlabs.io/docs/eleven-creative/playground/text-to-speech) · [Create speech](https://elevenlabs.io/docs/api-reference/text-to-speech/convert).

Les paramètres de phase et de ton choisissent l’une des douze phrases françaises prévues par l’app. Les tons directs et intenses requièrent `bluntToneConsented=true`, sinon la phrase neutre est employée. ElevenLabs reçoit uniquement la phrase fixe avec sa balise d’interprétation. Les données du compte, les réponses de l’utilisateur et les informations de ses séances restent dans KAARIS. [Balises audio d’Eleven v4](https://elevenlabs.io/docs/help-center/product/core-capabilities/text-to-speech/how-do-audio-tags-work-with-eleven-v3-and-v4).

Les MP3 sont conservés en mémoire jusqu’au redémarrage du processus et mutualisés entre comptes. Le serveur accepte au plus 30 demandes par compte et par fenêtre de dix minutes, deux synthèses en cours et 18 tentatives fournisseur par jour UTC et par processus. Ces compteurs redémarrent avec l’API. Un plafond de crédits chez ElevenLabs complète ces limites. Le cache couvre 12 clips de 512 Kio maximum chacun. L’API peut répondre `503` si la voix distante est désactivée ou occupée, `502` en cas de panne fournisseur et `429` si un quota est atteint. L’app peut alors lire la phrase de secours sur l’iPhone.

Eleven v4 règle l’expression du coach. Un futur échange vocal demanderait un parcours distinct pour recevoir et transcrire la voix de l’utilisateur. Scribe v3 Live fournit la transcription et certains signaux de tour de parole. Le mode expressif ElevenAgents adapte le tour de parole et la voix à des indices comme la prosodie et le contexte. Son analyse de sentiment s’appuie sur la transcription de conversations terminées. Un indice vocal ou textuel reste une estimation et ne permet pas d’établir l’émotion réelle d’une personne. La version actuelle fonctionne avec les réponses explicites dans l’interface. [Modèles Scribe](https://elevenlabs.io/docs/overview/models) · [Mode expressif ElevenAgents](https://elevenlabs.io/docs/eleven-agents/customization/voice/expressive-mode) · [Analyse de sentiment](https://elevenlabs.io/docs/eleven-agents/customization/agent-analysis/sentiment-analysis).

## Recette de bêta

- Lancer `npm --prefix server test` à la racine et inspecter `/healthz` sur le VPS.
- Installer la version de test iOS et se connecter avec un compte Supabase de recette confirmé. Consentir à la liaison avec un agenda de test. Observer la liste des agendas et un créneau occupé.
- Confirmer un créneau libre, relire la séance dans l’agenda secondaire, répéter la requête avec le même UUID et vérifier qu’un seul événement existe. Tester un conflit réel et la révocation.
- Tester la pause des rappels et le mode neutre sur écran verrouillé, puis relever les réponses `template` ou `model` ainsi que la latence.
- Avec une configuration ElevenLabs autorisée, écouter le même extrait neutre deux fois depuis un compte de recette et vérifier que le second est servi sans nouvelle génération. Tester un ton direct avec et sans consentement, puis le secours iPhone avec le service indisponible.
- Une fois la distribution autorisée, vérifier dans TestFlight le build traité et l’installation sur un appareil réel.

Les migrations futures vont dans `supabase/migrations/`. Vérifier le journal avant activation d’un déploiement automatique GitHub, qui peut appliquer les migrations de la branche de production dès le push. [Intégration GitHub Supabase](https://supabase.com/docs/guides/deployment/branching/github-integration).

# Déploiement de KAARIS

## État vérifié le 19 novembre 2026

| Composant | État |
|---|---|
| GitHub | Dépôt créé par le porteur de projet. Vérifier sa visibilité avant toute publication de code. |
| Supabase | Projet KAARIS actif en région Paris `eu-west-3`. Migration `20261119080059_kaaris_initial_schema` appliquée et relue. Les six tables existent, toutes avec RLS. |
| Serveur API | Programme Node 24, sans dépendance npm. Tests locaux des échanges HTTP, OAuth, créneaux concurrents et choix des relances. Les fournisseurs sont simulés dans ces tests. |
| Google Agenda | Parcours OAuth et appels REST implémentés. Le client OAuth Google et un callback HTTPS sont requis pour une recette avec un agenda réel. |
| Inférence | Configuration Gemma 4 12B IT QAT Q4_0 et llama.cpp prête. Mesure de latence et de RAM requise sur le VPS choisi. |

Les quatre tables produit sont accessibles uniquement au compte authentifié propriétaire. Les deux tables OAuth sont réservées au rôle serveur. Le contrôle Supabase a relevé deux notices d’absence de politique sur ces tables réservées. Il a aussi signalé la fonction système préexistante `rls_auto_enable()`. Sa signature est `event_trigger` et son déclencheur est présent.

Ne pas mettre de clé privilégiée, de mot de passe de base de données, de coordonnées, d’agenda ou de données de test nominatives dans GitHub. L’identifiant Supabase et la clé publiable peuvent être configurés côté app. Le mot de passe Postgres communiqué dans la conversation doit être renouvelé avant tout accès SQL direct et ne sert pas au parcours API. [Rotation du mot de passe Supabase](https://supabase.com/kb/troubleshooting/how-do-i-reset-my-supabase-database-password-oTs5sB).

## Infrastructure

Réutiliser le projet Supabase existant. Le tarif de calcul affiché pour une instance Micro supplémentaire dans une organisation Pro est de 10 USD par mois, avec 10 USD de crédit de calcul mensuel au niveau de l’organisation. Consulter la facture et la taille du projet pour connaître le coût supplémentaire effectif. [Tarifs Supabase](https://supabase.com/pricing).

Choix initial OVHcloud VPS-3 2027 en France ou en Europe, Linux x86-64, 6 vCPU, 12 Go de RAM et 100 Go NVMe. Le catalogue API France affichait 12,24 € HT soit 14,69 € TTC par mois dans le mode mensuel, sans frais d’installation. Le tarif de 12,48 € TTC par mois affiché sur le site correspond à un prépaiement de 12 mois, soit 149,76 € TTC. Le VPS-4 à 24 Go était affiché à 28,19 € TTC par mois en mode mensuel. Confirmer le prix, la durée et les options dans le panier réel. [Catalogue OVHcloud France](https://eu.api.ovh.com/v1/order/catalog/public/vps?ovhSubsidiary=FR) · [Gamme VPS](https://www.ovhcloud.com/fr/vps/).

Gemma 4 12B tient dans un fichier de 6,98 Go. Le réglage initial utilise une requête à la fois et un contexte de 3 072 jetons. Le modèle Qwen3.8-27B quantifié Q4_K_M pèse 19,4 Go. Le cache et le système demandent aussi de la RAM. Le choix Gemma vise la bêta sur CPU et ne constitue pas une comparaison de qualité ou une mesure de débit. [Gemma 4](https://ai.google.dev/gemma/docs/core) · [Gemma 4 12B IT QAT](https://huggingface.co/google/gemma-4-12B-it-qat-q4_0-gguf) · [Qwen3.8-27B Q4_K_M](https://huggingface.co/ggml-org/Qwen3.8-27B-GGUF/blob/main/Qwen3.8-27B-Q4_K_M.gguf).

## Configuration du serveur

1. Préparer le VPS pour KAARIS, valider l’accès SSH par clé et déclarer le nom DNS dédié. Installer Docker Engine et le plugin Compose depuis les paquets officiels de la distribution. Les seuls ports du projet destinés au public sont 80 et 443. Préserver l’accès SSH d’administration.
2. Déployer une copie de travail de la version validée. Dans `server/`, créer `.env` depuis `.env.example` avec des permissions `0600`. Le fichier est ignoré par Git. Garder la copie de récupération des secrets dans le coffre de l’utilisateur.
3. Renseigner `KAARIS_HOST`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` et `SUPABASE_SECRET_KEY`. Cette dernière peut être une clé serveur `sb_secret_…` ou une clé héritée `service_role`. Vérifier que les clés correspondent au projet KAARIS. Conserver le réglage `PORT` par défaut dans Compose.
4. Activer Calendar API dans un projet Google dédié. Créer un client OAuth de type application Web, renseigner les utilisateurs autorisés et déclarer l’URL exacte `https://<hôte>/v1/google/callback`. Configurer `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` et `GOOGLE_REDIRECT_URI`. Garder une clé aléatoire de 32 octets encodée en base64 dans `OAUTH_ENCRYPTION_KEY`. Changer cette clé sans migration oblige à reconnecter les comptes.
5. Configurer côté iOS le nom HTTPS de l’API, le projet Auth Supabase et le schéma `kaaris://` utilisé par la session d’authentification système. L’enregistrement de l’URL de retour Google se fait avec l’URL HTTPS de l’API.
6. Démarrer un seul processus API pour la bêta. Les verrous de confirmation et d’inférence sont locaux au processus. Le serveur garde une identité d’événement stable chez Google pour les reprises après incident.
7. Déployer le profil Compose `model` après avoir vérifié le fichier du modèle. La génération du coach reçoit les variantes autorisées, le type de relance et les niveaux choisis. Elle ne reçoit ni agenda, ni poids, ni localisation.

Démarrer l’API avec Caddy, puis vérifier l’obtention du certificat et la réponse.

```sh
cd server
docker compose up -d --build
docker compose ps
curl -fsS https://kaaris-api.example.com/healthz
```

Télécharger les poids officiels à la révision contrôlée. Cette commande se lance dans `server/` sur le VPS.

```sh
mkdir -p models
curl --fail --location --retry 2 \
  -o models/gemma-4-12b-it-qat-q4_0.gguf \
  https://huggingface.co/google/gemma-4-12B-it-qat-q4_0-gguf/resolve/29d097773436b69ff9feafd636ab4cf873786537/gemma-4-12b-it-qat-q4_0.gguf
printf '%s  %s\n' \
  93567e57a8fe10b23569b9d9ec38cd005deedf71e29477c421a4b83f418a538b \
  models/gemma-4-12b-it-qat-q4_0.gguf | sha256sum -c -
```

Renseigner `INFERENCE_ORIGIN=http://inference:8080` dans `.env` puis démarrer le profil.

```sh
docker compose --profile model up -d --build
docker compose --profile model ps
docker compose --profile model exec -T api node -e 'fetch("http://inference:8080/health").then(async r => { console.log(r.status, await r.text()); process.exitCode = r.ok ? 0 : 1; })'
docker stats --no-stream
```

Vérifier les limites de RAM, le temps de cold start et la latence sur au moins dix appels consentis avec des valeurs fictives. Une réponse de source `model` confirme que le modèle a choisi une variante. Une réponse de source `template` maintient les relances si le modèle est occupé, hors délai ou invalide. Retirer `INFERENCE_ORIGIN` de la configuration et redémarrer le service API pour désactiver l’inférence.

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

Les dates sont au format RFC 3339 avec décalage ou suffixe `Z`. Les fuseaux sont des identifiants IANA. Les statuts de confirmation sont `booked`, `conflict` et `error`. Seul `booked` confirme une écriture Google. Si la disponibilité d’un agenda ne peut pas être vérifiée, la réservation échoue pour la séance concernée. En cas de réseau interrompu, reprendre avec les mêmes identifiants de séances. Reconfirmer le créneau si ses horaires ont changé.

Google expose la disponibilité sans contenu d’événement. KAARIS utilise le périmètre `calendar.app.created` pour créer l’agenda secondaire privé d’entraînement et les séances confirmées. Une révocation arrête les accès futurs. Les événements déjà inscrits sont gérés depuis Google Agenda. Avec une application Google externe en mode test et ces scopes, prévoir un renouvellement du consentement au bout de sept jours. [Scopes Calendar](https://developers.google.com/workspace/calendar/api/auth) · [OAuth Web](https://developers.google.com/identity/protocols/oauth2/web-server) · [Expiration des jetons Google](https://developers.google.com/identity/protocols/oauth2#expiration).

Le MCP Google Calendar officiel est en Developer Preview. Son activation demande un projet et un client OAuth déclarés pour un agent IA. Valider ces accès, les paramètres de l’outil et ses scopes avant d’intégrer son adaptateur. Le service actuel utilise Google Calendar REST avec OAuth par compte. [Documentation MCP Google Calendar](https://developers.google.com/workspace/calendar/api/guides/configure-mcp-server).

## Recette de bêta

- Lancer `npm --prefix server test` à la racine et inspecter `/healthz` sur le VPS.
- Installer la version de test iOS et se connecter avec un compte Supabase de recette confirmé. Consentir à la liaison avec un agenda de test. Observer la liste des agendas et un créneau occupé.
- Confirmer un créneau libre, relire la séance dans l’agenda secondaire, répéter la requête avec le même UUID et vérifier qu’un seul événement existe. Tester un conflit réel et la révocation.
- Tester la pause des rappels et le mode neutre sur écran verrouillé, puis relever les réponses `template` ou `model` ainsi que la latence.
- Une fois la distribution autorisée, vérifier dans TestFlight le build traité et l’installation sur un appareil réel.

Les migrations futures vont dans `supabase/migrations/`. Vérifier le journal avant activation d’un déploiement automatique GitHub, qui peut appliquer les migrations de la branche de production dès le push. [Intégration GitHub Supabase](https://supabase.com/docs/guides/deployment/branching/github-integration).

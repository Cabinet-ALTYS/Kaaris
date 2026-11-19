import { randomBytes } from "node:crypto";
import { makeCipher, sha256 } from "./crypto.mjs";
import { ApiError, upstreamJSON } from "./http.mjs";

const tokenURL = "https://oauth2.googleapis.com/token";
const revokeURL = "https://oauth2.googleapis.com/revoke";
const calendarAPI = "https://www.googleapis.com/calendar/v3";
const userInfoURL = "https://openidconnect.googleapis.com/v1/userinfo";
const scopes = [
  "openid",
  "https://www.googleapis.com/auth/calendar.calendarlist.readonly",
  "https://www.googleapis.com/auth/calendar.events.freebusy",
  "https://www.googleapis.com/auth/calendar.app.created"
];
const oauthState = /^[A-Za-z0-9_-]{43}$/;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const dateTime = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$/;
const day = 86_400_000;
const formHeaders = { "Content-Type": "application/x-www-form-urlencoded" };

function timestamp(value) {
  const ms = typeof value === "string" && dateTime.test(value) ? Date.parse(value) : NaN;
  if (!Number.isFinite(ms)) throw new ApiError(400, "invalid_time");
  return ms;
}

function timezone(value) {
  if (typeof value !== "string" || value.length > 80 || !/^[A-Za-z_+0-9/-]+$/.test(value)) {
    throw new ApiError(400, "invalid_time_zone");
  }
  try {
    new Intl.DateTimeFormat("fr-FR", { timeZone: value });
    return value;
  } catch {
    throw new ApiError(400, "invalid_time_zone");
  }
}

function requestedCalendars(ids) {
  if (!Array.isArray(ids) || ids.length < 1 || ids.length > 10 ||
      ids.some((id) => typeof id !== "string" || id.length < 1 || id.length > 255)) {
    throw new ApiError(400, "invalid_calendars");
  }
  return [...new Set(ids)];
}

function requestedSessions(sessions) {
  if (!Array.isArray(sessions) || sessions.length < 1 || sessions.length > 12) {
    throw new ApiError(400, "invalid_sessions");
  }

  const now = Date.now();
  const normalized = sessions.map((session) => {
    if (typeof session?.id !== "string" || !uuid.test(session.id) ||
        typeof session.title !== "string" || /[\u0000-\u001f\u007f]/.test(session.title)) {
      throw new ApiError(400, "invalid_session");
    }

    const title = session.title.trim();
    const start = timestamp(session.startsAt);
    const end = timestamp(session.endsAt);
    const duration = end - start;
    if (!title || [...title].length > 100 || duration < 900_000 || duration > 10_800_000 ||
        start < now - 300_000 || end > now + 90 * day) {
      throw new ApiError(400, "invalid_session");
    }
    return {
      id: session.id,
      title,
      start,
      end,
      startsAt: new Date(start).toISOString(),
      endsAt: new Date(end).toISOString()
    };
  });

  if (new Set(normalized.map((entry) => entry.id.toLowerCase())).size !== normalized.length) {
    throw new ApiError(400, "duplicate_session");
  }

  return normalized;
}

export function createGoogle(config, store, fetcher = fetch) {
  const cipher = makeCipher(config.encryptionKey);
  const writes = new Set();

  async function exclusive(userId, operation) {
    if (writes.has(userId)) throw new ApiError(409, "operation_in_progress");
    writes.add(userId);
    try {
      return await operation();
    } finally {
      writes.delete(userId);
    }
  }

  const stateContext = (row) => `state:${row.user_id}:${row.state_hash}`;
  const tokenContext = (row) => `refresh:${row.user_id}:${row.google_subject}`;

  async function token(params) {
    const response = await upstreamJSON(fetcher, tokenURL, {
      method: "POST",
      headers: formHeaders,
      body: new URLSearchParams({
        client_id: config.clientID,
        client_secret: config.clientSecret,
        ...params
      })
    }, "google_unavailable");
    if (response.body?.error === "invalid_grant") {
      throw new ApiError(409, "google_reconnect_required");
    }
    if (!response.ok || typeof response.body?.access_token !== "string") {
      throw new ApiError(502, "google_unavailable");
    }
    return response.body;
  }

  async function authorized(userId) {
    const connection = await store.getConnection(userId);
    if (!connection) throw new ApiError(409, "google_connection_required");
    const grant = await token({
      grant_type: "refresh_token",
      refresh_token: cipher.open(connection.refresh_token_encrypted, tokenContext(connection))
    });
    return { connection, accessToken: grant.access_token };
  }

  async function calendar(accessToken, path, method = "GET", data, timeout = 10_000) {
    return upstreamJSON(fetcher, `${calendarAPI}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json"
      },
      body: data === undefined ? undefined : JSON.stringify(data)
    }, "google_unavailable", timeout);
  }

  async function calendars(accessToken) {
    let pageToken;
    const entries = [];
    for (let page = 0; page < 5; page += 1) {
      const query = new URLSearchParams({
        maxResults: "250",
        showHidden: "true",
        ...(pageToken ? { pageToken } : {})
      });
      const response = await calendar(accessToken, `/users/me/calendarList?${query}`);
      if (!response.ok) throw new ApiError(502, "google_unavailable");
      entries.push(...(response.body?.items ?? []));
      pageToken = response.body?.nextPageToken;
      if (!pageToken) return entries;
    }
    throw new ApiError(502, "google_calendar_limit");
  }

  function selectedCalendars(ids, entries) {
    const available = new Set(entries.map((entry) => entry.id));
    const primary = entries.find((entry) => entry.primary)?.id;
    const selected = [...new Set(ids.map((id) => id === "primary" ? primary : id))];
    if (selected.some((id) => !available.has(id))) throw new ApiError(400, "unknown_calendar");
    return selected;
  }

  async function busy(accessToken, calendarIds, timeMin, timeMax, timeZone) {
    const answer = await calendar(accessToken, "/freeBusy", "POST", {
      timeMin: new Date(timeMin).toISOString(),
      timeMax: new Date(timeMax).toISOString(),
      timeZone,
      items: calendarIds.map((id) => ({ id }))
    });
    if (!answer.ok) throw new ApiError(502, "google_unavailable");
    const intervals = [];
    const unavailableCalendarIds = [];
    for (const id of calendarIds) {
      const result = Object.hasOwn(answer.body?.calendars ?? {}, id) ? answer.body.calendars[id] : null;
      if (!Array.isArray(result?.busy) || result.errors?.length) {
        unavailableCalendarIds.push(id);
        continue;
      }
      intervals.push(...result.busy.map(({ start, end }) => ({ start, end })));
    }
    const unique = new Map(intervals.map((entry) => [`${entry.start}|${entry.end}`, entry]));
    return {
      busy: [...unique.values()].sort((a, b) => Date.parse(a.start) - Date.parse(b.start)),
      unavailableCalendarIds
    };
  }

  async function dedicatedCalendar(connection, accessToken, timeZone, entries) {
    if (connection.calendar_id) return connection.calendar_id;

    const description = `Séances planifiées dans KAARIS. [kaaris-${sha256(
      `${connection.user_id}:${connection.google_subject}`
    ).slice(0, 32)}]`;
    const existing = entries.find((entry) => entry.description === description && entry.accessRole === "owner");
    const response = existing ? { ok: true, body: existing } : await calendar(
      accessToken, "/calendars", "POST", { summary: "KAARIS · Entraînements", description, timeZone }
    );

    if (!response.ok || typeof response.body?.id !== "string") throw new ApiError(502, "calendar_unavailable");
    await store.updateConnection(connection.user_id, { calendar_id: response.body.id });
    return response.body.id;
  }

  return {
    async connected(userId) {
      return Boolean(await store.getConnection(userId));
    },
    async authorize(userId) {
      return exclusive(userId, async () => {
        const state = randomBytes(32).toString("base64url");
        const verifier = randomBytes(48).toString("base64url");
        const row = {
          state_hash: sha256(state),
          user_id: userId,
          expires_at: new Date(Date.now() + 10 * 60_000).toISOString()
        };
        row.verifier_encrypted = cipher.seal(verifier, stateContext(row));
        await store.setState(row);
        const consentURL = new URL("https://accounts.google.com/o/oauth2/v2/auth");
        consentURL.search = new URLSearchParams({
          client_id: config.clientID,
          redirect_uri: config.redirectURI,
          response_type: "code",
          access_type: "offline",
          prompt: "consent select_account",
          scope: scopes.join(" "),
          state,
          code_challenge: sha256(verifier, "base64url"),
          code_challenge_method: "S256"
        }).toString();
        return consentURL.href;
      });
    },
    async callback(params) {
      const state = params.get("state") ?? "";
      if (!oauthState.test(state)) throw new ApiError(400, "invalid_oauth_state");
      const record = await store.useState(sha256(state));
      if (!record) throw new ApiError(400, "invalid_oauth_state");

      return exclusive(record.user_id, async () => {
        const code = params.get("code");
        if (!code || params.has("error")) throw new ApiError(400, "oauth_cancelled");
        const response = await token({
          code,
          code_verifier: cipher.open(record.verifier_encrypted, stateContext(record)),
          redirect_uri: config.redirectURI,
          grant_type: "authorization_code"
        });
        const granted = new Set(String(response.scope ?? "").split(" "));
        if (scopes.slice(1).some((scope) => !granted.has(scope))) {
          throw new ApiError(400, "oauth_scope_missing");
        }
        if (typeof response.refresh_token !== "string") {
          throw new ApiError(400, "oauth_offline_access_required");
        }

        const user = await upstreamJSON(fetcher, userInfoURL, {
          headers: { Authorization: `Bearer ${response.access_token}` }
        }, "google_unavailable");
        if (!user.ok || typeof user.body?.sub !== "string") throw new ApiError(502, "google_unavailable");

        const existing = await store.getConnection(record.user_id);
        if (existing && existing.google_subject !== user.body.sub) {
          throw new ApiError(409, "disconnect_previous_google_account");
        }
        const connection = {
          user_id: record.user_id,
          google_subject: user.body.sub,
          calendar_id: existing?.calendar_id ?? null,
          updated_at: new Date().toISOString()
        };
        connection.refresh_token_encrypted = cipher.seal(response.refresh_token, tokenContext(connection));
        await store.putConnection(connection);
      });
    },
    async disconnect(userId) {
      return exclusive(userId, async () => {
        await store.clearState(userId);
        const connection = await store.getConnection(userId);
        if (!connection) return;

        const refreshToken = cipher.open(connection.refresh_token_encrypted, tokenContext(connection));
        const response = await fetcher(revokeURL, {
          method: "POST",
          headers: formHeaders,
          redirect: "error",
          signal: AbortSignal.timeout(10_000),
          body: new URLSearchParams({ token: refreshToken })
        }).catch(() => { throw new ApiError(502, "google_unavailable"); });
        if (!response.ok && response.status !== 400) throw new ApiError(502, "google_unavailable");
        await store.deleteConnection(userId);
      });
    },
    async list(userId) {
      const { connection, accessToken } = await authorized(userId);
      const entries = await calendars(accessToken);
      return entries.filter((entry) => !entry.hidden && entry.id !== connection.calendar_id).map((entry) => ({
        id: entry.id,
        title: entry.summaryOverride ?? entry.summary ?? "Agenda",
        primary: entry.primary === true
      }));
    },
    async freebusy(userId, body) {
      const ids = requestedCalendars(body.calendarIds);
      const min = timestamp(body.timeMin);
      const max = timestamp(body.timeMax);
      const zone = timezone(body.timeZone ?? "UTC");
      if (max <= min || max - min > 31 * day) throw new ApiError(400, "invalid_date_range");
      const { accessToken } = await authorized(userId);
      const selected = selectedCalendars(ids, await calendars(accessToken));
      return busy(accessToken, selected, min, max, zone);
    },
    async book(userId, body) {
      const sessions = requestedSessions(body.sessions);
      const ids = requestedCalendars(body.calendarIds);
      const zone = timezone(body.timeZone ?? "UTC");

      return exclusive(userId, async () => {
        const { connection, accessToken } = await authorized(userId);
        const entries = await calendars(accessToken);
        const selected = selectedCalendars(ids, entries);
        let targetID = connection.calendar_id;
        const eventPath = (eventID) =>
          `/calendars/${encodeURIComponent(targetID)}/events${eventID ? `/${eventID}` : ""}`;

        const results = [];
        for (const session of sessions) {
          const eventID = sha256(`kaaris:${session.id.toLowerCase()}`);
          const id = session.id;
          const matches = (event) => event?.status !== "cancelled" &&
            Date.parse(event?.start?.dateTime) === session.start &&
            Date.parse(event?.end?.dateTime) === session.end &&
            event?.summary === session.title &&
            event?.extendedProperties?.private?.kaarisSession === id.toLowerCase();

          try {
            if (targetID) {
              const prior = await calendar(accessToken, eventPath(eventID));
              if (prior.ok) {
                results.push(matches(prior.body)
                  ? { id, status: "booked", eventId: eventID }
                  : { id, status: "error", code: "event_changed" });
                continue;
              }
              if (prior.status !== 404) {
                results.push({ id, status: "error", code: "google_unavailable" });
                continue;
              }
            }

            const checkedCalendars = targetID ? [...new Set([...selected, targetID])] : selected;
            const availability = await busy(accessToken, checkedCalendars, session.start, session.end, zone);
            if (availability.unavailableCalendarIds.length) {
              results.push({ id, status: "error", code: "availability_unavailable" });
              continue;
            }
            if (availability.busy.some((entry) =>
              Date.parse(entry.start) < session.end && Date.parse(entry.end) > session.start
            )) {
              results.push({ id, status: "conflict" });
              continue;
            }

            targetID ??= await dedicatedCalendar(connection, accessToken, zone, entries);
            const added = await calendar(accessToken, eventPath(), "POST", {
              id: eventID,
              summary: session.title,
              start: { dateTime: session.startsAt, timeZone: zone },
              end: { dateTime: session.endsAt, timeZone: zone },
              visibility: "private",
              reminders: { useDefault: false },
              extendedProperties: { private: { kaarisSession: id.toLowerCase() } }
            });
            const found = added.status === 409 ? await calendar(accessToken, eventPath(eventID)) : added;
            results.push(found.ok && matches(found.body)
              ? { id, status: "booked", eventId: eventID }
              : { id, status: "error", code: "event_unconfirmed" });
          } catch (error) {
            results.push({ id, status: "error", code: error instanceof ApiError ? error.code : "event_unconfirmed" });
          }
        }
        return results;
      });
    }
  };
}

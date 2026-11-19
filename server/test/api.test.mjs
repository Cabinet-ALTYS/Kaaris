import { once } from "node:events";
import assert from "node:assert/strict";
import { test } from "node:test";
import { createApp } from "../src/app.mjs";
import { sha256 } from "../src/crypto.mjs";

const user = "2edbbcb8-cae0-4875-83cd-04e3e69b09a6";
const otherUser = "5bc9dda8-e926-4e6f-bb24-077abb07909d";
const primary = "primary-calendar";
const dedicated = "private-gym-calendar";

async function fixture(context, options = {}) {
  const database = {
    kaaris_google_states: new Map(),
    kaaris_google_connections: new Map()
  };
  const entries = [{ id: primary, summary: "Personnel", primary: true }];
  const events = new Map();
  const calls = [];
  let lastToken;

  const noContent = () => new Response(null, { status: 204 });
  const json = (value, status = 200) => Response.json(value, { status });
  const app = createApp({
    supabase: {
      url: "https://supabase.test",
      publishableKey: "publishable-test",
      secretKey: "secret-test"
    },
    google: options.noGoogle ? undefined : {
      clientID: "web-test",
      clientSecret: "oauth-client-test",
      redirectURI: "https://kaaris.test/v1/google/callback",
      encryptionKey: Buffer.alloc(32, 7)
    },
    inferenceOrigin: new URL("http://inference.test")
  }, async (input, init = {}) => {
    const url = new URL(input);
    const method = init.method ?? "GET";
    calls.push(`${method} ${url.hostname}${url.pathname}`);

    if (url.hostname === "supabase.test") {
      if (url.pathname === "/auth/v1/user") {
        assert.equal(init.headers.apikey, "publishable-test");
        const auth = init.headers.Authorization;
        if (auth === "Bearer alice-test") return json({ id: user });
        if (auth === "Bearer bob-test") return json({ id: otherUser });
        if (auth === "Bearer anon-test") return json({ id: user, is_anonymous: true });
        return json({ message: "invalid token" }, 401);
      }

      assert.equal(init.headers.apikey, "secret-test");
      const table = database[url.pathname.split("/").at(-1)];
      const subject = url.searchParams.get("user_id")?.slice(3);
      const hash = url.searchParams.get("state_hash")?.slice(3);
      const expiry = url.searchParams.get("expires_at");
      if (method === "POST") {
        const data = JSON.parse(init.body);
        table.set(data.user_id, data);
        return new Response(null, { status: 201 });
      }
      if (method === "GET") return json(subject && table.has(subject) ? [table.get(subject)] : []);
      if (method === "PATCH") {
        Object.assign(table.get(subject), JSON.parse(init.body));
        return noContent();
      }
      const matched = [...table.values()].filter((row) =>
        (!subject || row.user_id === subject) &&
        (!hash || row.state_hash === hash) &&
        (!expiry || (expiry.startsWith("gt.") ? row.expires_at > expiry.slice(3) : row.expires_at <= expiry.slice(4)))
      );
      for (const row of matched) table.delete(row.user_id);
      return init.headers.Prefer === "return=representation" ? json(matched) : noContent();
    }

    if (url.hostname === "oauth2.googleapis.com") {
      if (url.pathname === "/revoke") {
        assert.equal(init.body.get("token"), "refresh-test");
        return new Response(null, { status: 200 });
      }
      lastToken = init.body;
      if (init.body.get("grant_type") === "refresh_token") {
        assert.equal(init.body.get("refresh_token"), "refresh-test");
        return json({ access_token: "access-test" });
      }
      return json({
        access_token: "access-test",
        refresh_token: "refresh-test",
        scope: options.limited ? "openid" : [
          "openid",
          "https://www.googleapis.com/auth/calendar.calendarlist.readonly",
          "https://www.googleapis.com/auth/calendar.events.freebusy",
          "https://www.googleapis.com/auth/calendar.app.created"
        ].join(" ")
      });
    }

    if (url.hostname === "openidconnect.googleapis.com") {
      return json({ sub: "google-user-test" });
    }

    if (url.hostname === "inference.test") {
      const data = JSON.parse(init.body);
      assert.ok(data.messages.every((message) => !message.content.includes(user)));
      return json({ choices: [{ message: { content: options.modelReply ?? "1" } }] });
    }

    assert.equal(url.hostname, "www.googleapis.com");
    assert.equal(init.headers.Authorization, "Bearer access-test");
    if (url.pathname.endsWith("calendarList")) return json({ items: entries });
    if (url.pathname.endsWith("freeBusy")) {
      await options.beforeAvailability?.();
      const data = JSON.parse(init.body);
      return json({
        calendars: Object.fromEntries(data.items.map(({ id }) => [
          id, id === primary && options.unavailable ? { errors: [{ reason: "forbidden" }] } : {
            busy: id === primary && options.conflict ? [{ start: data.timeMin, end: data.timeMax }] :
              id === dedicated ? [...events.values()].map(({ start, end }) =>
                ({ start: start.dateTime, end: end.dateTime })) : []
          }
        ]))
      });
    }
    if (url.pathname.endsWith("/calendars") && method === "POST") {
      const calendar = { id: dedicated, accessRole: "owner", ...JSON.parse(init.body) };
      entries.push(calendar);
      return json(calendar);
    }
    if (url.pathname.endsWith("/events") && method === "POST") {
      const event = JSON.parse(init.body);
      assert.equal(event.visibility, "private");
      assert.equal(event.attendees, undefined);
      if (events.has(event.id)) return json({}, 409);
      events.set(event.id, event);
      return json(event);
    }
    const event = events.get(url.pathname.split("/").at(-1));
    return event ? json(event) : json({}, 404);
  });

  app.listen(0, "127.0.0.1");
  await once(app, "listening");
  context.after(() => new Promise((resolve) => app.close(resolve)));
  const origin = `http://127.0.0.1:${app.address().port}`;

  function request(path, { method = "GET", body, auth = "alice-test" } = {}) {
    return fetch(origin + path, {
      method,
      redirect: "manual",
      headers: {
        ...(auth ? { Authorization: `Bearer ${auth}` } : {}),
        ...(body ? { "Content-Type": "application/json" } : {})
      },
      body: body ? JSON.stringify(body) : undefined
    });
  }

  async function authorize() {
    const response = await request("/v1/google/connect", { method: "POST" });
    assert.equal(response.status, 200);
    const authorization = new URL((await response.json()).authorizationUrl);
    const state = authorization.searchParams.get("state");
    return { authorization, state };
  }

  function callback(state, extra = "code=auth-code-test") {
    return request(`/v1/google/callback?state=${state}&${extra}`, { auth: null });
  }

  async function connect() {
    const { state } = await authorize();
    const response = await callback(state);
    assert.equal(response.headers.get("location"), "kaaris://google-connected?status=connected");
  }

  return { request, authorize, callback, connect, database, events, calls, lastToken: () => lastToken };
}

test("vérifie les sessions Supabase et distingue Google non configuré", async (t) => {
  const api = await fixture(t, { noGoogle: true });
  assert.equal((await api.request("/healthz", { auth: null })).status, 200);
  assert.equal((await api.request("/v1/google/status", { auth: null })).status, 401);
  assert.equal((await api.request("/v1/google/status", { auth: "invalid" })).status, 401);
  assert.equal((await api.request("/v1/google/status", { auth: "anon-test" })).status, 403);
  assert.deepEqual(await (await api.request("/v1/google/status")).json(), { available: false, connected: false });
  assert.equal((await api.request("/v1/google/connect", { method: "POST" })).status, 503);
});

test("OAuth PKCE chiffré, usage unique, isolation des comptes et révocation", async (t) => {
  const api = await fixture(t);
  const { authorization, state } = await api.authorize();
  assert.equal(authorization.host, "accounts.google.com");
  assert.equal(authorization.searchParams.get("code_challenge_method"), "S256");
  assert.equal(authorization.searchParams.get("access_type"), "offline");
  const stored = api.database.kaaris_google_states.get(user);
  assert.equal(stored.state_hash, sha256(state));

  const callback = await api.callback(state);
  assert.equal(callback.status, 303);
  assert.equal(callback.headers.get("location"), "kaaris://google-connected?status=connected");
  assert.equal(sha256(api.lastToken().get("code_verifier"), "base64url"), authorization.searchParams.get("code_challenge"));
  assert.ok(stored.verifier_encrypted !== api.lastToken().get("code_verifier"));
  assert.ok(!JSON.stringify(api.database.kaaris_google_connections.get(user)).includes("refresh-test"));

  const replayed = await api.callback(state);
  assert.match(replayed.headers.get("location"), /invalid_oauth_state/);
  assert.equal((await (await api.request("/v1/google/status", { auth: "bob-test" })).json()).connected, false);
  assert.deepEqual(await (await api.request("/v1/google/calendars")).json(), {
    calendars: [{ id: primary, title: "Personnel", primary: true }]
  });

  assert.equal((await api.request("/v1/google/connection", { method: "DELETE" })).status, 204);
  assert.equal((await (await api.request("/v1/google/status")).json()).connected, false);
  assert.equal(api.database.kaaris_google_connections.has(user), false);
});

test("refuse un state expiré et un consentement Google partiel", async (t) => {
  const api = await fixture(t, { limited: true });
  const first = await api.authorize();
  api.database.kaaris_google_states.get(user).expires_at = new Date(0).toISOString();
  assert.match((await api.callback(first.state)).headers.get("location"), /invalid_oauth_state/);

  const second = await api.authorize();
  assert.match((await api.callback(second.state)).headers.get("location"), /oauth_scope_missing/);
  assert.equal(api.database.kaaris_google_connections.has(user), false);
});

const bookingPayload = () => {
  const start = Date.now() + 86_400_000;
  return {
    calendarIds: ["primary"],
    timeZone: "Europe/Paris",
    sessions: [{
      id: "adc10d5d-b108-4259-ae03-5f561078f427",
      title: "Séance jambes",
      startsAt: new Date(start).toISOString(),
      endsAt: new Date(start + 3_600_000).toISOString()
    }]
  };
};

test("revérifie la disponibilité, écrit un événement privé et déduplique la relance", async (t) => {
  const api = await fixture(t);
  await api.connect();

  const payload = bookingPayload();
  const book = (body = payload) => api.request("/v1/google/sessions", { method: "POST", body });
  const first = await book();
  assert.equal(first.status, 200);
  const result = await first.json();
  assert.equal(result.sessions[0].status, "booked");
  assert.ok(/^[0-9a-f]{64}$/.test(result.sessions[0].eventId));
  assert.deepEqual(await (await book()).json(), result);
  assert.equal(api.calls.filter((call) => call.startsWith("POST") && call.endsWith("/events")).length, 1);
  assert.equal(api.events.size, 1);
  assert.deepEqual((await (await api.request("/v1/google/calendars")).json()).calendars.map(({ id }) => id), [primary]);

  const sameTime = { ...payload, sessions: [{ ...payload.sessions[0], id: otherUser }] };
  assert.equal((await (await book(sameTime)).json()).sessions[0].status, "conflict");
  const changed = { ...payload, sessions: [{ ...payload.sessions[0], title: "Nouveau titre" }] };
  assert.equal((await (await book(changed)).json()).sessions[0].code, "event_changed");
  assert.equal((await book({ ...payload, calendarIds: ["someone-else"] })).status, 400);
});

test("aucune écriture en cas de créneau occupé ou d’agenda indisponible", async (t) => {
  for (const options of [{ conflict: true }, { unavailable: true }]) {
    const api = await fixture(t, options);
    await api.connect();
    const response = await api.request("/v1/google/sessions", { method: "POST", body: bookingPayload() });
    const result = (await response.json()).sessions[0];
    assert.equal(result.status, options.conflict ? "conflict" : "error");
    assert.equal(api.events.size, 0);
    assert.ok(!api.calls.includes("POST www.googleapis.com/calendar/v3/calendars"));
  }
});

test("deux confirmations simultanées du même compte ne s’exécutent pas ensemble", async (t) => {
  const started = Promise.withResolvers();
  const release = Promise.withResolvers();
  const api = await fixture(t, { beforeAvailability: () => {
    started.resolve();
    return release.promise;
  } });
  await api.connect();
  const request = {
    method: "POST",
    body: bookingPayload()
  };

  const first = api.request("/v1/google/sessions", request);
  try {
    await started.promise;
    const second = await api.request("/v1/google/sessions", request);
    assert.equal(second.status, 409);
    assert.deepEqual(await second.json(), { error: "operation_in_progress" });
  } finally {
    release.resolve();
  }
  assert.equal((await (await first).json()).sessions[0].status, "booked");
  assert.equal(api.events.size, 1);
});

test("le modèle choisit un texte autorisé et n’obtient rien sans consentement", async (t) => {
  const api = await fixture(t);
  const body = { event: "missed", insultLevel: 4, egoLevel: 4 };
  const message = (extra) => api.request("/v1/coach/message", { method: "POST", body: { ...body, ...extra } });
  const neutral = await (await message({})).json();
  assert.equal(neutral.source, "template");
  assert.ok(!api.calls.some((call) => call.includes("inference.test")));
  const selected = await (await message({ bluntToneConsented: true })).json();
  assert.equal(selected.source, "model");
  assert.notEqual(selected.text, neutral.text);

  const invalidModel = await fixture(t, { modelReply: "Une phrase non validée." });
  assert.equal((await (await invalidModel.request("/v1/coach/message", {
    method: "POST", body: { ...body, bluntToneConsented: true }
  })).json()).source, "template");
});

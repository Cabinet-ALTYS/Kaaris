import { once } from "node:events";
import assert from "node:assert/strict";
import { test } from "node:test";
import { createApp } from "../src/app.mjs";
import { createVoice, voiceConfiguration } from "../src/voice.mjs";

const config = {
  apiKey: "synthetic-voice-provider-key",
  voiceId: "originalTestVoice11",
  modelId: "eleven_v4"
};
const payload = { phase: "workout", tone: "intense", bluntToneConsented: true };
const sample = new Uint8Array([73, 68, 51, 0, 1]);
const mp3 = () => new Response(sample, { headers: { "Content-Type": "audio/mpeg" } });

async function fixture(context, { voice = config, respond = mp3 } = {}) {
  const upstream = [];
  const app = createApp({
    supabase: {
      url: "https://auth.test",
      publishableKey: "public-auth-test",
      secretKey: "private-auth-test"
    },
    voice
  }, async (input, init) => {
    const url = new URL(input);
    if (url.origin === "https://auth.test") {
      const authorization = init.headers.Authorization;
      const accounts = { "Bearer valid-alice": "alice", "Bearer valid-bob": "bob" };
      return Object.hasOwn(accounts, authorization)
        ? Response.json({ id: accounts[authorization] })
        : Response.json({ message: "invalid" }, { status: 401 });
    }
    upstream.push({ url, init });
    return respond();
  });
  app.listen(0, "127.0.0.1");
  await once(app, "listening");
  context.after(() => new Promise((resolve) => app.close(resolve)));

  const origin = `http://127.0.0.1:${app.address().port}`;
  const request = (route, body, token = "valid-alice") => fetch(origin + route, {
    method: body ? "POST" : "GET",
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body ? { "Content-Type": "application/json" } : {})
    },
    body: body ? JSON.stringify(body) : undefined
  });
  return { request, upstream };
}

test("configuration ElevenLabs facultative et modèles TTS contrôlés", () => {
  assert.equal(voiceConfiguration({}), null);
  assert.equal(voiceConfiguration({ ELEVENLABS_API_KEY: config.apiKey }), null);
  const values = { ELEVENLABS_API_KEY: config.apiKey, ELEVENLABS_VOICE_ID: config.voiceId };
  assert.deepEqual(voiceConfiguration(values), config);
  assert.equal(voiceConfiguration({ ...values, ELEVENLABS_MODEL_ID: "eleven_v3" }).modelId, "eleven_v3");
  assert.throws(() => voiceConfiguration({ ...values, ELEVENLABS_MODEL_ID: "unauthorized_model" }));
  assert.throws(() => voiceConfiguration({ ...values, ELEVENLABS_VOICE_ID: "../../unsafe" }));
});

test("statut et audio requièrent une session, l’API fonctionne sans voix distante", async (t) => {
  const api = await fixture(t, { voice: null });
  assert.equal((await api.request("/v1/voice/status", null, null)).status, 401);
  assert.equal((await api.request("/v1/voice/check-in", payload, "invalid-token")).status, 401);
  assert.deepEqual(await (await api.request("/v1/voice/status")).json(), { available: false });
  const disabled = await api.request("/v1/voice/check-in", payload);
  assert.equal(disabled.status, 503);
  assert.deepEqual(await disabled.json(), { error: "voice_not_configured" });
  assert.equal(api.upstream.length, 0);
});

test("audio authentifié en français, phrase contrôlée et cache partagé sans données utilisateur", async (t) => {
  const api = await fixture(t);
  assert.deepEqual(await (await api.request("/v1/voice/status")).json(), { available: true });
  const unconsented = { ...payload, bluntToneConsented: false };
  const audio = await api.request("/v1/voice/check-in", unconsented);
  assert.equal(audio.status, 200);
  assert.equal(audio.headers.get("content-type"), "audio/mpeg");
  assert.equal(audio.headers.get("cache-control"), "no-store");
  assert.deepEqual(new Uint8Array(await audio.arrayBuffer()), sample);

  const second = await api.request("/v1/voice/check-in", { ...payload, tone: "neutral" }, "valid-bob");
  assert.deepEqual(new Uint8Array(await second.arrayBuffer()), sample);
  assert.equal(api.upstream.length, 1);
  const [{ url, init }] = api.upstream;
  assert.equal(url.href, "https://api.elevenlabs.io/v1/text-to-speech/originalTestVoice11?output_format=mp3_44100_128");
  assert.equal(init.headers["xi-api-key"], config.apiKey);
  assert.equal(init.headers.Authorization, undefined);
  assert.equal(init.redirect, "error");
  assert.deepEqual(JSON.parse(init.body), {
    text: "[curious] Tu as pu faire ta séance ? Si tu l’as reportée, tu peux choisir un nouveau créneau.",
    model_id: "eleven_v4",
    language_code: "fr"
  });

  const unexpected = await api.request("/v1/voice/check-in", { ...payload, text: "Donnée hors corpus" });
  assert.equal(unexpected.status, 400);
  assert.equal(api.upstream.length, 1);
});

test("la génération est mutualisée malgré des demandes simultanées et distinguée par intensité", async () => {
  const ready = Promise.withResolvers();
  const lines = [];
  const voice = createVoice(config, async (_url, options) => {
    lines.push(JSON.parse(options.body).text);
    await ready.promise;
    return mp3();
  });
  const responses = [
    voice.speak("alice", payload),
    voice.speak("bob", payload),
    voice.speak("alice", { ...payload, tone: "direct" })
  ];
  assert.equal(lines.length, 2);
  assert.notEqual(lines[0], lines[1]);
  await assert.rejects(voice.speak("alice", { ...payload, tone: "neutral" }), { code: "voice_busy" });
  ready.resolve();
  await Promise.all(responses);
  await voice.speak("bob", payload);
  assert.equal(lines.length, 2);
});

test("quota par compte sur les lectures et limite quotidienne des tentatives fournisseur", async () => {
  let now = 0;
  const voice = createVoice(config, mp3, () => now);
  for (let i = 0; i < 30; i += 1) await voice.speak("alice", payload);
  await assert.rejects(voice.speak("alice", payload), { code: "voice_quota_exceeded" });
  await voice.speak("bob", payload);
  now += 10 * 60_000;
  await voice.speak("alice", payload);

  let attempts = 0;
  const unavailable = createVoice(config, async () => {
    attempts += 1;
    return new Response('{"detail":"sensitive-provider-payload"}', {
      status: 403,
      headers: { "Content-Type": "application/json" }
    });
  }, () => now);

  for (let i = 0; i < 18; i += 1) {
    await assert.rejects(unavailable.speak("alice", payload), { message: "voice_unavailable" });
  }
  await assert.rejects(unavailable.speak("bob", payload), { code: "voice_quota_exceeded" });
  assert.equal(attempts, 18);
  now += 86_400_000;
  await assert.rejects(unavailable.speak("alice", payload), { code: "voice_unavailable" });
  assert.equal(attempts, 19);
});

test("refuse les réponses non audio et bornes de taille sans exposer la réponse du fournisseur", async (t) => {
  const invalid = await fixture(t, { respond: () => new Response("raw-secret-looking-error", { status: 500 }) });
  const response = await invalid.request("/v1/voice/check-in", payload);
  assert.equal(response.status, 502);
  assert.deepEqual(await response.json(), { error: "voice_unavailable" });

  const oversized = createVoice(config, async () => new Response(new Uint8Array(512 * 1024 + 1), {
    headers: { "Content-Type": "audio/mpeg" }
  }));
  await assert.rejects(oversized.speak("alice", payload), { code: "voice_unavailable" });
});

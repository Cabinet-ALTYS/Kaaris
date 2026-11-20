import { ApiError } from "./http.mjs";

const phrases = {
  greeting: {
    neutral: "[calm] Salut. On fait le point sur ta journée. Tu es prêt ?",
    direct: "[curious] Allez, on fait le point. Qu’est-ce que t’as fait aujourd’hui ?",
    intense: "[firm] On fait le bilan. Tu t’es fixé un objectif. Raconte-moi comment t’as bougé aujourd’hui."
  },
  workout: {
    neutral: "[curious] Tu as pu faire ta séance ? Si tu l’as reportée, tu peux choisir un nouveau créneau.",
    direct: "[firm] T’es allé à la salle ? Si t’as décalé, dis-le. On recale la séance.",
    intense: "[firm] T’avais bloqué ce créneau. T’as fait ta séance ou tu la recales ? Donne-moi une réponse claire."
  },
  nutrition: {
    neutral: "[curious] Qu’est-ce que tu as mangé aujourd’hui ? Tu peux me résumer tes repas.",
    direct: "[curious] Qu’est-ce que t’as mangé aujourd’hui ? Fais-moi le point, repas par repas.",
    intense: "[firm] Fais le point sur tes repas. Dis-moi ce que t’as mangé et ce que tu veux préparer pour demain."
  },
  closing: {
    neutral: "[calm] Merci pour ton bilan. Choisis la prochaine action que tu veux tenir.",
    direct: "[firm] Bilan fait. Choisis ton prochain créneau et prépare la suite.",
    intense: "[firm] C’est noté. Maintenant choisis ton prochain créneau. Ton engagement, c’est à toi de le tenir."
  }
};

const models = new Set(["eleven_v4", "eleven_v3"]);
const requestFields = new Set(["phase", "tone", "bluntToneConsented"]);
const maxAudioBytes = 512 * 1024;
const requestWindowMs = 10 * 60_000;
const dayMs = 24 * 60 * 60_000;

export function voiceConfiguration(environment) {
  const apiKey = environment.ELEVENLABS_API_KEY?.trim();
  const voiceId = environment.ELEVENLABS_VOICE_ID?.trim();
  const modelId = environment.ELEVENLABS_MODEL_ID?.trim() || "eleven_v4";
  if (!apiKey || !voiceId) return null;
  if (!/^[A-Za-z0-9_-]{10,64}$/.test(voiceId) || !models.has(modelId)) {
    throw new Error("Invalid ElevenLabs voice or model configuration");
  }
  return { apiKey, voiceId, modelId };
}

function voiceLine(body) {
  if (typeof body.phase !== "string" || !Object.hasOwn(phrases, body.phase) ||
      typeof body.tone !== "string" || !Object.hasOwn(phrases[body.phase], body.tone) ||
      typeof body.bluntToneConsented !== "boolean" || Object.keys(body).some((key) => !requestFields.has(key))) {
    throw new ApiError(400, "invalid_voice_request");
  }
  const tone = body.bluntToneConsented ? body.tone : "neutral";
  return { key: `${body.phase}:${tone}`, text: phrases[body.phase][tone] };
}

async function readAudio(response) {
  const mime = response.headers.get("content-type")?.split(";")[0].trim().toLowerCase();
  const length = Number(response.headers.get("content-length"));
  if (!response.ok || !response.body || !["audio/mpeg", "audio/mp3"].includes(mime) ||
      length > maxAudioBytes) {
    await response.body?.cancel();
    throw new ApiError(502, "voice_unavailable");
  }

  const reader = response.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      size += chunk.value.byteLength;
      if (size > maxAudioBytes) {
        await reader.cancel();
        throw new ApiError(502, "voice_unavailable");
      }
      chunks.push(chunk.value);
    }
  } finally {
    reader.releaseLock();
  }
  if (!size) throw new ApiError(502, "voice_unavailable");
  return Buffer.concat(chunks, size);
}

export function createVoice(config, fetcher = fetch, now = Date.now) {
  const cache = new Map();
  const pending = new Map();
  const accountRequests = new Map();
  let requestWindow;
  let generationDay;
  let generationAttempts = 0;

  function checkRequestQuota(userId) {
    const window = Math.floor(now() / requestWindowMs);
    if (window !== requestWindow) {
      accountRequests.clear();
      requestWindow = window;
    }
    const used = accountRequests.get(userId) ?? 0;
    if (used >= 30 || (used === 0 && accountRequests.size >= 2000)) {
      throw new ApiError(429, "voice_quota_exceeded");
    }
    accountRequests.set(userId, used + 1);
  }

  function checkGenerationQuota() {
    const day = Math.floor(now() / dayMs);
    if (day !== generationDay) {
      generationAttempts = 0;
      generationDay = day;
    }
    if (generationAttempts >= 18) throw new ApiError(429, "voice_quota_exceeded");
    if (pending.size >= 2) throw new ApiError(503, "voice_busy");
    generationAttempts += 1;
  }

  async function generate(text) {
    const url = new URL(`https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(config.voiceId)}`);
    url.searchParams.set("output_format", "mp3_44100_128");
    try {
      const response = await fetcher(url, {
        method: "POST",
        headers: {
          "xi-api-key": config.apiKey,
          "Content-Type": "application/json",
          Accept: "audio/mpeg"
        },
        body: JSON.stringify({ text, model_id: config.modelId, language_code: "fr" }),
        redirect: "error",
        signal: AbortSignal.timeout(7_000)
      });
      return await readAudio(response);
    } catch {
      throw new ApiError(502, "voice_unavailable");
    }
  }

  return {
    available: Boolean(config),
    async speak(userId, body) {
      if (!config) throw new ApiError(503, "voice_not_configured");
      const { key, text } = voiceLine(body);
      checkRequestQuota(userId);

      if (cache.has(key)) return cache.get(key);
      if (pending.has(key)) return pending.get(key);
      checkGenerationQuota();

      const request = generate(text).then((audio) => {
        cache.set(key, audio);
        return audio;
      }).finally(() => pending.delete(key));
      pending.set(key, request);
      return request;
    }
  };
}

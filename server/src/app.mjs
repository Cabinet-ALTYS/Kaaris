import { createServer } from "node:http";
import { ApiError, readJSON, writeJSON } from "./http.mjs";
import { createCoach } from "./coach.mjs";
import { createGoogle } from "./google.mjs";
import { createSupabase } from "./supabase.mjs";
import { createVoice } from "./voice.mjs";

export function createApp(config, fetcher = fetch) {
  const supabase = createSupabase(config.supabase, fetcher);
  const google = config.google ? createGoogle(config.google, supabase, fetcher) : null;
  const coach = createCoach(config.inferenceOrigin, fetcher);
  const voice = createVoice(config.voice, fetcher);

  async function dispatch(request, response) {
    const url = new URL(request.url, "http://kaaris.local");
    const route = `${request.method} ${url.pathname}`;
    if (route === "GET /healthz") {
      return writeJSON(response, 200, { status: "ok" });
    }
    if (route === "GET /v1/google/callback") {
      if (!google) throw new ApiError(503, "google_not_configured");
      const destination = new URL("kaaris://google-connected");
      try {
        await google.callback(url.searchParams);
        destination.searchParams.set("status", "connected");
      } catch (error) {
        destination.searchParams.set("status", "error");
        destination.searchParams.set("code", error instanceof ApiError ? error.code : "oauth_unavailable");
      }
      response.writeHead(303, { Location: destination.href });
      return response.end();
    }

    const userId = await supabase.authenticate(request.headers.authorization);
    if (route === "GET /v1/google/status") {
      return writeJSON(response, 200, {
        available: Boolean(google),
        connected: google ? await google.connected(userId) : false
      });
    }
    if (route === "POST /v1/coach/message") {
      const message = await coach(await readJSON(request));
      return writeJSON(response, 200, message);
    }
    if (route === "GET /v1/voice/status") {
      return writeJSON(response, 200, { available: voice.available });
    }
    if (route === "POST /v1/voice/check-in") {
      if (!voice.available) throw new ApiError(503, "voice_not_configured");
      const audio = await voice.speak(userId, await readJSON(request));
      response.writeHead(200, {
        "Content-Type": "audio/mpeg",
        "Content-Length": audio.length
      });
      return response.end(audio);
    }
    if (!google && url.pathname.startsWith("/v1/google/")) {
      throw new ApiError(503, "google_not_configured");
    }

    switch (route) {
      case "POST /v1/google/connect":
        return writeJSON(response, 200, { authorizationUrl: await google.authorize(userId) });
      case "DELETE /v1/google/connection":
        await google.disconnect(userId);
        response.statusCode = 204;
        return response.end();
      case "GET /v1/google/calendars":
        return writeJSON(response, 200, { calendars: await google.list(userId) });
      case "POST /v1/google/freebusy":
        return writeJSON(response, 200, await google.freebusy(userId, await readJSON(request)));
      case "POST /v1/google/sessions":
        return writeJSON(response, 200, {
          sessions: await google.book(userId, await readJSON(request))
        });
      default:
        throw new ApiError(404, "not_found");
    }
  }

  return createServer({ requestTimeout: 15_000, headersTimeout: 10_000 }, async (request, response) => {
    response.setHeader("Cache-Control", "no-store");
    response.setHeader("Referrer-Policy", "no-referrer");
    response.setHeader("X-Content-Type-Options", "nosniff");
    try {
      await dispatch(request, response);
    } catch (error) {
      if (error instanceof ApiError) {
        return writeJSON(response, error.status, { error: error.code });
      }

      console.error("unexpected_request_failure", error?.name);
      return writeJSON(response, 500, { error: "internal_error" });
    }
  });
}

export class ApiError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

export async function readJSON(request) {
  if (!/^application\/json(?:;|$)/i.test(request.headers["content-type"] ?? "")) {
    throw new ApiError(415, "json_required");
  }

  let size = 0;
  let body = "";
  request.setEncoding("utf8");
  for await (const chunk of request) {
    size += Buffer.byteLength(chunk);
    if (size > 16_384) {
      throw new ApiError(413, "body_too_large");
    }
    body += chunk;
  }

  try {
    const value = JSON.parse(body);
    if (value && typeof value === "object" && !Array.isArray(value)) return value;
  } catch {
    // La réponse reste générique et ne contient aucun fragment de l’entrée.
  }
  throw new ApiError(400, "invalid_json");
}

export async function upstreamJSON(fetcher, url, init, code, timeout = 10_000) {
  try {
    const response = await fetcher(url, {
      ...init,
      redirect: "error",
      signal: AbortSignal.timeout(timeout)
    });
    const text = await response.text();
    const body = text ? JSON.parse(text) : null;
    return { ok: response.ok, status: response.status, body };
  } catch {
    throw new ApiError(502, code);
  }
}

export function writeJSON(response, status, body) {
  response.statusCode = status;
  response.setHeader("Content-Type", "application/json; charset=utf-8");
  response.end(JSON.stringify(body));
}

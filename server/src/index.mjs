import { createApp } from "./app.mjs";

function required(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing configuration: ${name}`);
  return value;
}

function baseURL(value, name, validProtocols = ["https:"]) {
  const url = new URL(value);
  if (!validProtocols.includes(url.protocol) || url.username || url.password ||
      url.search || url.hash) throw new Error(`Invalid configuration: ${name}`);
  return url;
}

const supabase = {
  url: baseURL(required("SUPABASE_URL"), "SUPABASE_URL"),
  publishableKey: required("SUPABASE_PUBLISHABLE_KEY"),
  secretKey: required("SUPABASE_SECRET_KEY")
};

let google;
if (process.env.GOOGLE_CLIENT_ID) {
  const redirectURI = baseURL(required("GOOGLE_REDIRECT_URI"), "GOOGLE_REDIRECT_URI");
  const encryptionKey = Buffer.from(required("OAUTH_ENCRYPTION_KEY"), "base64");
  if (redirectURI.pathname !== "/v1/google/callback" || encryptionKey.length !== 32) {
    throw new Error("Invalid Google callback path or token encryption key");
  }
  google = {
    clientID: required("GOOGLE_CLIENT_ID"),
    clientSecret: required("GOOGLE_CLIENT_SECRET"),
    redirectURI: redirectURI.href,
    encryptionKey
  };
}

const inferenceOrigin = process.env.INFERENCE_ORIGIN
  ? baseURL(process.env.INFERENCE_ORIGIN, "INFERENCE_ORIGIN", ["http:", "https:"])
  : undefined;

const app = createApp({ supabase, google, inferenceOrigin });
app.listen(Number(process.env.PORT ?? 8787), process.env.HOST ?? "127.0.0.1", () => {
  console.log("KAARIS API ready");
});

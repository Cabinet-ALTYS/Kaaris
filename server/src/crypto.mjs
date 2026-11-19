import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";

export function makeCipher(key) {
  return {
    seal(value, context) {
      const iv = randomBytes(12);
      const cipher = createCipheriv("aes-256-gcm", key, iv);
      cipher.setAAD(Buffer.from(context));
      const data = Buffer.concat([cipher.update(value, "utf8"), cipher.final()]);
      return [iv, cipher.getAuthTag(), data].map((part) => part.toString("base64url")).join(".");
    },
    open(value, context) {
      const [iv, tag, data] = value.split(".").map((part) => Buffer.from(part, "base64url"));
      const decipher = createDecipheriv("aes-256-gcm", key, iv);
      decipher.setAAD(Buffer.from(context));
      decipher.setAuthTag(tag);
      return Buffer.concat([decipher.update(data), decipher.final()]).toString("utf8");
    }
  };
}

export function sha256(value, encoding = "hex") {
  return createHash("sha256").update(value).digest(encoding);
}

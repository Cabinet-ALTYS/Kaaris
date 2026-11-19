import { ApiError, upstreamJSON } from "./http.mjs";

export function createSupabase(config, fetcher = fetch) {
  const publicHeaders = { apikey: config.publishableKey };
  const serviceHeaders = {
    apikey: config.secretKey,
    "Content-Type": "application/json"
  };
  if (config.secretKey.startsWith("eyJ")) {
    serviceHeaders.Authorization = `Bearer ${config.secretKey}`;
  }

  async function authenticate(header) {
    if (typeof header !== "string" || !/^Bearer [^\s]{1,6000}$/i.test(header)) {
      throw new ApiError(401, "sign_in_required");
    }
    const response = await upstreamJSON(fetcher, new URL("/auth/v1/user", config.url), {
      headers: { ...publicHeaders, Authorization: header }
    }, "auth_unavailable");
    if ([401, 403].includes(response.status)) throw new ApiError(401, "sign_in_required");
    if (!response.ok || typeof response.body?.id !== "string") {
      throw new ApiError(502, "auth_unavailable");
    }
    if (response.body.is_anonymous === true) throw new ApiError(403, "verified_account_required");
    return response.body.id;
  }

  async function request(table, query, method = "GET", value, prefer) {
    const url = new URL(`/rest/v1/${table}`, config.url);
    url.search = new URLSearchParams(query).toString();
    const headers = prefer ? { ...serviceHeaders, Prefer: prefer } : serviceHeaders;
    const response = await upstreamJSON(fetcher, url, {
      method,
      headers,
      body: value === undefined ? undefined : JSON.stringify(value)
    }, "storage_unavailable");
    if (!response.ok) throw new ApiError(502, "storage_unavailable");
    return response.body;
  }

  const states = "kaaris_google_states";
  const connections = "kaaris_google_connections";
  const userFilter = (id) => ({ user_id: `eq.${id}` });

  return {
    authenticate,
    async setState(record) {
      await request(states, { expires_at: `lte.${new Date().toISOString()}` }, "DELETE");
      await request(states, { on_conflict: "user_id" }, "POST", record, "resolution=merge-duplicates");
    },
    async useState(hash) {
      const rows = await request(states, {
        state_hash: `eq.${hash}`,
        expires_at: `gt.${new Date().toISOString()}`
      }, "DELETE", undefined, "return=representation");
      return rows[0] ?? null;
    },
    async clearState(id) {
      await request(states, userFilter(id), "DELETE");
    },
    async getConnection(id) {
      const rows = await request(connections, { ...userFilter(id), limit: 1 });
      return rows[0] ?? null;
    },
    async putConnection(record) {
      await request(connections, { on_conflict: "user_id" }, "POST", record, "resolution=merge-duplicates");
    },
    async updateConnection(id, patch) {
      await request(connections, userFilter(id), "PATCH", { ...patch, updated_at: new Date().toISOString() });
    },
    async deleteConnection(id) {
      await request(connections, userFilter(id), "DELETE");
    }
  };
}

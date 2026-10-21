// Signed-in check of the discourse-fomio-app-locales endpoints (schema 2, plugin v0.3.0), run in the browser console of a meta.fomio.app tab
// where a member (not an admin API key) is signed in. Uses the session cookie only; prints no username, cookie or token.
// The browser always requests compression, so the ETag it receives is the one real clients see (weak when compressed).
(async () => {
  const cur = await fetch("/session/current.json", { credentials: "same-origin", headers: { Accept: "application/json" } });
  const me = cur.status === 200 ? (await cur.json()).current_user : null;
  const name = me ? me.username : null;
  const pick = (r) => ({ status: r.status, etag: r.headers.get("etag"), cache: r.headers.get("cache-control"), username_header: r.headers.get("x-discourse-username") !== null });
  const get = async (path, headers = {}) => {
    const r = await fetch(path, { credentials: "same-origin", cache: "no-store", headers: { Accept: "application/json", ...headers } });
    return { h: pick(r), body: r.status === 200 ? await r.text() : "" };
  };
  const out = { signed_in: !!me, admin: me ? me.admin : null, moderator: me ? me.moderator : null, trust_level: me ? me.trust_level : null };
  for (const doc of ["index", "en"]) {
    const first = await get(`/fomio/app-locales/2/${doc}.json`);
    const again = await get(`/fomio/app-locales/2/${doc}.json`, { "If-None-Match": first.h.etag });
    const anon = await fetch(`/fomio/app-locales/2/${doc}.json`, { credentials: "omit", cache: "no-store" }).then((r) => r.text());
    out[doc] = { first: first.h, conditional_with_returned_etag: again.h, body_equals_anonymous: first.body === anon, username_in_body: name ? first.body.includes(name) : null };
  }
  out.negatives = {};
  for (const p of ["/fomio/app-locales/2/ar.json", "/fomio/app-locales/2/xx.json", "/fomio/app-locales/1/index.json", "/fomio/app-locales/2/AR.json"]) out.negatives[p] = (await get(p)).h.status;
  return out;
})();

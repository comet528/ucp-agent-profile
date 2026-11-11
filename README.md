# ucp-agent-profile

The UCP **agent profile** for this estate: the document a merchant fetches to
establish who is asking.

- Identity (advertised in the `UCP-Agent` header): <https://agent.attainai.ai/.well-known/ucp>
- Release-pinned copies, for audit and for a client that pins: `ucp/agent/<release>.json`

Served by Cloudflare Pages, behind the custom domain `agent.attainai.ai`, with
header rules in `_headers`. **GitHub Pages cannot host this document** — measured,
not assumed: it has no per-file header control, so an extensionless
`/.well-known/ucp` is served as `application/octet-stream` with `max-age=600` and
no `public`, and Shopify's fetcher rejects both in turn with `-32001
profile_malformed` ("Invalid content type", then "Invalid cache control").
Shopify's own reference profile sends `application/json` and
`public, max-age=3600, stale-while-revalidate=7200`.

| Gate a merchant actually enforces | GitHub Pages | Cloudflare Pages with `_headers` |
|---|---|---|
| `content-type: application/json` on an extensionless path | `application/octet-stream` — refused | set by `_headers` |
| `Cache-Control` containing `public` and `max-age >= 60` | `max-age=600`, no `public` — refused | set by `_headers` |

## Why `/.well-known/ucp` and not a versioned path

The specification says two different things about where an agent profile lives:

- **Profile Structure:** "Businesses publish their profile at `/.well-known/ucp`;
  platforms publish their profile at the URI advertised in `UCP-Agent`." Under
  this reading any advertised URI is legal.
- **`rest.openapi.json`, the `UCP-Agent` parameter:** "The URL MUST point to
  `/.well-known/ucp`." Under this reading a versioned path is non-conformant.

Shopify's own reference profile sits at a non-well-known path
(`shopify.dev/ucp/agent-profiles/...`) and its merchants accept it, so enforcement
is inconsistent in practice. This estate writes conformance tooling, so it takes
the stricter clause: `/.well-known/ucp` is the identity. The consequence is
recorded rather than hidden — `/.well-known/ucp` holds exactly one release per
host, so a second release on the wire needs its own hostname, while the
release-pinned copies here exist for audit and pinning only.

## What it declares

`ucp.version` `2026-08-25`, the `mcp` service bindings with no endpoint (an agent
serves no endpoint), and eight capabilities we actually handle:

`dev.ucp.shopping.checkout`, `.fulfillment`, `.buyer_consent`, `.discount`,
`.cart`, `.order`, `.catalog.search`, `.catalog.lookup`.

Deliberately **not** declared: `dev.shopify.*` extensions (we do not implement
them), `dev.ucp.common.location.*` (we do not handle physical locations), and
`dev.ucp.common.identity_linking` (we cannot perform OAuth on a buyer's behalf).
`payment_handlers` is `{}` — honest, not a stub. Declaring a capability we cannot
process would make the document a lie about what will happen to a merchant's
payloads.

## Changing it

Edit `ucp/agent/<release>.json`, run `./publish.sh` to copy it to `.well-known/ucp`
and `latest.json`, then `./check.sh` against the live host. Every change is a
commit, which is the audit trail for an identity document.

Caching is `max-age=600` on Pages: a wrong publish lingers for about ten minutes
in a merchant's cache, so verify before pushing rather than after.

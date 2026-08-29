# Building the beancount-io images

Upstream (`bex-co/beancount-io`, MIT) publishes no container images, so all
three are built here and pushed to `git.ramoneees.com/ramoneees/`.

Currently deployed: upstream commit **b127f3a**, image tag `b127f3a-r2`.

## Patches we carry

Upstream's build is not reproducible as-shipped. Both patches must be
re-applied after every `git pull` of the upstream repo, or the build breaks —
one silently (a 12 GB image), one loudly (a crash-looping pod).

### 1. `backend-cluster/backend-v2/Dockerfile` — clean the yarn cache

```diff
-RUN yarn install
+RUN yarn install --network-timeout 600000 --network-concurrency 2 && yarn cache clean
```

`yarn cache clean` is the important half: without it, 9.3 GB of yarn's download
cache is baked into the image (12.3 GB total vs 2.6 GB with it). **Gitea's
`/data` PVC is only ~19.6 GB**, so pushing the unslimmed image fills it to 100%
and takes the registry — and git pushes — down with `no space left on device`.

The network flags are for reliability: plain `yarn install` intermittently dies
on `ETIMEDOUT` fetching optional esbuild platform binaries.

### 2. `backend-cluster/backend-v2/package.json` — fix the ai-sdk resolution

```diff
-    "@ai-sdk/provider-utils": "5.0.28"
+    "@ai-sdk/provider-utils": "5.0.33"
```

backend-v2 ships **no `yarn.lock`** (the Dockerfile globs `yarn.lock*`), so every
build resolves `^` ranges to whatever is newest on npm. As of 2026-08-29 that is
`@ai-sdk/openai@4.0.51` / `@ai-sdk/anthropic@4.0.45`, both of which require
`@ai-sdk/provider-utils@5.0.33` exactly and import
`createJsonLinesResponseHandler` from it. The upstream `resolutions` pin of
5.0.28 predates that symbol, so the container starts and immediately dies with:

```
SyntaxError: The requested module '@ai-sdk/provider-utils' does not provide
an export named 'createJsonLinesResponseHandler'
```

On upgrade, re-check what the resolved `@ai-sdk/*` packages depend on rather
than assuming 5.0.33 is still right.

### 3. `src/features/s3/service/asset-storage-service.ts` — path-style S3

```diff
     this.s3Client = new S3Client({
       region: config.region,
       endpoint: config.endpoint,
+      forcePathStyle: Boolean(config.endpoint),
```

Upstream only ever targets real AWS, so it uses virtual-hosted addressing. With
a custom endpoint that resolves `{bucket}.minio.apps.svc.cluster.local`, which
does not exist in cluster DNS. Gating on `config.endpoint` keeps real AWS on its
default behaviour.

Note the S3 config is **not optional**: `AssetStorageService` builds an
`S3Client` in its constructor during `buildServiceLayer`, so leaving the
`TEMP_ASSETS_*` / `PERM_ASSETS_*` variables unset kills the process at boot with
`Error: Region is missing`.

### 4. `src/foundation/sendgrid.ts` + `src/foundation/factory.ts` — SMTP transport

Upstream only speaks SendGrid's HTTP API. `createSignUpSession` **rethrows**
delivery failures, so without a valid `SG.` key `signUp` returns
`INTERNAL_SERVER_ERROR` and account creation is impossible — it does not
degrade to a silent no-op.

`sendgrid.ts` gains an `SmtpMailer` implementing the same two-method
`ISendGrid` interface on top of `nodemailer` (added to `package.json`), and
`factory.ts` selects it whenever `SMTP_HOST` is set:

```diff
-    sendgrid:
-      config.env === "production"
+    sendgrid: process.env.SMTP_HOST
+      ? new SmtpMailer({ host: ..., port: ... })
+      : config.env === "production"
         ? new SendGrid(sendGridOpts)
         : new ConsoleSendGrid(sendGridOpts),
```

Points at the in-cluster MailHog, so signup OTPs, password resets and email
verification all stay on-network and are readable in MailHog's web UI. Leaving
`SMTP_HOST` unset restores upstream behaviour exactly. `sendTemplate` has no
local equivalent of SendGrid's server-side templates, so it delivers the
template id and its dynamic data as readable text.

### 5. `src/shared/cookie-utils.ts` — auth cookie domain

Upstream hardcodes the shared parent domain so the cookie can span
`api.v3.beancount.io` / `dashboard.v3.beancount.io`:

```diff
-    domain: isProduction ? ".beancount.io" : undefined,
+    domain: process.env.AUTH_COOKIE_DOMAIN || undefined,
```

On any other host the browser **rejects** a cookie scoped to a domain it does
not belong to. Login succeeds and issues a JWT, the cookie is silently dropped,
and the next request is unauthenticated — the UI reports *"Your session has
expired. Please log in again."* Symptom looks like a session/expiry bug; it is
not.

Leave `AUTH_COOKIE_DOMAIN` **unset** for a single-host install: that yields a
host-only cookie, which is correct here because the dashboard and the API are
already same-origin (see patch 1 / `ingress.yaml`). Set it only if you split
them across subdomains.

## Build and push

Both cluster nodes are amd64; an Apple Silicon Mac must cross-build. OrbStack's
Rosetta makes this fast (the ledger image builds in ~40s).

```zsh
git clone --depth 1 https://github.com/bex-co/beancount-io.git /tmp/beancount-io
# ...apply the two patches above...
TAG=b127f3a-r2

docker buildx build --platform linux/amd64 -t beancount-io-ledger:$TAG --load \
  /tmp/beancount-io/backend-cluster/ledger
docker buildx build --platform linux/amd64 -t beancount-io-backend:$TAG --load \
  /tmp/beancount-io/backend-cluster/backend-v2
docker buildx build --platform linux/amd64 \
  --build-arg VITE_API_URL=https://beancount.ramoneees.com/api-gateway/ \
  --build-arg VITE_SSR_API_URL=http://beancount-io-backend.apps.svc.cluster.local:4104/api-gateway/ \
  -t beancount-io-dashboard:$TAG --load /tmp/beancount-io/dashboard
```

`VITE_API_URL` points at the **dashboard** host, not `beancount-api`. backend-v2
hardcodes its CORS allowlist to `beancount.io` with no env override, so browser
calls must be same-origin — see the comment in `ingress.yaml`.

Push with `crane`, not `docker push`: OrbStack routes daemon traffic through a
proxy with no route to the LAN registry.

```zsh
for i in backend ledger dashboard; do
  docker save beancount-io-$i:$TAG -o /tmp/$i.tar
  crane push /tmp/$i.tar git.ramoneees.com/ramoneees/beancount-io-$i:$TAG
  rm -f /tmp/$i.tar
done
```

**Check Gitea has room first** — `kubectl exec -n apps deploy/gitea -c gitea --
df -h /data`. A failed push leaves multi-GB orphans in
`/data/tmp/package-upload/` that Gitea never reaps; clear them with
`rm -f /data/tmp/package-upload/*` in that pod.

# Zuri Market API (backend)

Node.js 22 + Express REST API. The product catalogue is hardcoded in `data/products.js` (8 products in 4 categories: apparel, gear, home, tech); there is no database.

## Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/api/health` | Liveness and readiness check: `{"status":"ok"}` |
| GET | `/api/store` | Store name and product count |
| GET | `/api/products` | All products; filter with `?category=<name>` |
| GET | `/api/products/:id` | One product, or `404` |
| POST | `/api/cart/validate` | Checks stock and prices a cart. Requires the `x-api-key` header; returns `401` without it |
| GET | `/metrics` | Prometheus metrics (cluster-internal only; the Ingress does not route it) |

Example cart request:

```bash
curl -X POST http://localhost:5000/api/cart/validate \
  -H "Content-Type: application/json" -H "x-api-key: <API_SECRET_KEY>" \
  -d '{"items":[{"id":1,"quantity":2}]}'
```

## Configuration

| Variable | Default | Where it comes from in Kubernetes |
|---|---|---|
| `PORT` | `5000` | ConfigMap `backend-config` |
| `STORE_NAME` | `My Store` | ConfigMap `backend-config` |
| `API_SECRET_KEY` | none | Secret `backend-secrets`, synced from AWS Secrets Manager |
| `CORS_ORIGIN` | unset (CORS off) | Not set: in production the frontend and API share one origin through the Ingress |

For local runs, copy `.env.example` to `.env` and fill in a value for `API_SECRET_KEY`. `.env` is git-ignored.

## Run locally

```bash
npm ci
cp .env.example .env
npm run dev
```

The API listens on http://localhost:5000. `npm run dev` restarts on file changes (`node --watch`); `npm start` runs it plainly.

If you run the frontend dev server against it, set `CORS_ORIGIN=http://localhost:3000` in `.env`, or use the Vite proxy described in the frontend README.

## Lint and test

```bash
npm run lint
npm test
npm run test:coverage
```

- Lint: ESLint 10 (`eslint.config.js`).
- Tests: Node's built-in test runner. `test/api.test.js` starts the app on a random port and covers every route, including the 401, 400 and 404 branches.
- Coverage: c8 writes `coverage/lcov.info`, which SonarQube Cloud reads in CI (`sonar-project.properties`). The quality gate requires 80% coverage on new code.

## Metrics

`prom-client` exposes default Node.js process metrics plus `http_request_duration_seconds`, a histogram labelled with `method`, `route` and `status_code`. The Grafana dashboard's request rate, error rate and latency panels are all built from it.

## Container

```bash
docker build -t zuri-backend .
docker run --rm -p 5000:5000 -e API_SECRET_KEY=dev-key zuri-backend
```

The image is based on `node:22-alpine`, installs production dependencies only with lifecycle scripts disabled, copies just `server.js` and `data/`, and runs as the non-root `node` user. In Kubernetes it also runs with a read-only root filesystem and all Linux capabilities dropped.

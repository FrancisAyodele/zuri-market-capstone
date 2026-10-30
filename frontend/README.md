# Zuri Market storefront (frontend)

React 18 single-page app built with Vite 7 and served as static files by nginx. It lists products from the API, filters them by category, and keeps a cart in the browser.

## Structure

```
src/
  App.jsx              fetches the store name and products, holds page state
  hooks/useCart.js     cart state: add, remove, change quantity, totals
  components/          Navbar, Hero, FilterBar, ProductGrid, ProductCard, CartSidebar
  App.test.jsx         Vitest test
nginx.conf             nginx config used by Docker Compose
Dockerfile             two-stage build: Node builds, nginx serves
```

## Configuration

Vite reads these at **build time** and bakes them into the JavaScript bundle. Changing them means rebuilding, not restarting.

| Variable | Purpose |
|---|---|
| `VITE_API_URL` | Base URL for API calls |
| `VITE_STORE_NAME` | Fallback store name if `/api/store` cannot be reached |

- **Local development:** copy `.env.example` to `.env`, which points `VITE_API_URL` at `http://localhost:5000`. If it is unset, the app falls back to `http://localhost:5001`.
- **Docker image:** the Dockerfile defaults `VITE_API_URL` to `.`, so the app calls `./api/...` on whatever host served it. The same image works behind Docker Compose's nginx proxy and behind the Kubernetes Ingress without rebuilding.

## Run locally

Start the backend first (see [../backend/README.md](../backend/README.md)), then:

```bash
npm ci
cp .env.example .env
npm run dev
```

Open http://localhost:3000. The app calls the API at `VITE_API_URL` directly, which is a different origin, so set `CORS_ORIGIN=http://localhost:3000` in the backend's `.env`.

## Build, test, preview

```bash
npm run build
npm run preview
npm test
npm run test:coverage
```

- `build` writes static files to `dist/`.
- Tests use Vitest; `test:coverage` writes `coverage/lcov.info` for SonarQube Cloud.
- `npm run lint` is currently a placeholder.

## Container

```bash
docker build -t zuri-frontend .
docker run --rm -p 8080:8080 zuri-frontend
```

Stage 1 builds the app on `node:22-alpine`. Stage 2 serves `dist/` from `nginxinc/nginx-unprivileged:stable-alpine`, with OS packages upgraded at build time to pick up security fixes.

nginx runs as a non-root user and therefore listens on **8080**, not 80.

- **Docker Compose** uses `nginx.conf`, which also proxies `/api/` to the `backend` service.
- **Kubernetes** replaces that file with the `frontend-nginx` ConfigMap (static files only). The Ingress sends `/api` straight to the backend Service.

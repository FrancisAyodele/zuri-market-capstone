// Set a known API key BEFORE loading the app (dotenv never overrides an existing value)
process.env.API_SECRET_KEY = "test-key";

const { test, before, after } = require("node:test");
const assert = require("node:assert");
const { once } = require("node:events");
const app = require("../server");
const products = require("../data/products");

let server;
let base;

before(async () => {
  server = app.listen(0); // random free port
  await once(server, "listening");
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => server.close());

const validateCart = (body, key = "test-key") =>
  fetch(`${base}/api/cart/validate`, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...(key ? { "x-api-key": key } : {}) },
    body: JSON.stringify(body),
  });

// ---- platform endpoints ----
test("GET /api/health returns ok", async () => {
  const res = await fetch(`${base}/api/health`);
  assert.strictEqual(res.status, 200);
  assert.deepStrictEqual(await res.json(), { status: "ok" });
});

test("GET /metrics exposes the request histogram", async () => {
  await fetch(`${base}/does-not-exist`); // also records an "unmatched" route
  const res = await fetch(`${base}/metrics`);
  assert.strictEqual(res.status, 200);
  assert.match(await res.text(), /http_request_duration_seconds/);
});

test("Express version header is hidden", async () => {
  const res = await fetch(`${base}/api/health`);
  assert.strictEqual(res.headers.get("x-powered-by"), null);
});

// ---- store and products ----
test("GET /api/store returns name and product count", async () => {
  const res = await fetch(`${base}/api/store`);
  const body = await res.json();
  assert.strictEqual(res.status, 200);
  assert.ok(body.name);
  assert.strictEqual(body.totalProducts, products.length);
});

test("GET /api/products returns all products", async () => {
  const res = await fetch(`${base}/api/products`);
  assert.strictEqual(res.status, 200);
  assert.strictEqual((await res.json()).length, products.length);
});

test("GET /api/products?category= filters by category", async () => {
  const category = products[0].category;
  const res = await fetch(`${base}/api/products?category=${encodeURIComponent(category)}`);
  const body = await res.json();
  assert.ok(body.length > 0);
  assert.ok(body.every((p) => p.category === category));
});

test("GET /api/products/:id returns one product", async () => {
  const res = await fetch(`${base}/api/products/${products[0].id}`);
  assert.strictEqual(res.status, 200);
  assert.strictEqual((await res.json()).id, products[0].id);
});

test("GET /api/products/:id returns 404 for an unknown id", async () => {
  const res = await fetch(`${base}/api/products/999999`);
  assert.strictEqual(res.status, 404);
});

// ---- protected cart route ----
test("cart validate rejects a missing API key", async () => {
  const res = await validateCart({ items: [] }, null);
  assert.strictEqual(res.status, 401);
});

test("cart validate rejects a wrong API key", async () => {
  const res = await validateCart({ items: [] }, "wrong-key");
  assert.strictEqual(res.status, 401);
});

test("cart validate rejects an invalid payload", async () => {
  const res = await validateCart({ items: "not-an-array" });
  assert.strictEqual(res.status, 400);
});

test("cart validate prices valid items and flags bad ones", async () => {
  const inStock = products.find((p) => p.stock > 0);
  const res = await validateCart({
    items: [
      { id: inStock.id, quantity: 1 },
      { id: inStock.id, quantity: inStock.stock + 1 },
      { id: 999999, quantity: 1 },
    ],
  });
  const body = await res.json();

  assert.strictEqual(res.status, 200);
  assert.strictEqual(body.items[0].valid, true);
  assert.strictEqual(body.items[0].subtotal, inStock.price);
  assert.strictEqual(body.items[1].reason, "Insufficient stock");
  assert.strictEqual(body.items[2].reason, "Product not found");
  assert.strictEqual(body.total, inStock.price);
});
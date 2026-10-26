require("dotenv").config();
const express = require("express");
const cors = require("cors");
const products = require("./data/products");

const app = express();
const PORT = process.env.PORT || 5001;
const API_SECRET_KEY = process.env.API_SECRET_KEY;
const STORE_NAME = process.env.STORE_NAME || "My Store";

app.use(express.json());

app.disable('x-powered-by');          // stops Express advertising its version

// Production is same-origin through the Ingress, so CORS only matters in dev (Vite on 5173)
const allowed = process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',') : false;
app.use(cors({ origin: allowed }));   // replaces a bare cors()

const port = Number.parseInt(process.env.PORT, 10) || 5000;  // was parseInt

const validateApiKey = (req, res, next) => {
  const key = req.headers["x-api-key"];
  if (!key || key !== API_SECRET_KEY) {
    return res.status(401).json({ error: "Unauthorized: invalid or missing API key" });
  }
  next();
};

// GET /api/store — store info
app.get("/api/store", (req, res) => {
  res.json({ name: STORE_NAME, totalProducts: products.length });
});

// GET /api/products — all products (optional ?category= filter)
app.get("/api/products", (req, res) => {
  const { category } = req.query;
  const result = category
    ? products.filter((p) => p.category === category)
    : products;
  res.json(result);
});

// GET /api/products/:id — single product
app.get("/api/products/:id", (req, res) => {
  const product = products.find((p) => p.id === parseInt(req.params.id));
  if (!product) return res.status(404).json({ error: "Product not found" });
  res.json(product);
});

// POST /api/cart/validate — validate cart items (protected route)
app.post("/api/cart/validate", validateApiKey, (req, res) => {
  const { items } = req.body;

  if (!items || !Array.isArray(items)) {
    return res.status(400).json({ error: "Invalid cart payload" });
  }

  const validated = items.map((item) => {
    const product = products.find((p) => p.id === item.id);
    if (!product) return { id: item.id, valid: false, reason: "Product not found" };
    if (product.stock < item.quantity)
      return { id: item.id, valid: false, reason: "Insufficient stock" };
    return {
      id: item.id,
      valid: true,
      name: product.name,
      price: product.price,
      quantity: item.quantity,
      subtotal: product.price * item.quantity,
    };
  });

  const total = validated
    .filter((i) => i.valid)
    .reduce((sum, i) => sum + i.subtotal, 0);

  res.json({ items: validated, total });
});

if (require.main === module) {
  app.listen(port, () => console.log(`API on ${port}`));
}
module.exports = app;
const { initializeApp } = require("firebase-admin/app");
const { FieldValue, getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { logger } = require("firebase-functions");
const { setGlobalOptions } = require("firebase-functions/v2");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

initializeApp();
setGlobalOptions({ region: "southamerica-west1" });

const db = getFirestore();
const managementRoles = ["Administrador", "Gerente"];

function numberValue(value) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function money(value) {
  return `S/ ${numberValue(value).toFixed(2)}`;
}

async function dispatchNotification({
  eventId,
  type,
  title,
  body,
  productId,
  sku,
  price,
  stock,
  minStock,
}) {
  const recipients = await db
    .collection("users")
    .where("active", "==", true)
    .where("role", "in", managementRoles)
    .get();

  if (recipients.empty) return;

  const notification = {
    type,
    title,
    body,
    productId,
    sku,
    price: numberValue(price),
    stock: numberValue(stock),
    minStock: numberValue(minStock),
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  };

  const createdRecipients = [];
  for (const recipient of recipients.docs) {
    const notificationRef = recipient.ref
      .collection("notifications")
      .doc(eventId);
    const created = await db.runTransaction(async (transaction) => {
      const current = await transaction.get(notificationRef);
      if (current.exists) return false;
      transaction.create(notificationRef, notification);
      return true;
    });
    if (created) createdRecipients.push(recipient);
  }

  const deviceRefs = [];
  const deviceOwners = [];
  const fids = [];
  for (const recipient of createdRecipients) {
    const deviceSnapshot = await recipient.ref.collection("fcmDevices").get();
    for (const deviceDocument of deviceSnapshot.docs) {
      const fid = deviceDocument.data().fid;
      if (typeof fid === "string" && fid.length > 0) {
        fids.push(fid);
        deviceRefs.push(deviceDocument.ref);
        deviceOwners.push(recipient.id);
      }
    }
  }

  for (let offset = 0; offset < fids.length; offset += 500) {
    const fidBatch = fids.slice(offset, offset + 500);
    const refsBatch = deviceRefs.slice(offset, offset + 500);
    const ownersBatch = deviceOwners.slice(offset, offset + 500);
    const response = await getMessaging().sendEach(
      fidBatch.map((fid) => ({
        fid,
        notification: { title, body },
        data: {
          notificationId: eventId,
          type,
          productId,
        },
        android: {
          priority: "high",
          notification: { channelId: "product_updates" },
        },
      })),
    );

    const staleTokens = [];
    response.responses.forEach((result, index) => {
      if (result.success) return;
      const code = result.error?.code;
      if (
        code === "messaging/installation-id-not-registered"
      ) {
        staleTokens.push(refsBatch[index].delete());
      } else {
        logger.warn("No se pudo enviar una notificación push.", {
          code,
          uid: ownersBatch[index],
        });
      }
    });
    await Promise.all(staleTokens);
  }
}

exports.notifyProductRegistered = onDocumentCreated(
  "products/{productId}",
  async (event) => {
    const product = event.data?.data();
    if (!product || product.active !== true) return;

    const name = String(product.name || "Producto");
    const sku = String(product.sku || "Sin SKU");
    const stock = numberValue(product.stock);
    const minStock = numberValue(product.minStock);
    await dispatchNotification({
      eventId: event.id,
      type: "product_registered",
      title: `Producto registrado: ${name}`,
      body:
        `SKU: ${sku} · ${String(product.category || "Sin categoría")} · ` +
        `Precio de venta: ${money(product.price)} · ` +
        `Stock inicial: ${stock} · Mínimo: ${minStock}`,
      productId: event.params.productId,
      sku,
      price: product.price,
      stock,
      minStock,
    });

    if (stock <= minStock) {
      await dispatchNotification({
        eventId: `${event.id}_low_stock`,
        type: "low_stock",
        title: `Stock bajo: ${name}`,
        body: `Quedan ${stock} unidades (mínimo: ${minStock}) · SKU: ${sku}`,
        productId: event.params.productId,
        sku,
        price: product.price,
        stock,
        minStock,
      });
    }
  },
);

exports.notifyStockEntry = onDocumentCreated(
  "stockMovements/{movementId}",
  async (event) => {
    const movement = event.data?.data();
    if (
      !movement ||
      !["entry", "purchase"].includes(movement.type) ||
      movement.reason === "Stock inicial"
    ) {
      return;
    }

    const productSnapshot = await db
      .collection("products")
      .doc(String(movement.productId))
      .get();
    const product = productSnapshot.data() || {};
    const name = String(movement.productName || product.name || "Producto");
    const sku = String(movement.sku || product.sku || "Sin SKU");
    const quantity = numberValue(movement.quantity);
    const stock = numberValue(movement.afterStock);
    const minStock = numberValue(product.minStock);

    await dispatchNotification({
      eventId: event.id,
      type: "stock_entry",
      title: `Ingreso de producto: ${name}`,
      body:
        `Entraron ${quantity} unidades · Stock actual: ${stock} · SKU: ${sku}`,
      productId: String(movement.productId),
      sku,
      price: product.price,
      stock,
      minStock,
    });
  },
);

exports.notifyLowStock = onDocumentUpdated(
  "products/{productId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || after.active !== true) return;

    const previousStock = numberValue(before.stock);
    const previousMinimum = numberValue(before.minStock);
    const stock = numberValue(after.stock);
    const minStock = numberValue(after.minStock);
    if (previousStock <= previousMinimum || stock > minStock) return;

    const name = String(after.name || "Producto");
    const sku = String(after.sku || "Sin SKU");
    await dispatchNotification({
      eventId: event.id,
      type: "low_stock",
      title: `Stock bajo: ${name}`,
      body: `Quedan ${stock} unidades (mínimo: ${minStock}) · SKU: ${sku}`,
      productId: event.params.productId,
      sku,
      price: after.price,
      stock,
      minStock,
    });
  },
);

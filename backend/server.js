import express from "express";
import fetch from "node-fetch";
import { google } from "googleapis";
import fs from "fs";
import cors from "cors";
import admin from "firebase-admin";

const app = express();
app.use(cors());
app.use(express.json());

// ✅ โหลด service account
const serviceAccount = JSON.parse(fs.readFileSync("./speedwaystore-c0aa9-7499329e62dd.json", "utf8"));

// ✅ เริ่ม Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

// ✅ ตั้งค่า scope FCM
const SCOPES = ["https://www.googleapis.com/auth/firebase.messaging"];
const jwtClient = new google.auth.JWT(
  serviceAccount.client_email,
  null,
  serviceAccount.private_key.replace(/\\n/g, "\n"),
  SCOPES
);

// ✅ ฟังก์ชันส่งแจ้งเตือน
async function sendNotification(token, title, body) {
  await jwtClient.authorize();
  const accessToken = jwtClient.credentials.access_token;
  const message = {
    message: { token, notification: { title, body } },
  };

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(message),
    }
  );
  return response.json();
}

// ✅ Route: แจ้งเตือนอัตโนมัติเมื่อสั่งซื้อใหม่
app.post("/newOrder", async (req, res) => {
  const { orderId, customerName } = req.body;

  try {
    // 🔹 ดึง token ของแอดมินทั้งหมดจาก Firestore
    const adminSnap = await admin.firestore().collection("users").where("role", "==", "admin").get();

    const tokens = adminSnap.docs
      .map((doc) => doc.data().fcmToken)
      .filter((t) => !!t);

    console.log("📱 เจอ Token ของแอดมิน:", tokens);

    if (tokens.length === 0) {
      return res.json({ success: false, message: "ไม่มี token ของแอดมินใน Firestore" });
    }

    // 🔹 ส่งแจ้งเตือนให้ทุก token
    for (const token of tokens) {
      await sendNotification(
        token,
        "📦 มีคำสั่งซื้อใหม่!",
        `ลูกค้า ${customerName} ได้ทำการสั่งซื้อสินค้า (Order #${orderId})`
      );
    }

    res.json({ success: true, message: "ส่งแจ้งเตือนสำเร็จ" });
  } catch (err) {
    console.error("❌ ส่งแจ้งเตือนล้มเหลว:", err);
    res.status(500).json({ success: false, error: err.message });
  }
});

app.listen(3000, () => console.log("🚀 Backend running on port 3000"));

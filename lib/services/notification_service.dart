import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;

/// ✅ FCMService
/// ทำหน้าที่ส่ง Notification ไปยังผู้ใช้ (โดยเฉพาะ admin)
/// ผ่าน Firebase Cloud Messaging (FCM HTTP v1 API)
///
/// ใช้ Service Account (.json) เพื่อขอ Access Token จาก Google OAuth2
/// แล้วยิง POST request ไปยัง endpoint ของ FCM
class FCMService {
  static const _scope = 'https://www.googleapis.com/auth/firebase.messaging';
  static const _projectId = 'speedwaystore-c0aa9'; // 🔹 Project ID จาก Firebase Console

  /// ✅ โหลด Service Account Credentials จากไฟล์ใน assets/
  /// และสร้าง Authenticated Client สำหรับเรียก Google API
  static Future<auth.AuthClient> _getAuthClient() async {
    try {
      // โหลด JSON ของ Service Account จาก assets/
      final serviceAccountJson = await rootBundle.loadString(
        'assets/speedwaystore-c0aa9-7499329e62dd.json',
      );

      // แปลงเป็น credentials
      final credentials = auth.ServiceAccountCredentials.fromJson(
        json.decode(serviceAccountJson),
      );

      // ขอ AuthClient ที่มีสิทธิ์ Firebase Messaging (OAuth 2.0)
      return await auth.clientViaServiceAccount(credentials, [_scope]);
    } catch (e) {
      debugPrint("❌ โหลด Service Account ไม่สำเร็จ: $e");
      rethrow; // โยน error กลับให้ฟังก์ชันหลักจัดการ
    }
  }

  /// ✅ ส่งแจ้งเตือนไปยังผู้ใช้ที่เป็น "admin" ทั้งหมด
  /// โดยใช้ token จาก Firestore (field: fcmToken)
  static Future<void> sendNotification({
    required String title,
    required String body,
  }) async {
    try {
      final client = await _getAuthClient(); // 🔐 ได้ AuthClient ที่มี token แล้ว

      // 🔹 ดึงรายชื่อผู้ใช้ role=admin จาก Firestore
      final adminSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      if (adminSnapshot.docs.isEmpty) {
        debugPrint('❌ ไม่พบผู้ใช้แอดมินในระบบ');
        client.close();
        return;
      }

      // 🔹 วนส่งแจ้งเตือนให้แอดมินแต่ละคน
      for (final doc in adminSnapshot.docs) {
        final token = doc.data()['fcmToken'];
        if (token == null) continue; // ข้ามถ้าไม่มี token

        // 🔸 Endpoint ของ FCM HTTP v1
        final url = Uri.parse(
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send',
        );

        // 🔸 สร้าง payload ของข้อความแจ้งเตือน
        final message = {
          "message": {
            "token": token, // token ของอุปกรณ์เป้าหมาย
            "notification": {
              "title": title,
              "body": body,
            },
            "data": {
              // ใช้กับ onMessageOpenedApp
              "click_action": "FLUTTER_NOTIFICATION_CLICK",
              "type": "order", // ประเภทการแจ้งเตือน
            },
          }
        };

        // 🔹 ส่ง POST request ไปยัง FCM API
        final response = await client.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(message),
        );

        // ✅ ตรวจผลลัพธ์
        if (response.statusCode == 200) {
          debugPrint("✅ ส่งแจ้งเตือนสำเร็จถึง $token");
        } else {
          debugPrint(
            "❌ ส่งแจ้งเตือนล้มเหลว: ${response.statusCode} ${response.body}",
          );
        }
      }

      client.close(); // ปิด client เมื่อเสร็จงาน
    } catch (e) {
      debugPrint('❌ เกิดข้อผิดพลาดในการส่งแจ้งเตือน: $e');
    }
  }
}

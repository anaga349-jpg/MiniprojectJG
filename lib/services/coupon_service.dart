import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ✅ CouponService
/// จัดการการตรวจสอบและบันทึกการใช้คูปอง (coupon)
/// ทำงานร่วมกับ Firestore (collection: `coupons`)
/// และ Firebase Authentication (เพื่อระบุตัวผู้ใช้)
class CouponService {

  /// ✅ ตรวจสอบคูปอง (validateCoupon)
  /// - รับโค้ดจากผู้ใช้ เช่น "SAVE10"
  /// - ตรวจสอบว่าคูปองยังใช้งานได้หรือไม่
  /// - ตรวจสอบวันหมดอายุ และตรวจสอบว่าผู้ใช้นี้เคยใช้แล้วหรือยัง
  static Future<Map<String, dynamic>?> validateCoupon(String code) async {
    // 🔹 ดึง userId ของผู้ใช้ปัจจุบันจาก FirebaseAuth
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null; // ถ้ายังไม่ล็อกอิน ให้ return null

    // 🔹 ค้นหาคูปองใน Firestore ที่ตรงกับรหัส code และยังใช้งานได้ (isActive = true)
    final query = await FirebaseFirestore.instance
        .collection('coupons')
        .where('code', isEqualTo: code.toUpperCase()) // ตัวพิมพ์ใหญ่เพื่อความแน่นอน
        .where('isActive', isEqualTo: true)
        .limit(1) // จำกัดแค่ 1 เอกสาร
        .get();

    // ❌ ถ้าไม่เจอคูปองในระบบ
    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final data = doc.data();

    // 🕒 ตรวจสอบวันหมดอายุ (expiryDate)
    final expiry = (data['expiryDate'] as Timestamp).toDate();
    if (DateTime.now().isAfter(expiry)) return null; // ถ้าหมดอายุแล้ว

    // 🚫 ตรวจสอบว่าผู้ใช้นี้เคยใช้คูปองนี้หรือยัง
    final usedCheck = await FirebaseFirestore.instance
        .collection('coupons')
        .doc(doc.id)
        .collection('usedBy') // Subcollection เก็บผู้ใช้ที่เคยใช้คูปอง
        .doc(userId)
        .get();

    if (usedCheck.exists) {
      // ❌ ผู้ใช้นี้เคยใช้คูปองแล้ว
      return null;
    }

    // ✅ ผ่านทุกเงื่อนไข — คืนข้อมูลคูปองกลับไปใช้งานต่อได้
    return {...data, 'id': doc.id};
  }

  /// ✅ บันทึกว่าผู้ใช้ได้ใช้คูปองแล้ว (markCouponUsed)
  /// - เรียกหลังจากผู้ใช้ checkout สำเร็จ
  /// - เพิ่ม record ใน subcollection `usedBy`
  /// - และเพิ่มตัวนับ `usedCount` ในเอกสารคูปองหลัก
  static Future<void> markCouponUsed(String couponId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return; // ป้องกันกรณีไม่ล็อกอิน

    final couponRef =
        FirebaseFirestore.instance.collection('coupons').doc(couponId);

    // 🔹 เพิ่มข้อมูลใน subcollection usedBy/<userId>
    await couponRef.collection('usedBy').doc(userId).set({
      'usedAt': FieldValue.serverTimestamp(), // เก็บเวลาที่ใช้
    });

    // 🔹 เพิ่มตัวนับการใช้คูปอง (+1)
    await couponRef.update({
      'usedCount': FieldValue.increment(1),
    });
  }
}

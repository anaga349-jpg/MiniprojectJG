import 'dart:io';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/providers/cart_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ✅ หน้าชำระเงินแบบอัปโหลดสลิป (QR Payment)
/// - แสดง QR Code ของร้านค้า
/// - ให้ผู้ใช้เลือกสลิปจากแกลเลอรี
/// - อัปโหลดสลิปขึ้น Firebase Storage
/// - อัปเดตสถานะ Order เป็น "paid"
class QRPaymentScreen extends StatefulWidget {
  final double totalAmount;                      // ยอดเงินรวมที่ต้องชำระ
  final List<Map<String, dynamic>> cartItems;    // สินค้าในตะกร้า (ส่งมาจาก checkout)
  final String? orderId;                         // orderId ที่ถูกสร้างไว้แล้ว

  const QRPaymentScreen({
    super.key,
    required this.totalAmount,
    required this.cartItems,
    this.orderId,
  });

  @override
  State<QRPaymentScreen> createState() => _QRPaymentScreenState();
}

class _QRPaymentScreenState extends State<QRPaymentScreen> {
  File? _slipFile;          // ไฟล์สลิปที่ผู้ใช้เลือก
  bool _isUploading = false; // flag ป้องกันการกดย้ำระหว่างอัปโหลด

  // -----------------------------------------------------------
  // 📸 ฟังก์ชันเลือกไฟล์สลิปจากแกลเลอรี (ImagePicker)
  // -----------------------------------------------------------
  Future<void> _pickSlip() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      // แปลง path ที่เลือกเป็น File object
      setState(() => _slipFile = File(picked.path));
    }
  }

  // -----------------------------------------------------------
  // ☁️ ฟังก์ชันอัปโหลดสลิปขึ้น Firebase Storage และอัปเดต order ใน Firestore
  // -----------------------------------------------------------
  Future<void> _confirmPayment() async {
    // 🔸 ตรวจสอบว่ามีไฟล์สลิปหรือยัง
    if (_slipFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("กรุณาอัปโหลดสลิปก่อนยืนยันการชำระเงิน"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 🔹 ดึงข้อมูลผู้ใช้จาก FirebaseAuth
      final user = FirebaseAuth.instance.currentUser!;

      // 🔹 เตรียม path สำหรับเก็บรูปใน Firebase Storage
      // รูปจะเก็บในโฟลเดอร์ "payment_slips/" โดยใช้ userId + timestamp
      final storageRef = FirebaseStorage.instance
          .ref()
          .child("payment_slips/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg");

      // 🔹 อัปโหลดไฟล์ภาพไปยัง Storage
      await storageRef.putFile(_slipFile!);

      // 🔹 ดึง URL ของภาพที่อัปโหลด (ไว้ให้ admin ตรวจสอบ)
      final slipUrl = await storageRef.getDownloadURL();

      // -----------------------------------------------------------
      // 🔹 อัปเดตข้อมูล order เดิมใน Firestore
      // -----------------------------------------------------------
      if (widget.orderId != null) {
        await FirebaseFirestore.instance
            .collection("orders")
            .doc(widget.orderId)
            .update({
          "slipUrl": slipUrl,                      // ลิงก์รูปสลิป
          "status": "paid",                        // เปลี่ยนสถานะเป็น "paid"
          "isPaid": true,                          // ตั้ง flag เป็น true
          "updatedAt": FieldValue.serverTimestamp() // เวลาอัปเดตล่าสุด
        });
      }

      // -----------------------------------------------------------
      // 🧹 เคลียร์ตะกร้าหลังจากอัปโหลดเสร็จ
      // -----------------------------------------------------------
      if (mounted) {
        try {
          final cartProvider = Provider.of<CartProvider>(context, listen: false);
          cartProvider.clearCart();
        } catch (e) {
          debugPrint("⚠️ Clear cart failed: $e");
        }
      }

      // แจ้งเตือนผู้ใช้ว่าอัปโหลดสำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ อัปโหลดสลิปสำเร็จ! ระบบจะตรวจสอบภายใน 24 ชม."),
          backgroundColor: Colors.green,
        ),
      );

      // กลับไปหน้า Home หลังจากทำรายการเสร็จ
      Navigator.pushReplacementNamed(context, '/home');

    } catch (e) {
      // 🔸 กรณีเกิดข้อผิดพลาด เช่น upload ล้มเหลว หรือ Firestore error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เกิดข้อผิดพลาด: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // -----------------------------------------------------------
  // 🧩 ส่วน UI ของหน้าชำระเงิน
  // -----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0B3D91),
        title: const Text(
          "ชำระเงินผ่าน QR Code",
          style: TextStyle(color: Color(0xFFFFD600), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),

            // ---------------- แสดงยอดที่ต้องชำระ ----------------
            Text(
              "ยอดชำระทั้งหมด",
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 5),
            Text(
              "฿${widget.totalAmount.toStringAsFixed(2)}",
              style: const TextStyle(
                  color: Color(0xFFFFD600),
                  fontSize: 28,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // ---------------- ข้อมูลบัญชีร้านค้า ----------------
            Text(
              "บัญชีร้านค้า: Speedway Store",
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
            ),
            Text(
              "ธนาคารกรุงศรี 800-9-13632-5",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            // ---------------- QR Code ของร้านค้า ----------------
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Image.asset(
                "assets/images/QRcode.png", // ✅ รูป QR Code อยู่ใน assets
                width: 220,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 20),

            // ---------------- คำแนะนำอัปโหลดสลิป ----------------
            const Text(
              "หลังจากโอนเงินแล้ว กรุณาอัปโหลดสลิปด้านล่าง",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // ---------------- ปุ่มเลือกสลิป ----------------
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickSlip,
              icon: const Icon(Icons.upload, color: Colors.yellow),
              label: const Text(
                "เลือกสลิปจากแกลเลอรี",
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.yellow),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
            ),

            const SizedBox(height: 10),

            // ---------------- แสดงตัวอย่างสลิป ----------------
            if (_slipFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _slipFile!,
                  width: 240,
                  height: 240,
                  fit: BoxFit.cover,
                ),
              ),

            const SizedBox(height: 24),

            // ---------------- ปุ่มยืนยันการชำระเงิน ----------------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD600),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
                icon: const Icon(Icons.check_circle, color: Colors.black),

                // ถ้าอยู่ระหว่างอัปโหลด → แสดง progress indicator
                label: _isUploading
                    ? const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: CircularProgressIndicator(color: Colors.black),
                      )
                    : const Text(
                        "ยืนยันการชำระเงิน",
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                onPressed: _isUploading ? null : _confirmPayment,
              ),
            ),

            const SizedBox(height: 10),

            // ---------------- แสดงอีเมลผู้ชำระเงิน ----------------
            if (user != null)
              Text(
                "ผู้ชำระเงิน: ${user.email}",
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}

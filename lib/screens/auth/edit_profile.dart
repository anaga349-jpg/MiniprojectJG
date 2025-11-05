import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// หน้าสำหรับแก้ไขข้อมูลโปรไฟล์ผู้ใช้ (ชื่อ และอีเมล)
// ใช้ Firebase Authentication เพื่ออัปเดตข้อมูลผู้ใช้
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>(); // ใช้ตรวจสอบความถูกต้องของฟอร์ม
  final _auth = FirebaseAuth.instance; // ใช้เข้าถึงข้อมูลผู้ใช้ใน Firebase Authentication

  late TextEditingController _nameController; // ควบคุมค่าชื่อที่พิมพ์ในช่องกรอก
  late TextEditingController _emailController; // ควบคุมค่าอีเมลที่พิมพ์ในช่องกรอก
  bool _isLoading = false; // สถานะระหว่างรออัปเดตข้อมูล

  // ฟังก์ชันเริ่มต้นเมื่อเปิดหน้าครั้งแรก
  // ใช้ดึงข้อมูลชื่อและอีเมลของผู้ใช้ปัจจุบันมาแสดงในช่องกรอก
  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser; // ดึงผู้ใช้ปัจจุบัน
    _nameController = TextEditingController(text: user?.displayName ?? ""); // แสดงชื่อปัจจุบัน
    _emailController = TextEditingController(text: user?.email ?? ""); // แสดงอีเมลปัจจุบัน
  }

  // ฟังก์ชันทำความสะอาดเมื่อปิดหน้า (ป้องกัน memory leak)
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ฟังก์ชันอัปเดตข้อมูลโปรไฟล์ใน Firebase
  Future<void> _updateProfile() async {
    // ตรวจสอบว่าข้อมูลในฟอร์มถูกต้องหรือไม่
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true); // แสดงสถานะกำลังโหลด

    try {
      final user = _auth.currentUser; // ดึงข้อมูลผู้ใช้ปัจจุบัน
      if (user == null) throw FirebaseAuthException(code: 'user-not-found');

      // อัปเดตชื่อผู้ใช้ใน Firebase Authentication
      await user.updateDisplayName(_nameController.text.trim());

      // ตรวจสอบว่าอีเมลที่กรอกใหม่ต่างจากอีเมลเดิมหรือไม่
      final newEmail = _emailController.text.trim();
      if (user.email != newEmail) {
        // ถ้าเปลี่ยนอีเมล ให้ส่งอีเมลยืนยันไปยังอีเมลใหม่ก่อน
        await user.verifyBeforeUpdateEmail(newEmail);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📩 ส่งอีเมลยืนยันไปที่อีเมลใหม่แล้ว กรุณาตรวจสอบกล่องจดหมาย"),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // รีโหลดข้อมูลผู้ใช้ใหม่จาก Firebase
      await user.reload();

      // แสดงข้อความเมื่อบันทึกสำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ บันทึกข้อมูลสำเร็จ")),
      );

      Navigator.pop(context); // ปิดหน้าและกลับไปหน้าก่อนหน้า
    } on FirebaseAuthException catch (e) {
      // กรณีเกิดข้อผิดพลาดจาก Firebase เช่น อีเมลซ้ำ หรือรูปแบบผิด
      String message;
      switch (e.code) {
        case "email-already-in-use":
          message = "อีเมลนี้ถูกใช้งานแล้ว";
          break;
        case "invalid-email":
          message = "รูปแบบอีเมลไม่ถูกต้อง";
          break;
        case "requires-recent-login":
          message = "กรุณาเข้าสู่ระบบใหม่ก่อนแก้ไขอีเมล";
          break;
        default:
          message = e.message ?? "เกิดข้อผิดพลาดไม่ทราบสาเหตุ";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ $message"), backgroundColor: Colors.red),
      );
    } catch (e) {
      // จัดการข้อผิดพลาดทั่วไป เช่น การเชื่อมต่อ หรือปัญหาอื่นๆ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เกิดข้อผิดพลาด: $e")),
      );
    } finally {
      // ปิดสถานะโหลดไม่ว่าจะสำเร็จหรือเกิดข้อผิดพลาด
      setState(() => _isLoading = false);
    }
  }

  // ส่วนแสดงผล UI ของหน้า Edit Profile
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91), // กำหนดพื้นหลังสีน้ำเงินเข้ม
      appBar: AppBar(
        title: const Text("แก้ไขข้อมูล"), // ชื่อหัวข้อหน้า
        backgroundColor: const Color(0xFF1565C0), // สีของ AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16), // ระยะห่างรอบขอบหน้าจอ
        child: Form(
          key: _formKey, // ใช้ตรวจสอบฟอร์ม
          child: Column(
            children: [
              // ช่องกรอกชื่อผู้ใช้
              TextFormField(
                controller: _nameController, // ใช้ควบคุมค่าชื่อ
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: "ชื่อ", // ป้ายข้อความในช่องกรอก
                  filled: true,
                  fillColor: Colors.white, // สีพื้นหลังช่องกรอก
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? "กรุณากรอกชื่อ" : null,
              ),
              const SizedBox(height: 16),

              // ช่องกรอกอีเมล
              TextFormField(
                controller: _emailController, // ใช้ควบคุมค่าอีเมล
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: "อีเมล",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  // ตรวจสอบว่ากรอกหรือยัง และรูปแบบถูกต้องไหม
                  if (value == null || value.isEmpty) {
                    return "กรุณากรอกอีเมล";
                  }
                  if (!value.contains("@")) {
                    return "อีเมลไม่ถูกต้อง";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ปุ่มบันทึกข้อมูล
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow, // สีปุ่ม
                  minimumSize: const Size.fromHeight(50), // ความสูงปุ่ม
                ),
                onPressed: _isLoading ? null : _updateProfile, // ปิดปุ่มระหว่างโหลด
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black) // แสดงโหลด
                    : const Text(
                        "บันทึก",
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// หน้าจอ Forgot Password สำหรับให้ผู้ใช้รีเซ็ตรหัสผ่านผ่านอีเมล
// ใช้ Firebase Authentication ส่งลิงก์รีเซ็ตรหัสผ่านไปยังอีเมลของผู้ใช้
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController(); // ตัวควบคุมช่องกรอกอีเมล
  final _formKey = GlobalKey<FormState>(); // key สำหรับตรวจสอบความถูกต้องของฟอร์ม
  bool isLoading = false; // สถานะระหว่างรอการประมวลผล เช่น ระหว่างส่งอีเมล

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91), // สีพื้นหลังของหน้า
      appBar: AppBar(
        title: const Text('ลืมรหัสผ่าน'),
        backgroundColor: const Color(0xFF1565C0),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey, // ใช้ตรวจสอบข้อมูลในฟอร์ม
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // หัวข้อของหน้า
                  const Text(
                    'รีเซ็ตรหัสผ่าน',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // คำอธิบายการทำงานของหน้า
                  const Text(
                    'กรอกอีเมลของคุณ ระบบจะส่งลิงก์รีเซ็ตรหัสผ่านไปทางอีเมล',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 32),

                  // ช่องกรอกอีเมล
                  TextFormField(
                    controller: emailController, // ควบคุมค่าที่พิมพ์ในช่อง
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'อีเมล',
                      prefixIcon: const Icon(Icons.email, color: Colors.black87),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    // ตรวจสอบความถูกต้องของอีเมล
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณากรอกอีเมล';
                      }
                      if (!value.contains('@')) {
                        return 'อีเมลไม่ถูกต้อง';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // ปุ่มส่งอีเมลรีเซ็ตรหัสผ่าน
                  SizedBox(
                    width: double.infinity, // ความกว้างเต็มหน้าจอ
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD600),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.send, color: Colors.black),
                      label: isLoading
                          // แสดงวงกลมหมุนระหว่างโหลด
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          // แสดงข้อความปุ่มเมื่อไม่โหลด
                          : const Text(
                              'ส่งลิงก์รีเซ็ตรหัสผ่าน',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                              ),
                            ),
                      // ฟังก์ชันทำงานเมื่อกดปุ่ม
                      onPressed: isLoading
                          ? null // ปิดปุ่มชั่วคราวระหว่างโหลด
                          : () async {
                              if (_formKey.currentState!.validate()) {
                                // ตรวจสอบว่าฟอร์มถูกต้องหรือไม่
                                setState(() => isLoading = true);

                                try {
                                  // ส่งอีเมลรีเซ็ตรหัสผ่านผ่าน Firebase Authentication
                                  await FirebaseAuth.instance
                                      .sendPasswordResetEmail(
                                    email: emailController.text.trim(),
                                  );

                                  // เมื่อส่งสำเร็จ แสดงข้อความแจ้งเตือนและกลับไปหน้า login
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'ส่งลิงก์รีเซ็ตรหัสผ่านแล้ว กรุณาเช็คอีเมลของคุณ'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    Navigator.pop(context); // กลับไปหน้าเข้าสู่ระบบ
                                  }
                                } on FirebaseAuthException catch (e) {
                                  // กรณีเกิดข้อผิดพลาดจาก Firebase เช่น ไม่มีผู้ใช้นี้หรืออีเมลไม่ถูกต้อง
                                  String message = 'เกิดข้อผิดพลาด';
                                  if (e.code == 'user-not-found') {
                                    message = 'ไม่พบบัญชีนี้ในระบบ';
                                  } else if (e.code == 'invalid-email') {
                                    message = 'อีเมลไม่ถูกต้อง';
                                  }

                                  // แสดงข้อความ error
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(message),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                } finally {
                                  // ปิดสถานะโหลด
                                  setState(() => isLoading = false);
                                }
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ปุ่มกลับไปหน้าเข้าสู่ระบบ
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context); // กลับไปหน้าก่อนหน้า
                      },
                      child: const Text(
                        'กลับไปหน้าเข้าสู่ระบบ',
                        style: TextStyle(color: Color(0xFFFFD600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

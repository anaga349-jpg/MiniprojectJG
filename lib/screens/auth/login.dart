import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// หน้าล็อกอินสำหรับให้ผู้ใช้เข้าสู่ระบบผ่าน Firebase Authentication
// ใช้ร่วมกับ Firestore เพื่อเก็บ Token ของผู้ใช้ (FCM Token)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>(); // ใช้ตรวจสอบฟอร์มก่อนเข้าสู่ระบบ
  final emailController = TextEditingController(); // ควบคุมช่องกรอกอีเมล
  final passwordController = TextEditingController(); // ควบคุมช่องกรอกรหัสผ่าน
  bool isLoading = false; // สถานะระหว่างโหลด เช่น ตอนล็อกอิน

  // ฟังก์ชันบันทึก Token ของผู้ใช้ลงใน Firestore เพื่อใช้กับการแจ้งเตือน (FCM)
  Future<void> _saveUserToken(String uid) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken(); // ดึง Token จาก FCM
      if (fcmToken != null) {
        // บันทึก token ลงในเอกสารของผู้ใช้ใน Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'fcmToken': fcmToken}, SetOptions(merge: true));
        debugPrint('Token ถูกบันทึกเรียบร้อย: $fcmToken');
      }
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาดในการบันทึก Token: $e');
    }
  }

  // ส่วนของ UI หลัก
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91), // สีพื้นหลังน้ำเงินเข้ม
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey, // ใช้ตรวจสอบข้อมูลก่อนเข้าสู่ระบบ
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // หัวข้อหน้า
                  const Text(
                    'เข้าสู่ระบบ',
                    style: TextStyle(
                      color: Color(0xFFFFD600),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'ยินดีต้อนรับกลับสู่ Speedways Store',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ช่องกรอกอีเมล
                  TextFormField(
                    controller: emailController, // ควบคุมค่าที่กรอก
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'อีเมล',
                      prefixIcon: const Icon(Icons.email),
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
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // ช่องกรอกรหัสผ่าน
                  TextFormField(
                    controller: passwordController, // ควบคุมค่าที่กรอก
                    obscureText: true, // ซ่อนรหัสผ่าน
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'รหัสผ่าน',
                      prefixIcon: const Icon(Icons.lock),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    // ตรวจสอบความถูกต้องของรหัสผ่าน
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'รหัสผ่านอย่างน้อย 6 ตัว';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // ปุ่ม "ลืมรหัสผ่าน"
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/forgot-password');
                      },
                      child: const Text(
                        'ลืมรหัสผ่าน?',
                        style: TextStyle(color: Color(0xFFFFD600)),
                      ),
                    ),
                  ),

                  // ปุ่มเข้าสู่ระบบ
                  SizedBox(
                    width: double.infinity, // ปุ่มเต็มความกว้าง
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD600),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.login, color: Colors.black),
                      label: isLoading
                          // แสดงตัวโหลดระหว่างล็อกอิน
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          // แสดงข้อความปุ่มปกติ
                          : const Text(
                              'เข้าสู่ระบบ',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                              ),
                            ),
                      // ฟังก์ชันทำงานเมื่อกดปุ่มเข้าสู่ระบบ
                      onPressed: isLoading
                          ? null // ปิดปุ่มชั่วคราวตอนกำลังโหลด
                          : () async {
                              if (_formKey.currentState!.validate()) {
                                setState(() => isLoading = true); // เริ่มโหลด

                                try {
                                  // เข้าสู่ระบบด้วย Firebase Authentication
                                  UserCredential userCred =
                                      await FirebaseAuth.instance
                                          .signInWithEmailAndPassword(
                                    email: emailController.text.trim(),
                                    password: passwordController.text.trim(),
                                  );

                                  // เมื่อเข้าสู่ระบบสำเร็จให้บันทึก Token ของผู้ใช้
                                  await _saveUserToken(userCred.user!.uid);

                                  // เมื่อเข้าสู่ระบบสำเร็จให้เปลี่ยนหน้าไป Home
                                  if (context.mounted) {
                                    Navigator.pushReplacementNamed(
                                        context, '/home');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('เข้าสู่ระบบสำเร็จ!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } on FirebaseAuthException catch (e) {
                                  // กรณีเกิดข้อผิดพลาดจาก Firebase เช่น อีเมลผิด หรือรหัสผ่านผิด
                                  String message = 'เข้าสู่ระบบล้มเหลว';
                                  if (e.code == 'user-not-found') {
                                    message = 'ไม่พบบัญชีนี้ในระบบ';
                                  } else if (e.code == 'wrong-password') {
                                    message = 'รหัสผ่านไม่ถูกต้อง';
                                  } else if (e.code == 'invalid-email') {
                                    message = 'อีเมลไม่ถูกต้อง';
                                  }

                                  // แสดงข้อความ error
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(message),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  // ปิดสถานะโหลดไม่ว่าจะสำเร็จหรือไม่
                                  setState(() => isLoading = false);
                                }
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ลิงก์ไปหน้าสมัครสมาชิก
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'ยังไม่มีบัญชี?',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: const Text(
                          'สมัครสมาชิก',
                          style: TextStyle(color: Color(0xFFFFD600)),
                        ),
                      ),
                    ],
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

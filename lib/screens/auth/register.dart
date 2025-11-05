import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

// หน้าสมัครสมาชิกของผู้ใช้ ใช้ร่วมกับ authProvider เพื่อสมัครและบันทึกข้อมูลผู้ใช้ใหม่ในระบบ
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>(); // ใช้ตรวจสอบความถูกต้องของฟอร์ม
  final nameController = TextEditingController(); // สำหรับเก็บค่าชื่อผู้ใช้
  final emailController = TextEditingController(); // สำหรับเก็บค่าอีเมล
  final passwordController = TextEditingController(); // สำหรับเก็บค่ารหัสผ่าน
  final addressController = TextEditingController(); // สำหรับเก็บค่าที่อยู่ผู้ใช้

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider); // ดึงสถานะของ auth เช่น โหลดอยู่หรือมี error

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91), // สีพื้นหลังน้ำเงินเข้ม
      appBar: AppBar(
        title: const Text('สมัครสมาชิก'),
        backgroundColor: const Color(0xFF1565C0), // สีของ AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey, // ผูกฟอร์มกับตัวตรวจสอบ
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'สร้างบัญชีใหม่',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD600),
                  ),
                ),
                const SizedBox(height: 24),

                // ช่องกรอกชื่อผู้ใช้
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'ชื่อ',
                    prefixIcon: const Icon(Icons.person, color: Colors.black87),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'กรุณากรอกชื่อ' : null,
                ),
                const SizedBox(height: 16),

                // ช่องกรอกอีเมล
                TextFormField(
                  controller: emailController,
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
                const SizedBox(height: 16),

                // ช่องกรอกรหัสผ่าน
                TextFormField(
                  controller: passwordController,
                  obscureText: true, // ซ่อนข้อความที่พิมพ์
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'รหัสผ่าน',
                    prefixIcon: const Icon(Icons.lock, color: Colors.black87),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'รหัสผ่านอย่างน้อย 6 ตัว';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ช่องกรอกที่อยู่ผู้ใช้
                TextFormField(
                  controller: addressController,
                  maxLines: 2, // ให้พิมพ์ได้หลายบรรทัด
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'ที่อยู่',
                    prefixIcon: const Icon(Icons.home, color: Colors.black87),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'กรุณากรอกที่อยู่' : null,
                ),
                const SizedBox(height: 24),

                // ปุ่มสมัครสมาชิก
                SizedBox(
                  width: double.infinity, // ปุ่มเต็มความกว้างหน้าจอ
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD600),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.person_add, color: Colors.black),
                    label: auth.isLoading
                        // แสดงวงกลมโหลดขณะกำลังสมัครสมาชิก
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
                            'สมัครสมาชิก',
                            style: TextStyle(color: Colors.black, fontSize: 16),
                          ),
                    // เมื่อกดปุ่มสมัครสมาชิก
                    onPressed: auth.isLoading
                        ? null // ปิดปุ่มชั่วคราวระหว่างโหลด
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              // เรียกฟังก์ชัน register จาก authProvider พร้อมส่งข้อมูลผู้ใช้
                              final success = await ref
                                  .read(authProvider.notifier)
                                  .register(
                                    nameController.text.trim(),
                                    emailController.text.trim(),
                                    passwordController.text.trim(),
                                    address: addressController.text.trim(),
                                  );

                              if (!mounted) return;

                              // ถ้าสมัครสำเร็จ
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('สมัครสมาชิกสำเร็จ'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.pushReplacementNamed(
                                    context, '/login'); // ไปหน้าเข้าสู่ระบบ
                              } else {
                                // ถ้าเกิดข้อผิดพลาด
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(auth.error ?? 'เกิดข้อผิดพลาด'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ),
                const SizedBox(height: 16),

                // ลิงก์กลับไปหน้าเข้าสู่ระบบ
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'มีบัญชีแล้ว?',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: const Text(
                        'เข้าสู่ระบบ',
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
    );
  }
}

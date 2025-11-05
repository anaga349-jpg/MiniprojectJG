import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart';

// หน้าจอโปรไฟล์ของผู้ใช้ แสดงข้อมูลส่วนตัวและเมนูต่าง ๆ เช่น แก้ไขข้อมูล ประวัติการสั่งซื้อ และออกจากระบบ
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider); // ดึงสถานะการล็อกอินของผู้ใช้จาก provider
    final user = FirebaseAuth.instance.currentUser; // ดึงข้อมูลผู้ใช้ปัจจุบันจาก Firebase

    // ถ้าผู้ใช้ยังไม่ได้ล็อกอิน → ส่งกลับไปหน้า Login
    if (user == null || !authState.isAuthenticated) {
      Future.microtask(() {
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return const Scaffold(
        backgroundColor: Color(0xFF0B3D91),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD600)),
        ),
      );
    }

    // ถ้าผู้ใช้ล็อกอินแล้ว แสดงหน้าข้อมูลโปรไฟล์
    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91), // พื้นหลังสีน้ำเงินเข้ม
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0), // สีแถบด้านบน
        title: const Text(
          "โปรไฟล์ของฉัน",
          style: TextStyle(color: Color(0xFFFFD600)),
        ),
        actions: [
          // ปุ่มออกจากระบบบริเวณมุมขวาบน
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFFFD600)),
            tooltip: "ออกจากระบบ",
            onPressed: () async {
              await FirebaseAuth.instance.signOut(); // ออกจากระบบ Firebase
              ref.read(authProvider.notifier).logout(); // อัปเดตสถานะใน provider
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // ส่วนแสดงภาพโปรไฟล์ (Avatar) ใช้ตัวอักษรแรกของชื่อ
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFFFFD600),
              child: Text(
                user.displayName != null && user.displayName!.isNotEmpty
                    ? user.displayName![0].toUpperCase() // ใช้อักษรตัวแรกของชื่อ
                    : "U", // ถ้าไม่มีชื่อ ใช้อักษร U แทน
                style: const TextStyle(
                  fontSize: 40,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // แสดงชื่อผู้ใช้
            Text(
              user.displayName ?? 'ไม่ระบุชื่อ',
              style: const TextStyle(
                fontSize: 24,
                color: Color(0xFFFFD600),
                fontWeight: FontWeight.bold,
              ),
            ),

            // แสดงอีเมล
            Text(
              user.email ?? 'ไม่มีอีเมล',
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),

            const SizedBox(height: 24),
            const Divider(color: Colors.white24), // เส้นแบ่งส่วนบนกับเมนู

            // รายการเมนูของโปรไฟล์ (เช่น แก้ไขข้อมูล ประวัติการสั่งซื้อ ออกจากระบบ)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  // เมนู: แก้ไขข้อมูลส่วนตัว
                  Card(
                    color: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.edit, color: Color(0xFFFFD600)),
                      title: const Text(
                        "แก้ไขข้อมูลส่วนตัว",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          size: 16, color: Colors.white70),
                      onTap: () =>
                          Navigator.pushNamed(context, '/edit-profile'), // ไปหน้าแก้ไขข้อมูล
                    ),
                  ),
                  const SizedBox(height: 12),

                  // เมนู: ประวัติการสั่งซื้อ
                  Card(
                    color: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading:
                          const Icon(Icons.history, color: Color(0xFFFFD600)),
                      title: const Text(
                        "ประวัติการสั่งซื้อ",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          size: 16, color: Colors.white70),
                      onTap: () {
                        Navigator.pushNamed(context, '/order-history');
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // เมนู: ออกจากระบบ
                  Card(
                    color: Colors.red.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: Colors.white),
                      title: const Text(
                        "ออกจากระบบ",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      onTap: () async {
                        await FirebaseAuth.instance.signOut(); // ออกจากระบบ Firebase
                        ref.read(authProvider.notifier).logout(); // อัปเดตสถานะ provider
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/login');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

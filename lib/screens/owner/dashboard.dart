import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ใช้สำหรับเชื่อมต่อ Firebase Firestore

/// หน้าหลัก Dashboard ของผู้ดูแลระบบ (Admin)
/// แสดงเมนูการจัดการ เช่น สินค้า ออเดอร์ สต็อก รายงาน และข้อความแชทลูกค้า
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ดึงสถานะการล็อกอินจาก Riverpod (authProvider)
    final authState = ref.watch(authProvider);

    // ตรวจสอบสิทธิ์ของผู้ใช้งาน
    if (!authState.isAuthenticated || authState.role != "admin") {
      // ถ้าไม่ใช่ admin หรือยังไม่ได้ล็อกอิน ให้แสดง SnackBar และกลับหน้า Home
      Future.microtask(() {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ ไม่มีสิทธิ์เข้าถึงหน้านี้"),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      });

      // ระหว่างรอเปลี่ยนหน้า แสดงวงกลมโหลด
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ถ้าผ่านการตรวจสอบสิทธิ์แล้ว แสดงหน้า Dashboard
    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFD600),
        title: const Text(
          "Admin Dashboard",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // ปุ่มออกจากระบบ
          IconButton(
            tooltip: "ออกจากระบบ",
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () async {
              // เรียกใช้ logout จาก authProvider
              await ref.read(authProvider.notifier).logout();
              // กลับไปหน้า login
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),

      // ส่วนแสดงเนื้อหา Dashboard ในรูปแบบ Grid
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // จำนวนคอลัมน์ในแต่ละแถว
            crossAxisSpacing: 12, // ระยะห่างแนวนอน
            mainAxisSpacing: 12, // ระยะห่างแนวตั้ง
            childAspectRatio: 0.9, // อัตราส่วนความกว้าง/สูงของการ์ด
          ),
          children: [
            // การ์ดเมนู: จัดการสินค้า
            _DashboardCard(
              icon: Icons.list_alt,
              color: Colors.indigo,
              title: "จัดการสินค้า",
              subtitle: "เพิ่ม / แก้ไข / ลบสินค้า",
              onTap: () => Navigator.pushNamed(context, '/manageproducts'),
            ),

            // การ์ดเมนู: คำสั่งซื้อทั้งหมด
            _DashboardCard(
              icon: Icons.shopping_cart,
              color: Colors.green,
              title: "คำสั่งซื้อทั้งหมด",
              subtitle: "ดูรายการออเดอร์ลูกค้า",
              onTap: () => Navigator.pushNamed(context, '/orders'),
            ),

            // การ์ดเมนู: จัดการสต็อกสินค้า
            _DashboardCard(
              icon: Icons.inventory_2_outlined,
              color: Colors.deepPurple,
              title: "จัดการสต็อก",
              subtitle: "ตรวจสอบจำนวนสินค้า",
              onTap: () => Navigator.pushNamed(context, '/stock'),
            ),

            // การ์ดเมนู: รายงานยอดขาย
            _DashboardCard(
              icon: Icons.bar_chart_rounded,
              color: Colors.orange,
              title: "รายงานยอดขาย",
              subtitle: "ดูรายวัน / รายเดือน",
              onTap: () => Navigator.pushNamed(context, '/sales-report'),
            ),

            // การ์ดเมนู: แชทกับลูกค้า (ดึงจำนวนข้อความใหม่จาก Firestore)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('unreadByAdmin', isEqualTo: true) // เฉพาะแชทที่ยังไม่ได้อ่าน
                  .snapshots(), // ฟังการเปลี่ยนแปลงแบบเรียลไทม์
              builder: (context, snapshot) {
                // นับจำนวนแชทยังไม่ได้อ่าน
                final unreadCount = snapshot.data?.docs.length ?? 0;

                return _DashboardCard(
                  // สร้างไอคอนที่มี badge แสดงจำนวนข้อความ
                  iconWidget: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          color: Colors.pinkAccent, size: 30),
                      if (unreadCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: CircleAvatar(
                            radius: 9,
                            backgroundColor: Colors.red,
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  color: Colors.pinkAccent,
                  title: "แชทกับลูกค้า",
                  subtitle: unreadCount > 0
                      ? "มีข้อความใหม่ ($unreadCount)"
                      : "ตอบกลับข้อความได้ทันที",
                  onTap: () => Navigator.pushNamed(context, '/chat-admin'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// คลาสย่อยสำหรับสร้าง "การ์ด" ใน Dashboard แต่ละช่อง
class _DashboardCard extends StatelessWidget {
  final IconData? icon; // ไอคอนมาตรฐาน
  final Widget? iconWidget; // ใช้แทนไอคอน (เช่น Stack แสดง badge)
  final Color color; // สีประจำการ์ด
  final String title; // ชื่อหัวข้อ
  final String subtitle; // รายละเอียดย่อย
  final VoidCallback onTap; // ฟังก์ชันเมื่อกดการ์ด

  const _DashboardCard({
    this.icon,
    this.iconWidget,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, // เมื่อกดที่การ์ด
      borderRadius: BorderRadius.circular(12),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4, // เงา
        shadowColor: color.withOpacity(0.3), // เงาโปร่งแสงตามสีหลัก
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // วงกลมแสดงไอคอน
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withOpacity(0.15),
                child: iconWidget ??
                    Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 10),

              // ข้อความหัวข้อหลัก
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              // ข้อความคำอธิบายย่อย
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

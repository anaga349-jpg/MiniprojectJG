import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ✅ หน้าจัดการสต็อกสินค้า (Admin)
/// ใช้แสดงรายการสินค้าแบบเรียลไทม์จาก Firestore
/// และให้ผู้ดูแลสามารถเพิ่มหรือลดจำนวนสินค้าในระบบได้ทันที
class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // สร้าง instance ของ Firestore สำหรับเชื่อมต่อกับฐานข้อมูล
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFD600),
        title: const Text(
          "จัดการสต็อกสินค้า",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      // ✅ ใช้ StreamBuilder เพื่อรับข้อมูลสินค้าแบบเรียลไทม์
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('products') // ดึงข้อมูลจากคอลเลกชัน "products"
            .orderBy('name') // เรียงลำดับตามชื่อสินค้า
            .snapshots(), // ส่ง stream ข้อมูลอัปเดตตลอดเวลา
        builder: (context, snapshot) {
          // กรณีกำลังโหลดข้อมูล
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.yellow));
          }

          // กรณีไม่มีข้อมูลสินค้าในระบบ
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "ยังไม่มีสินค้าในระบบ",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          // ✅ ดึงข้อมูลสินค้าแต่ละชิ้นจาก snapshot
          final products = snapshot.data!.docs;

          // แสดงสินค้าแต่ละรายการใน ListView
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              // แปลงข้อมูลเอกสารให้เป็น Map
              final product = products[index].data() as Map<String, dynamic>;
              final productId = products[index].id; // เก็บ id ของเอกสาร
              final stock = (product["stock"] ?? 0) as int; // จำนวนสต็อก
              final lowStock = stock <= 2; // แจ้งเตือนถ้าสต็อกน้อยกว่า 3 ชิ้น

              // ✅ Card แสดงข้อมูลสินค้าแต่ละรายการ
              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

                  // วงกลมด้านซ้าย (แสดงสถานะสต็อก)
                  leading: CircleAvatar(
                    backgroundColor: lowStock
                        ? Colors.red.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                    child: Icon(
                      lowStock ? Icons.warning : Icons.inventory_2,
                      color: lowStock ? Colors.red : Colors.green,
                    ),
                  ),

                  // ชื่อสินค้า
                  title: Text(
                    product["name"] ?? "ไม่มีชื่อสินค้า",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  ),

                  // แสดงจำนวนคงเหลือ
                  subtitle: Text(
                    "คงเหลือ: $stock ชิ้น",
                    style: TextStyle(
                      color: lowStock ? Colors.redAccent : Colors.grey[800],
                    ),
                  ),

                  // ✅ ปุ่มเพิ่ม-ลดสต็อกด้านขวา
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🔻 ปุ่มลดสต็อก
                      IconButton(
                        icon: const Icon(Icons.remove_circle,
                            color: Colors.redAccent),
                        onPressed: () async {
                          // ถ้าสต็อกมากกว่า 0 ให้ลดได้
                          final newStock = stock > 0 ? stock - 1 : 0;

                          // อัปเดตข้อมูลใน Firestore (field: stock)
                          await firestore
                              .collection('products')
                              .doc(productId)
                              .update({'stock': newStock});

                          // แสดงข้อความแจ้งเตือนสั้นๆ
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  "ลดสต็อก ${product["name"]} เหลือ $newStock ชิ้น ✅"),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),

                      // 🔸 แสดงจำนวนคงเหลือตรงกลาง
                      Text(
                        "$stock",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),

                      // 🔺 ปุ่มเพิ่มสต็อก
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        onPressed: () async {
                          final newStock = stock + 1;

                          // เพิ่มค่า stock ใน Firestore
                          await firestore
                              .collection('products')
                              .doc(productId)
                              .update({'stock': newStock});

                          // แสดงข้อความแจ้งเตือน
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  "เพิ่มสต็อก ${product["name"]} เป็น $newStock ชิ้น ✅"),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

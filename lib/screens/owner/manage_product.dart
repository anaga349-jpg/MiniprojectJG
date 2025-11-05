import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import 'edit_product.dart';

/// ✅ หน้าจัดการสินค้า (Admin เท่านั้น)
/// แสดงสินค้าทั้งหมดแบบเรียลไทม์จาก Firestore (ผ่าน ProductProvider)
/// สามารถเพิ่ม, แก้ไข, และลบสินค้าได้
class ManageProductScreen extends StatelessWidget {
  const ManageProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ ดึง ProductProvider เพื่อเรียกใช้งานฟังก์ชันจัดการสินค้า
    final productProvider = context.read<ProductProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFD600),
        title: const Text(
          "จัดการสินค้า",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,

        // ปุ่ม "+" สำหรับเพิ่มสินค้าใหม่
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            tooltip: "เพิ่มสินค้าใหม่",
            onPressed: () {
              // ไปหน้า EditProductScreen โดยไม่ส่งข้อมูล (หมายถึงเพิ่มสินค้า)
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProductScreen()),
              );
            },
          ),
        ],
      ),

      // ✅ ใช้ StreamBuilder รับข้อมูลสินค้าแบบเรียลไทม์จาก Provider
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: productProvider.getProductsStream(), // ฟังข้อมูลจาก Firestore ผ่าน provider
        builder: (context, snapshot) {
          // กำลังโหลดข้อมูล
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.yellow),
            );
          }

          // ไม่มีข้อมูลสินค้าในระบบ
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "ยังไม่มีสินค้าในระบบ",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          // ✅ ดึงข้อมูลสินค้าจาก snapshot
          final products = snapshot.data!;

          // แสดงข้อมูลสินค้าแบบ Grid (2 คอลัมน์)
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // จำนวนคอลัมน์
              childAspectRatio: 0.8, // อัตราส่วนความสูง/กว้าง
              crossAxisSpacing: 12, // ระยะห่างแนวนอน
              mainAxisSpacing: 12, // ระยะห่างแนวตั้ง
            ),

            // ✅ สร้างการ์ดสินค้าแต่ละชิ้น
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 🔹 ส่วนรูปภาพสินค้า
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        child: product["image"] != null &&
                                (product["image"] as String).isNotEmpty
                            // ถ้ามีรูป แสดงจาก URL
                            ? Image.network(
                                product["image"],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image_not_supported,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              )
                            // ถ้าไม่มีรูป แสดง icon แทน
                            : const Icon(Icons.image,
                                size: 80, color: Colors.grey),
                      ),
                    ),

                    // 🔹 พื้นหลังเหลือง ชื่อสินค้า
                    Container(
                      color: const Color(0xFFFFD600),
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 6),
                      child: Text(
                        product["name"] ?? "ไม่มีชื่อสินค้า",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis, // ตัดข้อความยาวเกิน
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // 🔹 ส่วนรายละเอียดและปุ่มจัดการ
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // แสดงราคาและสต็อก
                          Text(
                            "฿${product["price"] ?? 0} | คงเหลือ ${product["stock"] ?? 0} ชิ้น",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),

                          // 🔹 ปุ่ม “แก้ไข” และ “ลบ”
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // ปุ่มแก้ไขสินค้า
                              TextButton.icon(
                                onPressed: () {
                                  // ไปหน้าแก้ไข โดยส่งข้อมูลสินค้าปัจจุบันไป
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EditProductScreen(product: product),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit,
                                    size: 16, color: Color(0xFF1565C0)),
                                label: const Text(
                                  "แก้ไข",
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFF1565C0)),
                                ),
                              ),

                              // ปุ่มลบสินค้า
                              TextButton.icon(
                                onPressed: () {
                                  _confirmDelete(
                                      context, productProvider, product);
                                },
                                icon: const Icon(Icons.delete,
                                    size: 16, color: Colors.redAccent),
                                label: const Text(
                                  "ลบ",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 🗑️ ฟังก์ชันแสดง Dialog ยืนยันการลบสินค้า
  void _confirmDelete(BuildContext context, ProductProvider provider,
      Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          "ยืนยันการลบ",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        // ✅ แสดงชื่อสินค้าที่จะถูกลบ
        content: Text(
          "คุณต้องการลบสินค้า ${product["name"]} หรือไม่?",
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          // ปุ่มยกเลิก
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ยกเลิก",
                style: TextStyle(color: Colors.black87)),
          ),

          // ปุ่มลบ
          TextButton(
            onPressed: () async {
              // ลบสินค้าโดยเรียกฟังก์ชันใน ProductProvider
              await provider.deleteProduct(product["id"]);

              Navigator.pop(ctx); // ปิด Dialog

              // แสดงข้อความแจ้งผล
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("ลบสินค้า ${product["name"]} สำเร็จ ✅"),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              "ลบ",
              style: TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

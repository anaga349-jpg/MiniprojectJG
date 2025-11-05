import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ------------------------------
// หน้าประวัติการสั่งซื้อของผู้ใช้
// ------------------------------
class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser; // ✅ ดึงข้อมูลผู้ใช้ที่ล็อกอินอยู่

    // ถ้ายังไม่ได้ล็อกอิน → แจ้งให้ล็อกอินก่อน
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B3D91),
        body: Center(
          child: Text(
            "กรุณาเข้าสู่ระบบก่อน",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    // ✅ ดึงข้อมูลคำสั่งซื้อแบบ Real-time ด้วย Stream (snapshot)
    // เฉพาะคำสั่งซื้อที่ userId ตรงกับผู้ใช้ปัจจุบัน และเรียงตามเวลาล่าสุดก่อน
    final ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        elevation: 4,
        centerTitle: true,
        title: const Text(
          "ประวัติการสั่งซื้อ",
          style: TextStyle(
            color: Color(0xFFFFD600),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ------------------------------
      // ใช้ StreamBuilder เพื่อฟังการเปลี่ยนแปลงข้อมูลแบบเรียลไทม์
      // ------------------------------
      body: StreamBuilder<QuerySnapshot>(
        stream: ordersStream,
        builder: (context, snapshot) {
          // 1️⃣ รอโหลดข้อมูล
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.yellow));
          }

          // 2️⃣ ถ้าไม่มีข้อมูลเลย
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "ยังไม่มีประวัติการสั่งซื้อ",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          // 3️⃣ มีข้อมูลคำสั่งซื้อ
          final orders = snapshot.data!.docs;

          // แสดงรายการคำสั่งซื้อทั้งหมดด้วย ListView
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index].data() as Map<String, dynamic>;

              final orderId = order['orderId'] ?? '';
              final total = order['total'] ?? 0;
              final status = order['status'] ?? 'pending';
              final createdAt = (order['createdAt'] as Timestamp?)?.toDate();

              // ✅ แปลงสถานะเป็นข้อความและกำหนดสีเพื่อ UI
              Color statusColor;
              String statusText;
              switch (status) {
                case 'pending':
                  statusColor = Colors.orangeAccent;
                  statusText = 'รอการชำระเงิน';
                  break;
                case 'shipping':
                  statusColor = Colors.blueAccent;
                  statusText = 'กำลังจัดส่ง';
                  break;
                case 'completed':
                  statusColor = Colors.greenAccent;
                  statusText = 'จัดส่งสำเร็จ';
                  break;
                case 'canceled':
                  statusColor = Colors.redAccent;
                  statusText = 'ยกเลิกแล้ว';
                  break;
                default:
                  statusColor = Colors.grey;
                  statusText = 'ไม่ทราบสถานะ';
              }

              // ✅ ใช้ AnimatedContainer เพื่อให้แต่ละรายการ transition นุ่มนวลเวลาโหลด
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                // แสดงข้อมูลคำสั่งซื้อแต่ละรายการ
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  title: Text(
                    "คำสั่งซื้อ #$orderId",
                    style: const TextStyle(
                        color: Color(0xFFFFD600),
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        "ยอดรวม: ฿${total.toStringAsFixed(2)}",
                        style: const TextStyle(color: Colors.white),
                      ),
                      // แสดงวันที่สั่งซื้อ (ถ้ามี)
                      Text(
                        createdAt != null
                            ? "วันที่: ${createdAt.day}/${createdAt.month}/${createdAt.year}"
                            : "",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      // ป้ายสถานะการสั่งซื้อ (สีขึ้นอยู่กับสถานะ)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          border: Border.all(color: statusColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      color: Colors.white70, size: 18),

                  // ➜ เมื่อแตะรายการ → ไปหน้าแสดงรายละเอียดคำสั่งซื้อ
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderDetailScreen(order: order),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ------------------------------
// หน้ารายละเอียดคำสั่งซื้อ
// ------------------------------
class OrderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> order; // ✅ รับข้อมูลคำสั่งซื้อจากหน้าก่อนหน้า
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    // ✅ แปลงข้อมูลสินค้า (ภายใน field "items") ให้เป็น List<Map>
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
    final total = order['total'] ?? 0.0;
    final payment = order['paymentMethod'] ?? '';
    final status = order['status'] ?? 'pending';

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        elevation: 4,
        centerTitle: true,
        title: const Text(
          "รายละเอียดคำสั่งซื้อ",
          style: TextStyle(
            color: Color(0xFFFFD600),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------ แสดงข้อมูลหลัก ------------------------------
            Text("สถานะ: $status",
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 6),
            Text("วิธีชำระเงิน: $payment",
                style: const TextStyle(color: Colors.white70)),
            const Divider(color: Colors.white30, height: 24),

            // ------------------------------ แสดงรายการสินค้าทั้งหมด ------------------------------
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white24, thickness: 0.5),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item['image'],
                        width: 55,
                        height: 55,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(item['name'],
                        style: const TextStyle(
                            color: Color(0xFFFFD600),
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      "฿${item['price']} x ${item['quantity']}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                },
              ),
            ),

            // ------------------------------ สรุปราคารวม ------------------------------
            const Divider(color: Colors.white30),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "รวมทั้งหมด: ฿${total.toStringAsFixed(2)}",
                style: const TextStyle(
                    color: Color(0xFFFFD600),
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// ✅ หน้ารายงานยอดขาย (Sales Dashboard)
/// ดึงข้อมูลคำสั่งซื้อจาก Firestore และคำนวณ:
/// - ยอดขายประจำวัน
/// - ยอดขายประจำเดือน
/// - สินค้าขายดีอันดับหนึ่ง
class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  double todaySales = 0; // เก็บยอดขายของวันนี้
  double monthSales = 0; // เก็บยอดขายของเดือนนี้
  String bestSeller = "-"; // เก็บชื่อสินค้าขายดี
  bool isLoading = true; // สำหรับแสดงสถานะโหลดข้อมูล

  @override
  void initState() {
    super.initState();
    _loadSalesData(); // ✅ โหลดข้อมูลทันทีเมื่อเปิดหน้าจอ
  }

  /// ✅ ดึงข้อมูลคำสั่งซื้อจาก Firestore และคำนวณสรุปยอดขาย
  Future<void> _loadSalesData() async {
    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();

    // สร้าง timestamp สำหรับช่วงเวลา
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfMonth = DateTime(now.year, now.month, 1);

    // 🔹 Query: ยอดขายของวันนี้
    final todayOrders = await firestore
        .collection('orders')
        .where('status', isEqualTo: 'completed') // เอาเฉพาะออเดอร์ที่สำเร็จแล้ว
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    // 🔹 Query: ยอดขายของเดือนนี้
    final monthOrders = await firestore
        .collection('orders')
        .where('status', isEqualTo: 'completed')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .get();

    // ตัวแปรสะสมยอดรวม
    double todayTotal = 0;
    double monthTotal = 0;

    // Map สำหรับคำนวณจำนวนสินค้าที่ขายแต่ละชิ้น
    final Map<String, double> productSales = {};

    // 🔸 รวมยอดขายวันนี้ (total)
    for (var doc in todayOrders.docs) {
      final data = doc.data();
      todayTotal += (data['total'] ?? 0).toDouble();
    }

    // 🔸 รวมยอดขายเดือนนี้ + เก็บข้อมูลสินค้าขายดี
    for (var doc in monthOrders.docs) {
      final data = doc.data();
      monthTotal += (data['total'] ?? 0).toDouble();

      // items: [ {name, quantity, price}, ... ]
      final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
      for (final item in items) {
        final name = item['name'] ?? '';
        final qty = (item['quantity'] ?? 1).toDouble();

        // รวมจำนวนสินค้าที่ขายในเดือน
        productSales[name] = (productSales[name] ?? 0) + qty;
      }
    }

    // 🔹 หาสินค้าขายดีที่สุด (max quantity)
    String bestProduct = "-";
    double maxQty = 0;
    productSales.forEach((key, qty) {
      if (qty > maxQty) {
        maxQty = qty;
        bestProduct = key;
      }
    });

    // ✅ อัปเดตค่าใน State เพื่อแสดงผล
    setState(() {
      todaySales = todayTotal;
      monthSales = monthTotal;
      bestSeller = bestProduct;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat("#,###"); // ฟอร์แมตราคาสวยงาม เช่น 12,000

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        title: const Text(
          "รายงานยอดขาย",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFD600),
        elevation: 2,
      ),

      // ✅ แสดงสถานะโหลดข้อมูล
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.yellow),
            )

          // ✅ แสดงผลรายงาน
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildReportCard(
                    title: "ยอดขายวันนี้",
                    value: "฿${numberFormat.format(todaySales)}",
                    icon: Icons.calendar_today,
                    color: Colors.blue.shade100,
                  ),
                  const SizedBox(height: 10),
                  _buildReportCard(
                    title: "ยอดขายเดือนนี้",
                    value: "฿${numberFormat.format(monthSales)}",
                    icon: Icons.bar_chart,
                    color: Colors.green.shade100,
                  ),
                  const SizedBox(height: 10),
                  _buildReportCard(
                    title: "สินค้าขายดี",
                    value: bestSeller,
                    icon: Icons.star,
                    color: Colors.orange.shade100,
                  ),
                ],
              ),
            ),
    );
  }

  /// ✅ Widget ย่อยสำหรับแสดงการ์ดรายงานแต่ละประเภท
  Widget _buildReportCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: color,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(icon, color: const Color(0xFF0B3D91)),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B3C73),
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

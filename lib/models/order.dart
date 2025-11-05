import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🧱 หน้าจอแสดง "คำสั่งซื้อทั้งหมด" (OrderScreen)
// ใช้ Firestore เป็นแหล่งข้อมูลหลักแบบ Real-time

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final firestore = FirebaseFirestore.instance; // ✅ สร้าง instance ของ Firestore
  String _searchText = ""; // เก็บข้อความค้นหา
  String _filterStatus = "ทั้งหมด"; // เก็บสถานะที่กรองอยู่ตอนนี้ (ค่าเริ่มต้นคือทั้งหมด)

  // รายการตัวเลือกสถานะที่ใช้กรอง
  final List<String> _statusFilters = [
    "ทั้งหมด",
    "pending",
    "paid",
    "delivering",
    "completed",
    "canceled",
  ];

  // ฟังก์ชันคืนค่า "สี" ตามสถานะคำสั่งซื้อ
  Color getStatusColor(String status) {
    switch (status) {
      case "pending":
        return Colors.orange;
      case "paid":
        return Colors.blue;
      case "delivering":
        return Colors.purple;
      case "completed":
        return Colors.green;
      case "canceled":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 query ดึงข้อมูลจาก Firestore collection 'orders' โดยเรียงจากวันที่ล่าสุด
    Query<Map<String, dynamic>> query =
        firestore.collection('orders').orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91), // พื้นหลังสีน้ำเงินเข้ม
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFD600), // สีเหลือง
        title: const Text(
          "📦 คำสั่งซื้อทั้งหมด",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 🔍 กล่องค้นหา
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) => setState(() => _searchText = value.trim()), // อัปเดตข้อความค้นหาเมื่อพิมพ์
              style: const TextStyle(color: Colors.black, fontSize: 16),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, color: Colors.black87),
                hintText: "ค้นหาชื่อ / อีเมล / สถานะ",
                hintStyle: const TextStyle(color: Colors.black54, fontSize: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.transparent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide:
                      const BorderSide(color: Color(0xFFFFD600), width: 2),
                ),
              ),
            ),
          ),

          // 🎛️ แถบปุ่มกรองสถานะ (ChoiceChip)
          SizedBox(
            height: 45,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _statusFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final status = _statusFilters[index];
                final isSelected = _filterStatus == status;
                return ChoiceChip(
                  label: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFFD600),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFFFFD600)
                          : Colors.black26,
                    ),
                  ),
                  onSelected: (_) => setState(() => _filterStatus = status), // เปลี่ยนสถานะกรอง
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // 📜 ส่วนแสดงรายการคำสั่งซื้อทั้งหมด
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(), // ✅ ใช้ Stream เพื่อรับข้อมูลแบบ real-time
              builder: (context, snapshot) {
                // 🔄 โหลดอยู่
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.yellow),
                  );
                }

                // ❌ ไม่มีข้อมูล
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("ยังไม่มีคำสั่งซื้อในระบบ",
                        style:
                            TextStyle(color: Colors.white70, fontSize: 16)),
                  );
                }

                // 🔍 ฟิลเตอร์คำสั่งซื้อ ตามข้อความค้นหา + สถานะ
                final filteredOrders = snapshot.data!.docs.where((doc) {
                  final order = doc.data() as Map<String, dynamic>;
                  final name =
                      (order["name"] ?? "").toString().toLowerCase();
                  final email =
                      (order["userEmail"] ?? "").toString().toLowerCase();
                  final status =
                      (order["status"] ?? "").toString().toLowerCase();
                  final search = _searchText.toLowerCase();

                  final matchesSearch =
                      name.contains(search) ||
                      email.contains(search) ||
                      status.contains(search);

                  final matchesFilter = _filterStatus == "ทั้งหมด" ||
                      status == _filterStatus.toLowerCase();

                  return matchesSearch && matchesFilter;
                }).toList();

                // ❌ ไม่เจอข้อมูลหลังกรอง
                if (filteredOrders.isEmpty) {
                  return const Center(
                    child: Text("ไม่พบคำสั่งซื้อที่ตรงกับการค้นหา",
                        style:
                            TextStyle(color: Colors.white70, fontSize: 16)),
                  );
                }

                // ✅ แสดงรายการทั้งหมดใน ListView
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = filteredOrders[index];
                    final order = doc.data() as Map<String, dynamic>;
                    final name = order["name"] ?? "ไม่ระบุ";
                    final email = order["userEmail"] ?? "ไม่ระบุ";
                    final total = order["total"] ?? 0;
                    final status = order["status"] ?? "pending";
                    final createdAt = order["createdAt"] is Timestamp
                        ? (order["createdAt"] as Timestamp).toDate()
                        : null;

                    // 🧾 การ์ดคำสั่งซื้อแต่ละรายการ
                    return Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          // 👉 กดเพื่อเปิดหน้ารายละเอียด OrderDetailPage
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OrderDetailPage(orderId: doc.id),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFF1B3C73)),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(status.toUpperCase(),
                                        style:
                                            const TextStyle(color: Colors.white)),
                                    backgroundColor: getStatusColor(status),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text("อีเมล: $email",
                                  style:
                                      const TextStyle(color: Colors.black87)),
                              const SizedBox(height: 4),
                              Text(
                                "ยอดรวม: ฿${total.toStringAsFixed(2)}",
                                style: const TextStyle(
                                    color: Color(0xFF0B3D91),
                                    fontWeight: FontWeight.bold),
                              ),
                              if (createdAt != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    "วันที่สั่ง: ${createdAt.day}/${createdAt.month}/${createdAt.year}",
                                    style: const TextStyle(
                                        color: Colors.black54, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== DETAIL PAGE ====================
// 🧾 หน้ารายละเอียดคำสั่งซื้อ (OrderDetailPage)
// ใช้สำหรับดูรายละเอียด, อัปเดตสถานะ, และจัดการคำสั่งซื้อแต่ละรายการ

class OrderDetailPage extends StatefulWidget {
  final String orderId; // รับค่า orderId จากหน้าก่อนหน้า
  const OrderDetailPage({super.key, required this.orderId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final firestore = FirebaseFirestore.instance; // ✅ ใช้เชื่อมต่อ Firestore
  final trackingController = TextEditingController(); // สำหรับกรอกหมายเลขพัสดุ
  bool isLoading = false; // สำหรับแสดง Loading ตอนอัปเดตสถานะ

  // ฟังก์ชันอัปเดตสถานะคำสั่งซื้อ เช่น จาก "pending" → "paid" หรือ "delivering"
  Future<void> updateStatus(String newStatus,
      {bool? isPaid, String? tracking}) async {
    setState(() => isLoading = true); // แสดง loading ขณะทำงาน

    // 🔥 ดึงเอกสารคำสั่งซื้อจาก Firestore ตาม orderId
    final orderDoc =
        await firestore.collection('orders').doc(widget.orderId).get();
    final orderData = orderDoc.data();

    // ❌ ถ้าไม่พบข้อมูล
    if (orderData == null) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ ไม่พบข้อมูลคำสั่งซื้อ")),
      );
      return;
    }

    final items = (orderData['items'] ?? []) as List; // ✅ ดึงรายการสินค้าที่อยู่ในคำสั่งซื้อ

    // ✅ คืน stock เมื่อสถานะถูกเปลี่ยนเป็น "canceled"
    if (newStatus == "canceled" && items.isNotEmpty) {
      for (final item in items) {
        final name = item['name']; // ชื่อสินค้า
        final qty = item['quantity'] ?? 1; // จำนวนสินค้าที่สั่ง

        // 🔍 ค้นหาสินค้าใน collection 'products' ที่มีชื่อเดียวกัน
        final productQuery = await firestore
            .collection('products')
            .where('name', isEqualTo: name)
            .limit(1)
            .get();

        // ถ้าพบสินค้าในฐานข้อมูล
        if (productQuery.docs.isNotEmpty) {
          final product = productQuery.docs.first;
          final currentStock = product['stock'] ?? 0;
          // ➕ เพิ่มจำนวน stock คืนเมื่อคำสั่งถูกยกเลิก
          await product.reference.update({'stock': currentStock + qty});
        }
      }
    }

    // ✅ อัปเดตข้อมูลคำสั่งซื้อใน Firestore
    await firestore.collection('orders').doc(widget.orderId).update({
      "status": newStatus, // สถานะใหม่
      if (isPaid != null) "isPaid": isPaid, // กำหนดสถานะจ่ายเงิน (ถ้ามี)
      if (tracking != null) "shippingTracking": tracking, // หมายเลขพัสดุ (ถ้ามี)
      "updatedAt": FieldValue.serverTimestamp(), // timestamp ล่าสุด
    });

    setState(() => isLoading = false); // ซ่อน loading

    // ✅ แสดง snackbar แจ้งผลสำเร็จ
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("✅ อัปเดตสถานะเป็น '$newStatus' แล้ว"),
      backgroundColor: Colors.green,
    ));

    Navigator.pop(context); // กลับไปหน้ารายการคำสั่งซื้อ
  }

  // ฟังก์ชันแสดงสีสถานะ (เหมือนหน้า OrderScreen)
  Color getStatusColor(String status) {
    switch (status) {
      case "pending":
        return Colors.orange;
      case "paid":
        return Colors.blue;
      case "delivering":
        return Colors.purple;
      case "completed":
        return Colors.green;
      case "canceled":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91), // พื้นหลังน้ำเงินเข้ม
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFD600), // สีเหลือง
        title: const Text(
          "รายละเอียดคำสั่งซื้อ",
          style: TextStyle(color: Colors.black),
        ),
      ),
      // ✅ ใช้ StreamBuilder เพื่ออัปเดตข้อมูลแบบ real-time
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            firestore.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          // ⏳ ยังโหลดข้อมูลอยู่
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.yellow));
          }

          // ดึงข้อมูลจาก Firestore document
          final order = snapshot.data!.data() as Map<String, dynamic>;
          final name = order["name"] ?? "ไม่ระบุ";
          final email = order["userEmail"] ?? "ไม่ระบุ";
          final items = (order["items"] as List?) ?? [];
          final slipUrl = order["slipUrl"] ?? "";
          final address = order["address"] ?? "ไม่ระบุ";
          final status = order["status"] ?? "pending";

          // 🧱 ส่วนเนื้อหาในหน้ารายละเอียด
          return Container(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                // 🧾 กล่องแสดงข้อมูลลูกค้า
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD600), Color(0xFFF7E96C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("ลูกค้า: $name",
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Text("อีเมล: $email",
                          style: const TextStyle(color: Colors.black87)),
                      Text("ที่อยู่จัดส่ง: $address",
                          style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 6),
                      // 🔖 แสดงสถานะปัจจุบันเป็น Chip สี
                      Chip(
                        label: Text(
                          "สถานะ: ${status.toUpperCase()}",
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: getStatusColor(status),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 📦 ส่วนแสดงรายการสินค้าในคำสั่งซื้อ
                const Text(
                  "รายการสินค้า",
                  style: TextStyle(
                      color: Colors.yellowAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const SizedBox(height: 8),

                // 🔁 แสดงสินค้าทุกรายการใน ListView
                ...items.map((item) {
                  final data = item as Map<String, dynamic>;
                  return Card(
                    color: Colors.white.withOpacity(0.9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: data["image"] != null
                            ? Image.network(data["image"],
                                width: 50, height: 50, fit: BoxFit.cover)
                            : const Icon(Icons.inventory_2_outlined),
                      ),
                      title: Text(data["name"] ?? "",
                          style: const TextStyle(color: Colors.black)),
                      subtitle: Text(
                        "฿${data["price"]} x ${data["quantity"]}",
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  );
                }),

                // 🧾 ถ้ามี slip แสดงรูปสลิปให้กดดูขยายได้
                if (slipUrl.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    "สลิปการชำระเงิน",
                    style: TextStyle(
                      color: Colors.yellowAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      // เปิดภาพเต็มจอในหน้าใหม่
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            backgroundColor: Colors.black,
                            appBar: AppBar(
                              backgroundColor: Colors.transparent,
                              iconTheme:
                                  const IconThemeData(color: Colors.white),
                            ),
                            body: Center(
                              child: InteractiveViewer(
                                clipBehavior: Clip.none,
                                panEnabled: true,
                                minScale: 0.5,
                                maxScale: 4.0,
                                child: Image.network(
                                  slipUrl,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        slipUrl,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // 🟡 ส่วนแสดงปุ่มอัปเดตสถานะ
                if (isLoading)
                  const Center(
                      child: CircularProgressIndicator(color: Colors.yellow))
                else ...[
                  // 🔹 ถ้าสถานะ = pending → แสดงปุ่ม "ยืนยันการชำระเงิน"
                  if (status == "pending")
                    ElevatedButton.icon(
                      onPressed: () => updateStatus("paid", isPaid: true),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text("ยืนยันการชำระเงิน"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size.fromHeight(50)),
                    ),

                  // 🔹 ถ้าสถานะ = paid → ให้กรอกหมายเลขพัสดุ และอัปเดตเป็น delivering
                  if (status == "paid") ...[
                    TextField(
                      controller: trackingController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "หมายเลขพัสดุ (เช่น TH1234567890)",
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white38)),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.yellow)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => updateStatus(
                        "delivering",
                        tracking: trackingController.text,
                      ),
                      icon: const Icon(Icons.local_shipping,
                          color: Colors.black87),
                      label: const Text(
                        "อัปเดตเป็น 'จัดส่งแล้ว'",
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        elevation: 3,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 🔹 ถ้าสถานะ = delivering → แสดงปุ่ม "สำเร็จแล้ว"
                  if (status == "delivering") ...[
                    ElevatedButton.icon(
                      onPressed: () => updateStatus("completed"),
                      icon: const Icon(Icons.done_all, color: Colors.white),
                      label: const Text(
                        "อัปเดตเป็น 'สำเร็จแล้ว'",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 🔹 ปุ่ม "ยกเลิกคำสั่งซื้อ" (จะไม่แสดงถ้าสำเร็จหรือถูกยกเลิกแล้ว)
                  if (status != "completed" && status != "canceled")
                    ElevatedButton.icon(
                      onPressed: () => updateStatus("canceled"),
                      icon: const Icon(Icons.cancel, color: Colors.white),
                      label: const Text("ยกเลิกคำสั่งซื้อ"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ]
              ],
            ),
          );
        },
      ),
    );
  }
}

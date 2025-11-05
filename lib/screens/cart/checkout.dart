import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/providers/cart_provider.dart';
import 'package:flutter_application_1/providers/auth_provider.dart';
import 'package:provider/provider.dart' as provider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/services/notification_service.dart';
import 'package:flutter_application_1/screens/cart/qr_payment_screen.dart';

// หน้าชำระเงินหลักของระบบ ใช้ ConsumerStatefulWidget เพื่อรองรับ Riverpod และ Provider พร้อมกัน
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  // เก็บวิธีการชำระเงินที่ผู้ใช้เลือก (ตัวแปรแบบ nullable)
  String? _selectedMethod;

  // Controller สำหรับช่องกรอกที่อยู่จัดส่ง
  final TextEditingController _addressController = TextEditingController();

  // รายการวิธีชำระเงินที่ให้ผู้ใช้เลือก
  final List<String> _paymentMethods = [
    'โอนผ่านบัญชีธนาคารหรือ QR Code พร้อมเพย์',
    'เก็บเงินปลายทาง',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserAddress(); // โหลดที่อยู่ผู้ใช้จาก Firestore ทันทีที่เปิดหน้า
  }

  /// โหลดที่อยู่ของผู้ใช้จาก Firestore โดยใช้ UID จาก FirebaseAuth
  Future<void> _loadUserAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ดึง document ของผู้ใช้จาก collection 'users'
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    // ถ้ามีข้อมูล address ใน Firestore → แสดงในช่องกรอกอัตโนมัติ
    if (doc.exists) {
      _addressController.text = doc.data()?['address'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // ดึง state ของผู้ใช้จาก Riverpod (authProvider)
    final authState = ref.watch(authProvider);

    // ดึงข้อมูลสินค้าในตะกร้าจาก Provider (CartProvider)
    final cart = provider.Provider.of<CartProvider>(context);
    final items = cart.items;
    final total = cart.total;

    // ดึงข้อมูลผู้ใช้ที่ล็อกอินจาก FirebaseAuth
    final user = FirebaseAuth.instance.currentUser;

    // รับข้อมูลเพิ่มเติมจาก cart.dart ที่ส่งมาผ่าน Navigator (ราคาหลังลด / คูปอง)
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final discountedTotal = args?['total'] ?? total; // ราคาหลังหักส่วนลด
    final discount = args?['discount'] ?? 0.0; // มูลค่าส่วนลด
    final couponCode = args?['coupon'] ?? ''; // รหัสคูปอง

    // ถ้ายังไม่ได้ล็อกอิน ให้ redirect ไปหน้า Login
    if (user == null || !authState.isAuthenticated) {
      Future.microtask(() {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0B3D91),
        centerTitle: true,
        title: const Text(
          "ชำระเงิน",
          style: TextStyle(
            color: Color(0xFFFFD600),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // กรณีไม่มีสินค้าในตะกร้า
      body: items.isEmpty
          ? const Center(
              child: Text("ไม่มีสินค้าในตะกร้า",
                  style: TextStyle(color: Colors.white, fontSize: 16)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // -------------------- ส่วนแสดงรายการสินค้า --------------------
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item["image"],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(item["name"],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1B3C73))),
                          subtitle: Text("฿${item["price"]}",
                              style: const TextStyle(color: Colors.black54)),
                          trailing: Text("x${item["quantity"]}",
                              style: const TextStyle(
                                  color: Color(0xFF1B3C73),
                                  fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // -------------------- ที่อยู่จัดส่ง --------------------
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextFormField(
                        controller: _addressController,
                        style: const TextStyle(color: Colors.black),
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: "ที่อยู่จัดส่ง",
                          labelStyle: TextStyle(color: Color(0xFF1B3C73)),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // -------------------- วิธีการชำระเงิน --------------------
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedMethod,
                    hint: const Text("เลือกวิธีชำระเงิน"),
                    items: _paymentMethods.map((method) {
                      return DropdownMenuItem(
                        value: method,
                        child: Text(method),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedMethod = value),
                  ),

                  const SizedBox(height: 20),

                  // -------------------- สรุปราคา --------------------
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B3C73),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // แสดงยอดรวมก่อนหักส่วนลด
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("ยอดรวมก่อนลด:",
                                style: TextStyle(color: Colors.white70)),
                            Text("฿${total.toStringAsFixed(2)}",
                                style: const TextStyle(color: Colors.white70)),
                          ],
                        ),

                        // ถ้ามีส่วนลด (เช่นจากคูปอง)
                        if (discount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("ส่วนลด ($couponCode):",
                                  style:
                                      const TextStyle(color: Colors.greenAccent)),
                              Text("-฿${discount.toStringAsFixed(2)}",
                                  style:
                                      const TextStyle(color: Colors.greenAccent)),
                            ],
                          ),
                        ],

                        const Divider(color: Colors.white30, height: 16),

                        // แสดงยอดสุทธิหลังลด
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("ยอดสุทธิ:",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18)),
                            Text("฿${discountedTotal.toStringAsFixed(2)}",
                                style: const TextStyle(
                                    color: Color(0xFFFFD600),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // -------------------- ปุ่มยืนยันคำสั่งซื้อ --------------------
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD600),
                      minimumSize: const Size.fromHeight(55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle, color: Colors.black),
                    label: const Text(
                      "ยืนยันคำสั่งซื้อ",
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.bold),
                    ),

                    // -------------------- ฟังก์ชันเมื่อกดปุ่ม --------------------
                    onPressed: () async {
                      if (_selectedMethod == null) {
                        // ถ้ายังไม่เลือกวิธีชำระเงิน
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("กรุณาเลือกวิธีชำระเงิน"),
                              backgroundColor: Colors.red),
                        );
                        return;
                      }

                      try {
                        final firestore = FirebaseFirestore.instance;
                        final user = FirebaseAuth.instance.currentUser!;
                        final userDoc =
                            await firestore.collection('users').doc(user.uid).get();

                        final userName = userDoc.data()?["name"] ?? "ไม่ระบุชื่อ";
                        final userAddress = _addressController.text.trim();

                        // -------------------- สร้างคำสั่งซื้อใหม่ --------------------
                        final orderRef = await firestore.collection('orders').add({
                          "userId": user.uid,
                          "orderId": "",
                          "userEmail": user.email ?? "",
                          "name": userName,
                          "address": userAddress,
                          "items": items,
                          "totalBeforeDiscount": total,
                          "discount": discount,
                          "couponCode": couponCode,
                          "total": discountedTotal,
                          "paymentMethod": _selectedMethod,
                          "status": "pending",
                          "isPaid": false,
                          "createdAt": FieldValue.serverTimestamp(),
                          "updatedAt": FieldValue.serverTimestamp(),
                        });

                        // อัปเดต field orderId = id จริงของ document
                        await orderRef.update({"orderId": orderRef.id});

                        // -------------------- ตัด stock ของสินค้า --------------------
                        for (final item in items) {
                          final productName = item['name'];
                          final quantity = item['quantity'] ?? 1;

                          final query = await firestore
                              .collection('products')
                              .where('name', isEqualTo: productName)
                              .limit(1)
                              .get();

                          if (query.docs.isNotEmpty) {
                            final productDoc = query.docs.first;
                            final stock = productDoc['stock'] ?? 0;
                            final newStock = (stock - quantity).clamp(0, stock);
                            await productDoc.reference.update({'stock': newStock});
                          }
                        }

                        // -------------------- ล้างตะกร้า --------------------
                        cart.clearCart();

                        // -------------------- แจ้งเตือนแอดมินผ่าน FCM --------------------
                        await FCMService.sendNotification(
                          title: "📦 มีคำสั่งซื้อใหม่!",
                          body: "ลูกค้า $userName ได้สั่งซื้อสินค้าใหม่",
                        );

                        // -------------------- การเลือกวิธีชำระเงิน --------------------
                        if (_selectedMethod ==
                            'โอนผ่านบัญชีธนาคารหรือ QR Code พร้อมเพย์') {
                          // ถ้าเลือกแบบโอน → ไปหน้า QR Payment
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QRPaymentScreen(
                                totalAmount: total,
                                cartItems: items,
                                orderId: orderRef.id,
                              ),
                            ),
                          );
                        } else {
                          // ถ้าเลือกแบบเก็บเงินปลายทาง → แสดง SnackBar และไปหน้าประวัติ
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("✅ สั่งซื้อแบบเก็บเงินปลายทางเรียบร้อย!"),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.pushReplacementNamed(context, '/order-history');
                        }
                      } catch (e) {
                        // -------------------- จัดการข้อผิดพลาด --------------------
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("เกิดข้อผิดพลาด: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

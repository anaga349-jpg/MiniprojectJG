import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/providers/cart_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/services/coupon_service.dart';

// หน้าตะกร้าสินค้า ใช้ ConsumerStatefulWidget เพื่อรองรับทั้ง Riverpod และ Provider ร่วมกัน
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  // ตัวแปรควบคุมสถานะโหลด เช่น ระหว่างเช็กคูปองหรือไปหน้าชำระเงิน
  bool _isLoading = false;

  // controller สำหรับรับรหัสคูปองจากผู้ใช้
  final TextEditingController _couponController = TextEditingController();

  // เก็บข้อมูลคูปองที่ถูกใช้แล้ว (เช่น id, code, discountType, value)
  Map<String, dynamic>? appliedCoupon;

  // เก็บจำนวนเงินส่วนลดที่คำนวณได้
  double discountAmount = 0;

  /// ฟังก์ชันใช้ตรวจสอบและนำคูปองไปใช้
  /// 1. รับยอดรวมในตะกร้า (total)
  /// 2. ตรวจสอบคูปองกับฐานข้อมูลผ่าน CouponService
  /// 3. คำนวณส่วนลด (percent หรือ fixed)
  /// 4. อัปเดต UI และ mark คูปองว่าใช้แล้วใน Firestore
  Future<void> _applyCoupon(double total) async {
    final code = _couponController.text.trim(); // อ่านรหัสคูปองจากช่องกรอก
    if (code.isEmpty) {
      // ถ้าไม่ได้กรอกอะไรเลย แสดงข้อความเตือน
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณากรอกรหัสคูปองก่อน")),
      );
      return;
    }

    setState(() => _isLoading = true); // เริ่มโหลด

    try {
      // ตรวจสอบรหัสคูปองกับ Firestore ผ่าน Service
      final couponData = await CouponService.validateCoupon(code);

      // ถ้าไม่พบหรือหมดอายุแล้ว
      if (couponData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ ไม่พบคูปองนี้ หรือคูปองหมดอายุแล้ว")),
        );
        setState(() => _isLoading = false);
        return;
      }

      // ประเภทคูปอง (percent / fixed)
      double discount = 0;
      final discountType = couponData['discountType'];
      final value = (couponData['value'] ?? 0).toDouble();

      // ถ้าเป็น percent จะคิดเป็นเปอร์เซ็นต์จากยอดรวม
      if (discountType == "percent") {
        discount = total * (value / 100);
      } else {
        // ถ้าเป็น fixed จะลดตามจำนวนเงินตรง ๆ
        discount = value;
      }

      // บันทึกผลลัพธ์ไว้ใน state เพื่ออัปเดตหน้าจอ
      setState(() {
        appliedCoupon = couponData;
        discountAmount = discount;
      });

      // บันทึกสถานะว่าคูปองนี้ถูกใช้แล้ว (update ที่ Firestore)
      await CouponService.markCouponUsed(couponData['id']);

      // แจ้งผลลัพธ์
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "✅ ใช้คูปอง ${couponData['code']} สำเร็จ! ลด ${value}${discountType == 'percent' ? '%' : '฿'}"),
        ),
      );
    } catch (e) {
      // กรณีเกิดข้อผิดพลาดอื่น ๆ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เกิดข้อผิดพลาด: $e")),
      );
    } finally {
      setState(() => _isLoading = false); // หยุดโหลด
    }
  }

  @override
  Widget build(BuildContext context) {
    // ดึง CartProvider ผ่าน Provider ของ Flutter (สำหรับจัดการสินค้าในตะกร้า)
    final cartProvider = context.watch<CartProvider>();
    final cartItems = cartProvider.items; // รายการสินค้าในตะกร้า
    final total = cartProvider.total; // ยอดรวมก่อนส่วนลด

    // ดึงสถานะผู้ใช้จาก Riverpod (authProvider)
    final authState = ref.watch(authProvider);

    // คำนวณยอดสุดท้ายหลังหักส่วนลด แต่ไม่ให้ติดลบ (ใช้ clamp)
    final finalTotal = (total - discountAmount).clamp(0, total);

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        title: const Text("🛒 ตะกร้าสินค้า"),
        backgroundColor: const Color(0xFF1565C0),
        actions: [
          // ปุ่ม “ล้างทั้งหมด” เพื่อลบสินค้าทั้งหมดในตะกร้า
          TextButton.icon(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            label: const Text("ล้างทั้งหมด",
                style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              context.read<CartProvider>().clearCart(); // ล้างข้อมูลใน provider
              setState(() {
                // รีเซ็ตสถานะคูปองด้วย
                appliedCoupon = null;
                discountAmount = 0;
                _couponController.clear();
              });
            },
          ),
        ],
      ),

      // ถ้ายังไม่มีสินค้าในตะกร้า → แสดงข้อความ “ยังไม่มีสินค้า”
      body: cartItems.isEmpty
          ? const Center(
              child: Text("ยังไม่มีสินค้าในตะกร้า",
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            )
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // แสดงรายการสินค้าแบบ ListView แยกด้วยช่องว่าง
                  Expanded(
                    child: ListView.separated(
                      itemCount: cartItems.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12), // ระยะห่างแต่ละรายการ
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        final imageUrl = item["image"] ?? "";
                        final isNetworkImage = imageUrl.startsWith("http");
                        final quantity = item["quantity"] ?? 1;
                        final price = item["price"] ?? 0;

                        // แสดงแต่ละสินค้าใน Card
                        return Card(
                          color: const Color(0xFF1565C0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                          child: ListTile(
                            // แสดงรูปสินค้า (รองรับทั้ง URL และ asset)
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: isNetworkImage
                                  ? Image.network(imageUrl,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover)
                                  : Image.asset(imageUrl,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover),
                            ),
                            // ชื่อสินค้า
                            title: Text(item["name"] ?? "ไม่มีชื่อสินค้า",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFFD600))),

                            // รายละเอียดสินค้า (ราคา, ปุ่ม + -, รวม)
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("฿$price",
                                    style:
                                        const TextStyle(color: Colors.white)),
                                Row(
                                  children: [
                                    // ปุ่มลดจำนวนสินค้า
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle,
                                          color: Colors.redAccent),
                                      onPressed: () {
                                        context
                                            .read<CartProvider>()
                                            .decreaseQuantity(index);
                                      },
                                    ),
                                    // แสดงจำนวนปัจจุบัน
                                    Text("$quantity",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),

                                    // ปุ่มเพิ่มจำนวนสินค้า
                                    IconButton(
                                      icon: const Icon(Icons.add_circle,
                                          color: Colors.greenAccent),
                                      onPressed: () async {
                                        // ตรวจสอบจำนวน stock จาก Firestore ก่อนเพิ่ม
                                        final snapshot = await FirebaseFirestore
                                            .instance
                                            .collection('products')
                                            .where('name',
                                                isEqualTo: item["name"])
                                            .limit(1)
                                            .get();

                                        if (snapshot.docs.isNotEmpty) {
                                          final stock =
                                              snapshot.docs.first['stock'] ?? 0;
                                          if (quantity >= stock) {
                                            // ถ้ามีสินค้าคงเหลือไม่พอ → แจ้งเตือน
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    "สินค้า ${item["name"]} เหลือ $stock ชิ้น"),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                            return;
                                          }
                                        }

                                        // ถ้าผ่านเงื่อนไข → เพิ่มสินค้าใน provider
                                        context
                                            .read<CartProvider>()
                                            .increaseQuantity(index);
                                      },
                                    ),
                                  ],
                                ),
                                // แสดงราคาสินค้ารวม (ราคาต่อชิ้น * จำนวน)
                                Text(
                                  "รวม: ฿${(price * quantity).toStringAsFixed(2)}",
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                            // ปุ่มลบสินค้าชิ้นนี้ออกจากตะกร้า
                            trailing: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              onPressed: () {
                                context.read<CartProvider>().removeItem(index);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ส่วนกรอกและใช้รหัสคูปอง
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // ช่องกรอกรหัสคูปอง
                        Expanded(
                          child: TextField(
                            controller: _couponController,
                            decoration: const InputDecoration(
                              hintText: "กรอกรหัสคูปอง",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        // ปุ่มใช้คูปอง
                        ElevatedButton(
                          onPressed: () => _applyCoupon(total),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.yellow),
                          child: const Text("ใช้คูปอง",
                              style: TextStyle(color: Colors.black)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ส่วนสรุปราคารวมและส่วนลด
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // แสดงยอดรวมก่อนหักส่วนลด
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("ยอดรวม:",
                                style: TextStyle(color: Colors.white)),
                            Text("฿${total.toStringAsFixed(2)}",
                                style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                        // ถ้ามีส่วนลด แสดงแถวส่วนลดเพิ่ม
                        if (discountAmount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  "ส่วนลด (${appliedCoupon?['value']}%)",
                                  style: const TextStyle(
                                      color: Colors.greenAccent)),
                              Text("-฿${discountAmount.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                      color: Colors.greenAccent)),
                            ],
                          ),
                        ],
                        const Divider(color: Colors.white30),
                        // แสดงยอดสุทธิหลังหักส่วนลด
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("ยอดสุทธิ:",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18)),
                            Text("฿${finalTotal.toStringAsFixed(2)}",
                                style: const TextStyle(
                                    color: Color(0xFFFFD600),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

      // แถบล่าง (bottom bar) มีปุ่มกลับหน้าร้าน และปุ่มไปชำระเงิน
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))
          ],
        ),
        child: Row(
          children: [
            // ปุ่มกลับไปหน้า Home
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD600),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                label: const Text("กลับหน้าร้าน",
                    style: TextStyle(color: Colors.black, fontSize: 16)),
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
              ),
            ),
            const SizedBox(width: 12),

            // ปุ่มไปหน้าชำระเงิน (checkout)
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.payment, color: Color(0xFFFFD600)),
                label: const Text(
                  "ไปชำระเงิน",
                  style: TextStyle(color: Color(0xFFFFD600), fontSize: 16),
                ),
                onPressed: _isLoading
                  ? null // ถ้ากำลังโหลดอยู่ ปิดการกดปุ่ม
                  : () async {
                      // ตรวจสอบก่อนชำระเงิน
                      if (cartItems.isEmpty) {
                        // ถ้าตะกร้าว่าง
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("ตะกร้าว่าง ไม่สามารถชำระเงินได้"),
                              backgroundColor: Colors.red),
                        );
                        return;
                      }

                      // ถ้ายังไม่ได้ล็อกอิน
                      if (!authState.isAuthenticated) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("กรุณาเข้าสู่ระบบก่อนทำการชำระเงิน"),
                            backgroundColor: Colors.red,
                          ),
                        );
                        Navigator.pushNamed(context, '/login');
                        return;
                      }

                      // เริ่มโหลดจำลองการตรวจสอบคำสั่งซื้อ
                      setState(() => _isLoading = true);
                      await Future.delayed(const Duration(seconds: 1));
                      setState(() => _isLoading = false);

                      // เมื่อพร้อม → ไปหน้าชำระเงินพร้อมส่งข้อมูลจำเป็น
                      Navigator.pushNamed(
                        context,
                        '/checkout',
                        arguments: {
                          'total': finalTotal, // ราคารวมหลังหักส่วนลด
                          'discount': discountAmount, // จำนวนส่วนลด
                          'coupon': appliedCoupon?['code'] ?? '', // รหัสคูปองที่ใช้
                        },
                      );
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

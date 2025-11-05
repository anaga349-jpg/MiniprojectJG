import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/providers/cart_provider.dart';

// หน้ารายละเอียดสินค้า (Product Detail)
class ProductDetailScreen extends StatefulWidget {
  final String name; // ชื่อสินค้า
  final double price; // ราคาสินค้า
  final List<String> images; // รูปภาพสินค้า (อาจมีหลายรูป)
  final int stock; // จำนวนสต็อกสินค้าที่เหลือ

  const ProductDetailScreen({
    super.key,
    required this.name,
    required this.price,
    required this.images,
    required this.stock,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int quantity = 1; // ตัวแปรเก็บจำนวนสินค้าที่ผู้ใช้ต้องการเลือกซื้อ

  @override
  Widget build(BuildContext context) {
    // ใช้ Provider เพื่อเข้าถึงข้อมูลตะกร้าสินค้า
    final cartProvider = context.watch<CartProvider>();

    // ตรวจสอบว่าสินค้าหมดหรือไม่
    final isOutOfStock = widget.stock <= 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: Text(widget.name),
        leading: IconButton(
          icon: const Icon(Icons.home, color: Color(0xFFFFD600)),
          onPressed: () {
            // กลับไปหน้าหลักเมื่อกดปุ่ม Home
            Navigator.pushReplacementNamed(context, '/home');
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ส่วนแสดงรูปภาพของสินค้า
            SizedBox(
              height: 200,
              child: PageView.builder(
                // ใช้ PageView เพื่อให้เลื่อนดูรูปภาพได้
                itemCount: widget.images.length,
                itemBuilder: (context, index) {
                  final imageUrl = widget.images[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image,
                                    size: 100, color: Colors.grey),
                          )
                        : const Icon(Icons.image,
                            size: 100, color: Colors.grey),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // กล่องแสดงรายละเอียดสินค้า (ชื่อ, ราคา, สต็อก)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // แสดงชื่อสินค้า
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // แสดงราคาสินค้า
                  Text(
                    "ราคา: ฿${widget.price.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // แสดงจำนวนสต็อกคงเหลือ
                  Text(
                    "สต็อกคงเหลือ: ${widget.stock}",
                    style: TextStyle(
                      fontSize: 16,
                      color:
                          widget.stock > 0 ? Colors.white : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // แสดงตัวเลือกจำนวนสินค้าที่จะซื้อ (Dropdown)
                  if (!isOutOfStock)
                    Row(
                      children: [
                        const Text("จำนวน:",
                            style: TextStyle(color: Colors.white)),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: quantity,
                          dropdownColor: Colors.blueGrey,
                          // จำกัดจำนวนสูงสุดที่เลือกได้ไม่เกิน 5 หรือจำนวนสต็อกจริง
                          items: List.generate(
                            (widget.stock < 5 ? widget.stock : 5),
                            (index) => index + 1,
                          ).map((qty) {
                            return DropdownMenuItem(
                              value: qty,
                              child: Text(qty.toString()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            // เมื่อเปลี่ยนจำนวน จะอัปเดตค่าภายใน state
                            setState(() {
                              quantity = value!;
                            });
                          },
                        ),
                      ],
                    )
                  else
                    // ถ้าสินค้าหมด
                    const Text(
                      "สินค้าหมด",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),

            const Spacer(),

            // ปุ่มเพิ่มสินค้าไปยังตะกร้า (Add to Cart)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isOutOfStock ? Colors.grey : const Color(0xFFFFD600),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  Icons.add_shopping_cart,
                  color: isOutOfStock ? Colors.black38 : Colors.black,
                ),
                label: Text(
                  isOutOfStock ? "สินค้าหมด" : "Add to Cart",
                  style: TextStyle(
                    color: isOutOfStock ? Colors.black38 : Colors.black,
                    fontSize: 16,
                  ),
                ),

                onPressed: isOutOfStock
                    ? null // ปิดการกดปุ่มเมื่อสินค้าหมด
                    : () {
                        // ตรวจสอบว่าสินค้าชิ้นนี้มีอยู่ในตะกร้าแล้วหรือไม่
                        final existingItem = cartProvider.items.firstWhere(
                          (item) => item['name'] == widget.name,
                          orElse: () => {},
                        );

                        // ดึงจำนวนสินค้าปัจจุบันในตะกร้า
                        int currentQty = existingItem.isNotEmpty
                            ? existingItem['quantity'] ?? 0
                            : 0;

                        // ถ้าจำนวนรวมเกินสต็อก ให้แจ้งเตือนและไม่เพิ่ม
                        if (currentQty + quantity > widget.stock) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  "⚠️ ครบจำนวนสต็อกแล้ว (${widget.stock} ชิ้น)"),
                              backgroundColor: Colors.orangeAccent,
                            ),
                          );
                          return;
                        }

                        // สร้างข้อมูลสินค้าเพื่อเพิ่มลงตะกร้า
                        final product = {
                          "name": widget.name,
                          "price": widget.price,
                          "image": widget.images.first,
                          "quantity": quantity,
                        };

                        // เพิ่มสินค้าไปยังตะกร้า
                        cartProvider.addItem(product);

                        // แสดง SnackBar แจ้งเตือนว่าการเพิ่มสำเร็จ
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${widget.name} ถูกเพิ่มลงตะกร้า (${currentQty + quantity}/${widget.stock} ชิ้น)'),
                            duration: const Duration(seconds: 2),
                          ),
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

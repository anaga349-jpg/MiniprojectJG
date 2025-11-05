import 'package:flutter/material.dart';
import 'package:flutter_application_1/providers/cart_provider.dart';
import 'package:flutter_application_1/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/product_detail.dart';

// หน้าหลักของแอป (HomeScreen) ใช้ ConsumerStatefulWidget เพื่อให้ใช้ Riverpod ได้
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = ""; // ตัวแปรเก็บข้อความค้นหา

  @override
  Widget build(BuildContext context) {
    // ดึงข้อมูลสถานะการล็อกอินจาก authProvider
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: const Text(
          'Speedway Store',
          style: TextStyle(color: Color(0xFFFFD600)),
        ),
        actions: [
          // ส่วนของลูกค้า (User)
          if (authState.isAuthenticated && authState.role == "user") ...[
            IconButton(
              icon: const Icon(Icons.person),
              color: const Color(0xFFFFD600),
              tooltip: "โปรไฟล์",
              onPressed: () => Navigator.pushNamed(context, '/profile'),
            ),
            IconButton(
              icon: const Icon(Icons.chat),
              color: const Color(0xFFFFD600),
              tooltip: "แชทกับร้านค้า",
              onPressed: () => Navigator.pushNamed(context, '/chat'),
            ),
            IconButton(
              icon: const Icon(Icons.shopping_cart),
              color: const Color(0xFFFFD600),
              tooltip: "ตะกร้าสินค้า",
              onPressed: () => Navigator.pushNamed(context, '/cart'),
            ),
          ],

          // ส่วนของแอดมิน (Admin)
          if (authState.isAuthenticated && authState.role == "admin") ...[
            // StreamBuilder ฟังการเปลี่ยนแปลงของข้อความที่ยังไม่ได้อ่าน
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('unreadByAdmin', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // จำนวนแชตที่ยังไม่ได้อ่าน
                final unreadCount = snapshot.data?.docs.length ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.dashboard),
                      color: const Color(0xFFFFD600),
                      tooltip: "Dashboard",
                      onPressed: () =>
                          Navigator.pushNamed(context, '/dashboard'),
                    ),
                    // แสดง badge แดงเมื่อมีข้อความใหม่
                    if (unreadCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            // ปุ่มออกจากระบบ
            IconButton(
              icon: const Icon(Icons.logout),
              color: const Color(0xFFFFD600),
              tooltip: "ออกจากระบบ",
              onPressed: () {
                ref.read(authProvider.notifier).logout(); // ล้างสถานะล็อกอิน
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],

          // ผู้ใช้ที่ยังไม่ล็อกอิน
          if (!authState.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.login),
              color: const Color(0xFFFFD600),
              tooltip: "เข้าสู่ระบบ",
              onPressed: () => Navigator.pushNamed(context, '/login'),
            ),
        ],
      ),

      // ส่วนของเนื้อหาหลัก (Body)
      body: Column(
        children: [
          // กล่องค้นหาสินค้า
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: "ค้นหาชื่อสินค้า...",
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                hintStyle: const TextStyle(color: Colors.black45),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // StreamBuilder ดึงข้อมูลสินค้าทั้งหมดจาก Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.yellow),
                  );
                }

                // ถ้ายังไม่มีสินค้าในระบบ
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "ยังไม่มีสินค้าในระบบ",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  );
                }

                // กรองข้อมูลสินค้าในฝั่ง client ด้วยข้อความค้นหา
                final filtered = snapshot.data!.docs.where((doc) {
                  final name = (doc['name'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      "ไม่พบสินค้าที่ตรงกับคำค้น",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  );
                }

                // แสดงสินค้าในรูปแบบ GridView
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // แสดง 2 คอลัมน์
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.75, // สัดส่วนการ์ดสินค้า
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product =
                        filtered[index].data() as Map<String, dynamic>;
                    final name = product['name'] ?? 'ไม่มีชื่อ';
                    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
                    final image = product['image'] ?? '';
                    final stock = (product['stock'] ?? 0) as int;

                    // สร้างการ์ดสินค้าแต่ละรายการ
                    return ProductCard(
                      name: name,
                      price: price,
                      image: image,
                      stock: stock,
                      isLoggedIn: authState.isAuthenticated,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // ปุ่ม Floating Chat (เฉพาะลูกค้าเท่านั้น)
      floatingActionButton:
          authState.isAuthenticated && authState.role == "user"
              ? FloatingActionButton(
                  backgroundColor: const Color(0xFFFFD600),
                  child: const Icon(Icons.chat, color: Colors.black),
                  onPressed: () => Navigator.pushNamed(context, '/chat'),
                )
              : null,
    );
  }
}

// วิดเจ็ตแสดงสินค้าแต่ละชิ้นในรูปแบบการ์ด
class ProductCard extends StatelessWidget {
  final String name;
  final double price;
  final String image;
  final bool isLoggedIn;
  final int stock;

  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    required this.image,
    required this.isLoggedIn,
    required this.stock,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = stock <= 0; // ตรวจว่าสินค้าหมดหรือไม่

    return InkWell(
      onTap: () {
        // เมื่อกดที่สินค้า จะไปหน้ารายละเอียดสินค้า
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              name: name,
              price: price,
              images: [image],
              stock: stock,
            ),
          ),
        );
      },
      child: Card(
        color: const Color(0xFF1E88E5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  // พื้นหลังและรูปสินค้า
                  Container(
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: image.isNotEmpty
                        ? Image.network(
                            image,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : const Icon(Icons.image, size: 80, color: Colors.grey),
                  ),
                  // ถ้าสินค้าหมดแสดงข้อความ SOLD OUT ทับภาพ
                  if (isOutOfStock)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.6),
                        alignment: Alignment.center,
                        child: const Text(
                          "SOLD OUT",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            shadows: [
                              Shadow(
                                blurRadius: 6,
                                color: Colors.black,
                                offset: Offset(1, 2),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ส่วนล่างของการ์ด (ชื่อ, ราคา, ปุ่ม)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Color(0xFFFFD600),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "฿${price.toStringAsFixed(0)}",
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  // ปุ่มเพิ่มลงตะกร้า
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOutOfStock
                          ? Colors.grey
                          : const Color(0xFFFFD600),
                    ),
                    onPressed: isOutOfStock
                        ? null // ถ้าหมดสต็อก ปุ่มกดไม่ได้
                        : () {
                            // ถ้าไม่ได้ล็อกอิน จะบังคับให้ไปหน้า login
                            if (!isLoggedIn) {
                              Navigator.pushNamed(context, '/login');
                              return;
                            }

                            // เข้าถึง CartProvider เพื่อจัดการตะกร้าสินค้า
                            final cartProvider = context.read<CartProvider>();

                            // ตรวจสอบว่าสินค้านี้มีอยู่ในตะกร้าแล้วหรือยัง
                            final existingItem = cartProvider.items.firstWhere(
                              (item) => item['name'] == name,
                              orElse: () => {},
                            );

                            int currentQty = existingItem.isNotEmpty
                                ? existingItem['quantity'] ?? 0
                                : 0;

                            // ถ้าจำนวนในตะกร้ามากกว่าหรือเท่ากับสต็อก ให้แจ้งเตือน
                            if (currentQty >= stock) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "⚠️ สินค้า $name ครบจำนวนสต็อกแล้ว ($stock ชิ้น)",
                                  ),
                                  backgroundColor: Colors.orangeAccent,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              return;
                            }

                            // เพิ่มสินค้าใหม่ลงตะกร้า
                            final product = {
                              "name": name,
                              "price": price,
                              "image": image,
                            };
                            cartProvider.addItem(product);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "เพิ่ม $name แล้ว (${currentQty + 1}/$stock ชิ้น)",
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                    child: Text(
                      isOutOfStock ? 'SOLD OUT' : 'Add to Cart',
                      style: TextStyle(
                        color: isOutOfStock ? Colors.white70 : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
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

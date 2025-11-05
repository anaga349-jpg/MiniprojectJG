import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// ✅ หน้าสำหรับ "เพิ่ม" หรือ "แก้ไข" สินค้าในระบบ
/// - ถ้ามี `product` → แก้ไขสินค้าเดิม
/// - ถ้าไม่มี `product` → เพิ่มสินค้าใหม่
class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product;

  const EditProductScreen({super.key, this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  // ✅ Key สำหรับตรวจสอบการ validate ของฟอร์ม
  final _formKey = GlobalKey<FormState>();

  // ✅ Controller สำหรับช่องกรอกข้อมูล
  late TextEditingController nameController;
  late TextEditingController priceController;
  late TextEditingController stockController;

  // ✅ ตัวแปรจัดการรูปภาพ
  File? _imageFile; // รูปใหม่ที่ผู้ใช้อัปโหลด
  String? _imageUrl; // URL ของรูปเก่าหรือที่อัปโหลดสำเร็จแล้ว
  bool _isUploading = false; // สำหรับแสดง loading state ขณะบันทึกข้อมูล

  @override
  void initState() {
    super.initState();

    // ✅ กำหนดค่าเริ่มต้นให้ text field (กรณีเป็นการแก้ไข)
    nameController = TextEditingController(text: widget.product?["name"] ?? "");
    priceController =
        TextEditingController(text: widget.product?["price"]?.toString() ?? "");
    stockController =
        TextEditingController(text: widget.product?["stock"]?.toString() ?? "");
    _imageUrl = widget.product?["image"]; // ดึง URL ของภาพเดิมมาใช้แสดง
  }

  /// ✅ ฟังก์ชันเปิดแกลเลอรีเพื่อเลือกรูป
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  /// ✅ ฟังก์ชันอัปโหลดรูปภาพขึ้น Firebase Storage แล้วคืนค่า URL
  Future<String> _uploadImage(File image) async {
    // ตั้งชื่อไฟล์ให้ไม่ซ้ำ โดยใช้เวลาปัจจุบัน (timestamp)
    final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child('products/$fileName');

    // อัปโหลดไฟล์จริง
    await ref.putFile(image);

    // คืนค่า URL ที่สามารถเรียกดูรูปได้
    return await ref.getDownloadURL();
  }

  /// ✅ ฟังก์ชันบันทึกสินค้า (ทั้งเพิ่มใหม่และแก้ไข)
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return; // ตรวจสอบการกรอกฟอร์ม

    setState(() => _isUploading = true); // แสดงโหลดระหว่างบันทึก

    try {
      String imageUrl = _imageUrl ?? "";

      // ถ้ามีรูปใหม่ ให้ทำการอัปโหลดก่อน
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
      }

      // ✅ เตรียมข้อมูลสินค้าที่จะบันทึกลง Firestore
      final productData = {
        "name": nameController.text.trim(),
        "price": double.tryParse(priceController.text) ?? 0,
        "stock": int.tryParse(stockController.text) ?? 0,
        "image": imageUrl,
        "updatedAt": FieldValue.serverTimestamp(),
      };

      final firestore = FirebaseFirestore.instance.collection("products");

      // ✅ ตรวจว่ากำลัง "เพิ่ม" หรือ "แก้ไข"
      if (widget.product == null) {
        // ➕ เพิ่มสินค้าใหม่
        await firestore.add({
          ...productData,
          "createdAt": FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ เพิ่มสินค้าใหม่เรียบร้อย!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // ✏️ แก้ไขสินค้าที่มีอยู่ (ต้องมี id ของ document)
        await firestore.doc(widget.product!["id"]).update(productData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ แก้ไขสินค้าเรียบร้อย!"),
            backgroundColor: Colors.green,
          ),
        );
      }

      // ✅ กลับไปหน้าก่อนหน้า (เฉพาะตอน widget ยังอยู่ใน tree)
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // ⚠️ ถ้ามี error เช่น upload หรือ Firestore fail
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ เกิดข้อผิดพลาด: $e")),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null; // true = แก้ไข / false = เพิ่มใหม่

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFD600),
        title: Text(
          isEdit ? "แก้ไขสินค้า" : "เพิ่มสินค้าใหม่",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              /// ✅ ส่วนเลือกรูปภาพสินค้า
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: _imageFile != null
                      // ถ้ามีรูปใหม่ แสดงจากไฟล์
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      // ถ้าไม่มีแต่มี URL เก่า → แสดงรูปเก่า
                      : (_imageUrl != null && _imageUrl!.isNotEmpty)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child:
                                  Image.network(_imageUrl!, fit: BoxFit.cover),
                            )
                          // ถ้าไม่มีทั้งสอง → แสดงข้อความ
                          : const Center(
                              child: Text(
                                "แตะเพื่อเลือกรูปสินค้า",
                                style: TextStyle(
                                    color: Colors.black54, fontSize: 16),
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 20),

              /// ✅ ช่องกรอกข้อมูลสินค้า
              _buildTextField(
                controller: nameController,
                label: "ชื่อสินค้า",
                icon: Icons.drive_file_rename_outline,
                validator: (v) =>
                    v == null || v.isEmpty ? "กรุณากรอกชื่อสินค้า" : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: priceController,
                label: "ราคา",
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
                validator: (v) => v == null || double.tryParse(v) == null
                    ? "ราคาต้องเป็นตัวเลข"
                    : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: stockController,
                label: "จำนวนในสต็อก",
                icon: Icons.inventory_2,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v == null || int.tryParse(v) == null
                        ? "จำนวนต้องเป็นตัวเลข"
                        : null,
              ),
              const SizedBox(height: 30),

              /// ✅ ปุ่มบันทึกสินค้า
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.save, color: Colors.black),
                  label: Text(
                    _isUploading
                        ? "กำลังบันทึก..."
                        : (isEdit ? "บันทึกการแก้ไข" : "เพิ่มสินค้า"),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD600),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  onPressed: _isUploading ? null : _saveProduct,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ ฟังก์ชันย่อยสำหรับสร้าง TextField
  /// ออกแบบให้หัวข้อสีเหลือง, ตัวอักษรดำ, มุมโค้ง, และมี icon นำหน้า
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFFFFD600),
          fontWeight: FontWeight.bold,
        ),
        prefixIcon: Icon(icon, color: Colors.black87),
        filled: true,
        fillColor: Colors.white,
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFFFD600), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

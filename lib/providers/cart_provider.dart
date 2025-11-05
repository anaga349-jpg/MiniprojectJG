import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// คลาส CartProvider ใช้จัดการข้อมูล "ตะกร้าสินค้า" ของผู้ใช้
// โดยใช้ ChangeNotifier เพื่ออัปเดต UI อัตโนมัติเมื่อมีการเปลี่ยนแปลง
// และใช้ SharedPreferences เพื่อบันทึกข้อมูลลงเครื่อง (local storage)
class CartProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _items = []; // เก็บรายการสินค้าทั้งหมดในตะกร้า

  // getter สำหรับเข้าถึงรายการสินค้าในตะกร้า
  List<Map<String, dynamic>> get items => _items;

  // getter สำหรับคำนวณราคารวมทั้งหมดของสินค้าในตะกร้า
  // ใช้ fold() เพื่อรวมราคาสินค้าแต่ละชิ้น * จำนวน
  double get total => _items.fold(
      0, (sum, item) => sum + (item["price"] * (item["quantity"] ?? 1)));

  // constructor เริ่มต้น เรียกฟังก์ชัน _loadCart() เพื่อโหลดข้อมูลตะกร้า
  CartProvider() {
    _loadCart(); // โหลดข้อมูลเมื่อเปิดแอปหรือสร้าง Provider ใหม่
  }

  // ฟังก์ชันโหลดข้อมูลตะกร้าจาก SharedPreferences (local storage)
  Future<void> _loadCart() async {
    final prefs = await SharedPreferences.getInstance(); // เข้าถึง SharedPreferences
    final data = prefs.getString("cart_items"); // ดึงข้อมูล key "cart_items"
    if (data != null) {
      // ถ้ามีข้อมูล ให้แปลงจาก JSON -> List<Map>
      _items = List<Map<String, dynamic>>.from(jsonDecode(data));
      notifyListeners(); // แจ้งให้ UI อัปเดต
    }
  }

  // ฟังก์ชันบันทึกข้อมูลตะกร้าปัจจุบันลง SharedPreferences
  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance(); // เข้าถึง SharedPreferences
    prefs.setString("cart_items", jsonEncode(_items)); // แปลงเป็น JSON แล้วบันทึก
  }

  // เพิ่มสินค้าเข้าตะกร้า
  // ถ้ามีสินค้าเดิมอยู่แล้วจะเพิ่มจำนวน
  void addItem(Map<String, dynamic> product) {
    final index = _items.indexWhere((item) => item["name"] == product["name"]);
    // ตรวจสอบว่าสินค้านี้มีอยู่ในตะกร้าแล้วหรือยัง

    if (index >= 0) {
      // ถ้ามีอยู่แล้ว ให้เพิ่มจำนวนเข้าไป
      _items[index]["quantity"] =
          (_items[index]["quantity"] ?? 1) + (product["quantity"] ?? 1);
    } else {
      // ถ้ายังไม่มี ให้เพิ่มสินค้าใหม่เข้ามาในตะกร้า
      _items.add({
        ...product, // คัดลอกข้อมูลจาก product เดิมทั้งหมด
        "quantity": product["quantity"] ?? 1, // ถ้าไม่มีจำนวน ให้ตั้งเป็น 1
      });
    }

    _saveCart(); // บันทึกข้อมูลใหม่ลง local storage
    notifyListeners(); // แจ้งให้ UI อัปเดต
  }

  // ลบสินค้าเฉพาะรายการออกจากตะกร้า ตามตำแหน่ง index
  void removeItem(int index) {
    _items.removeAt(index); // ลบรายการสินค้าตาม index
    _saveCart(); // บันทึกข้อมูลใหม่
    notifyListeners(); // อัปเดต UI
  }

  // ล้างตะกร้าทั้งหมด (ลบทุกสินค้าออก)
  void clearCart() {
    _items.clear(); // ลบข้อมูลทั้งหมด
    _saveCart(); // บันทึกตะกร้าที่ว่าง
    notifyListeners(); // อัปเดต UI
  }

  // เพิ่มจำนวนสินค้าของรายการที่เลือก (ตาม index)
  void increaseQuantity(int index) {
    if (index < 0 || index >= _items.length) return; // ตรวจสอบว่า index ถูกต้องไหม
    _items[index]["quantity"] = (_items[index]["quantity"] ?? 1) + 1; // บวกจำนวน +1
    _saveCart(); // บันทึก
    notifyListeners(); // แจ้งให้ UI อัปเดต
  }

  // ลดจำนวนสินค้า (ถ้าจำนวนเหลือ 1 แล้วลดอีก จะลบออกจากตะกร้า)
  void decreaseQuantity(int index) {
    if (index < 0 || index >= _items.length) return; // ตรวจสอบ index
    if ((_items[index]["quantity"] ?? 1) > 1) {
      // ถ้ามีมากกว่า 1 ชิ้นให้ลบออก 1 ชิ้น
      _items[index]["quantity"] = _items[index]["quantity"] - 1;
    } else {
      // ถ้ามีแค่ 1 ชิ้น ให้ลบออกจากตะกร้าเลย
      _items.removeAt(index);
    }
    _saveCart(); // บันทึกข้อมูลใหม่
    notifyListeners(); // อัปเดต UI
  }
}

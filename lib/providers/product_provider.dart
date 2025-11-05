import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// คลาส ProductProvider ใช้จัดการข้อมูลสินค้าในระบบ
// โดยเชื่อมต่อกับฐานข้อมูล Firestore และใช้ ChangeNotifier เพื่อให้ UI อัปเดตเมื่อข้อมูลเปลี่ยน
class ProductProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // เชื่อมต่อ Firestore

  // เก็บข้อมูลสินค้าล่าสุดไว้ในหน่วยความจำชั่วคราว (_products)
  List<Map<String, dynamic>> _products = [];

  // getter สำหรับให้ส่วนอื่นของแอปเรียกดูรายการสินค้าได้
  List<Map<String, dynamic>> get products => _products;

  // ดึงข้อมูลสินค้าทั้งหมดแบบ Real-time
  // ใช้ Stream เพื่อให้เมื่อมีการเปลี่ยนแปลงใน Firestore ระบบจะอัปเดตอัตโนมัติ
  Stream<List<Map<String, dynamic>>> getProductsStream() {
    return _firestore
        .collection('products') // เข้าถึง collection ชื่อ products
        .orderBy('name') // เรียงตามชื่อสินค้า
        .snapshots() // ฟังการเปลี่ยนแปลงแบบเรียลไทม์
        .map((snapshot) {
      // เมื่อมีข้อมูลใหม่จาก Firestore ให้แปลงเป็น List<Map>
      _products = snapshot.docs.map((doc) {
        final data = doc.data(); // ดึงข้อมูลสินค้าแต่ละรายการ
        data['id'] = doc.id; // เพิ่ม field id เพื่อเก็บรหัสเอกสารของ Firestore
        return data;
      }).toList();
      return _products; // ส่งคืนรายการสินค้าแบบ List<Map>
    });
  }

  // โหลดข้อมูลสินค้าทั้งหมดครั้งเดียว (ไม่เรียลไทม์)
  // ใช้ในกรณีที่ไม่ต้องการอัปเดตต่อเนื่องจาก Firestore
  Future<void> loadProducts() async {
    final snapshot =
        await _firestore.collection('products').orderBy('name').get(); // ดึงข้อมูลทั้งหมด
    _products = snapshot.docs.map((doc) {
      final data = doc.data(); // ดึงข้อมูลจากแต่ละเอกสาร
      data['id'] = doc.id; // เพิ่ม id ของเอกสารไว้ในข้อมูล
      return data;
    }).toList();
    notifyListeners(); // แจ้งให้ widget ที่ฟัง provider นี้อัปเดต
  }

  // เพิ่มสินค้าใหม่เข้า Firestore
  // รับข้อมูลสินค้าในรูปแบบ Map<String, dynamic>
  Future<void> addProduct(Map<String, dynamic> product) async {
    await _firestore.collection('products').add({
      "name": product["name"], // ชื่อสินค้า
      "price": product["price"], // ราคา
      "stock": product["stock"], // จำนวนคงเหลือ
      "image": product["image"], // URL รูปภาพสินค้า
      "createdAt": FieldValue.serverTimestamp(), // เวลาที่สร้างสินค้า
    });
  }

  // แก้ไขข้อมูลสินค้าใน Firestore ตาม productId ที่ระบุ
  Future<void> updateProduct(
      String productId, Map<String, dynamic> updatedProduct) async {
    await _firestore.collection('products').doc(productId).update({
      "name": updatedProduct["name"], // ชื่อสินค้าใหม่
      "price": updatedProduct["price"], // ราคาที่อัปเดต
      "stock": updatedProduct["stock"], // จำนวนคงเหลือใหม่
      "image": updatedProduct["image"], // รูปภาพที่อัปเดต
      "updatedAt": FieldValue.serverTimestamp(), // เวลาที่แก้ไขล่าสุด
    });
  }

  // ลบสินค้าออกจาก Firestore ตาม productId ที่ระบุ
  Future<void> deleteProduct(String productId) async {
    await _firestore.collection('products').doc(productId).delete();
  }
}

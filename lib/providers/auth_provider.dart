import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ===============================
// 🔐 จัดการ Authentication ด้วย Riverpod + Firebase
// ===============================

// ✅ คลาส AuthState ใช้เก็บสถานะผู้ใช้ (State)
class AuthState {
  final bool isAuthenticated; // บอกว่าเข้าสู่ระบบแล้วหรือยัง
  final bool isLoading; // บอกว่ากำลังประมวลผล (เช่น login/register)
  final String? error; // ข้อความ error ถ้ามี
  final String? role; // บทบาทผู้ใช้ เช่น admin / user
  final String? userName; // ชื่อผู้ใช้
  final String? email; // อีเมล
  final String? address; // ที่อยู่ (ใช้แสดงในหน้าโปรไฟล์)

  // ✅ กำหนดค่าพื้นฐานของ state
  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.role,
    this.userName,
    this.email,
    this.address,
  });

  // ✅ copyWith() สำหรับสร้าง state ใหม่โดยแก้ไขบางค่า
  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    String? role,
    String? userName,
    String? email,
    String? address,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      role: role ?? this.role,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      address: address ?? this.address,
    );
  }

  // ✅ สร้างค่าเริ่มต้น (ผู้ใช้ยังไม่ได้ login)
  factory AuthState.initial() => const AuthState(isAuthenticated: false);
}

// ===============================
// 🧠 AuthNotifier: ตัวจัดการ logic ทั้งหมดของ Auth
// ===============================
class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance; // ใช้ติดต่อ Firebase Auth
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // ใช้ติดต่อ Firestore

  // ✅ เริ่มต้นเมื่อ AuthNotifier ถูกสร้าง
  AuthNotifier() : super(AuthState.initial()) {
    // ฟัง event การเปลี่ยนแปลงของผู้ใช้ (เช่น login/logout)
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        // รอ 0.2 วินาทีเพื่อให้ Firestore sync ข้อมูลทัน
        await Future.delayed(const Duration(milliseconds: 200));

        // ดึงข้อมูลผู้ใช้จาก collection 'users'
        final doc = await _firestore.collection('users').doc(user.uid).get();
        final data = doc.data() ?? {};

        // ดึง role, name, address ถ้ามี
        final role = data['role'] ?? 'user';
        final name = data['name'] ?? user.displayName ?? "ผู้ใช้";
        final address = data['address'] ?? '';

        // ✅ อัปเดต state ของ AuthNotifier
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          userName: name,
          email: user.email,
          role: role,
          address: address,
          error: null,
        );

        print("✅ Auth Change → ${user.email} | Role: $role | UID: ${user.uid}");
      } else {
        // ถ้า user = null (ยังไม่ได้ login หรือ logout แล้ว)
        state = AuthState.initial();
        print("🚪 User logged out or not found");
      }
    });
  }

  // ===============================
  // 🟩 ฟังก์ชันสมัครสมาชิก (Register)
  // ===============================
  Future<bool> register(String name, String email, String password,
      {String? address}) async {
    try {
      state = state.copyWith(isLoading: true); // เริ่มโหลด

      // 🔹 สมัครสมาชิกใน Firebase Authentication
      await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      final user = _auth.currentUser!;
      await user.updateDisplayName(name); // อัปเดตชื่อใน Firebase profile

      // 🔹 บันทึกข้อมูลเพิ่มใน Firestore (collection 'users')
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'name': name,
        'role': 'user', // ค่าเริ่มต้น
        'createdAt': FieldValue.serverTimestamp(), // เวลาใน server
        'address': address ?? '',
      });

      // ✅ ปรับ state ในแอปให้ตรงกับข้อมูลล่าสุด
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        userName: name,
        email: email,
        role: "user",
        address: address ?? '',
      );

      print("🟢 Register success for $email");
      return true;
    } on FirebaseAuthException catch (e) {
      // ❌ ถ้าสมัครไม่สำเร็จ เช่น email ซ้ำ / password อ่อน
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? "สมัครสมาชิกไม่สำเร็จ",
      );
      print("🔴 Register failed: ${e.message}");
      return false;
    }
  }

  // ===============================
  // 🟦 ฟังก์ชันเข้าสู่ระบบ (Login)
  // ===============================
  Future<bool> login(String email, String password) async {
    try {
      state = state.copyWith(isLoading: true); // เริ่มโหลด

      // 🔹 เข้าสู่ระบบผ่าน Firebase Auth
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = _auth.currentUser!;

      // 🔹 ดึงข้อมูลเพิ่มเติมจาก Firestore (เช่น role / address)
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      final role = data['role'] ?? 'user';
      final name = data['name'] ?? user.displayName ?? "ผู้ใช้";

      // 🔹 ตรวจสอบ address (บางกรณี Firestore เก็บเป็น Map)
      final address = (data['address'] is Map)
          ? data['address']['line1'] ?? ''
          : '';

      // ✅ อัปเดต state ของ Auth
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        userName: name,
        email: user.email,
        role: role,
        address: address,
        error: null,
      );

      print("✅ Login success: ${user.email} | Role: $role");
      return true;
    } on FirebaseAuthException catch (e) {
      // ❌ ถ้าเข้าสู่ระบบล้มเหลว (เช่นรหัสผิด หรือไม่มีบัญชีนี้)
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? "เข้าสู่ระบบล้มเหลว",
      );
      print("🔴 Login error: ${e.message}");
      return false;
    }
  }

  // ===============================
  // 🚪 ฟังก์ชันออกจากระบบ (Logout)
  // ===============================
  Future<void> logout() async {
    await _auth.signOut(); // สั่ง Firebase ล็อกเอาท์
    state = AuthState.initial(); // รีเซ็ต state กลับค่าเริ่มต้น
    print("🚪 Logged out successfully");
  }

  // ===============================
  // 🏠 ฟังก์ชันอัปเดตที่อยู่ผู้ใช้ (ใช้ในหน้า Edit Profile)
  // ===============================
  Future<void> updateAddress(String newAddress) async {
    final user = _auth.currentUser;
    if (user == null) return; // ถ้ายังไม่ login ให้ออกเลย

    // 🔹 อัปเดตที่อยู่ใหม่ใน Firestore
    await _firestore.collection('users').doc(user.uid).update({
      'address.line1': newAddress,
    });

    // 🔹 อัปเดตใน state เพื่อให้ UI เปลี่ยนตาม
    state = state.copyWith(address: newAddress);
    print("🏠 Address updated → $newAddress");
  }
}

// ===============================
// 🧩 Provider หลักของระบบ Auth
// ใช้ใน Widget ได้เลย เช่น ref.watch(authProvider)
// ===============================
final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

import 'package:flutter/material.dart';
import 'package:flutter_application_1/providers/cart_provider.dart';
import 'package:flutter_application_1/providers/product_provider.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// import หน้าต่าง ๆ ของแอป เช่น หน้าล็อกอิน หน้าสินค้า หน้าผู้ดูแล
import 'screens/auth/profile.dart';
import 'screens/auth/login.dart';
import 'screens/auth/register.dart';
import 'screens/auth/edit_profile.dart';
import 'screens/auth/forgot_password.dart';
import 'screens/home/home.dart';
import 'screens/cart/cart.dart';
import 'screens/cart/checkout.dart';
import 'screens/owner/dashboard.dart';
import 'screens/owner/manage_product.dart';
import 'screens/owner/stock_screen.dart';
import 'screens/owner/sales_report_screen.dart';
import 'screens/owner/edit_product.dart';
import 'models/order.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/chat/chat_admin_screen.dart';
import 'screens/cart/order_history.dart';

// ตัวแปร plugin สำหรับจัดการ Local Notification (การแจ้งเตือนในเครื่อง)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ฟังก์ชัน callback เมื่อได้รับข้อความแจ้งเตือนขณะแอปปิดอยู่ (Background)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('แจ้งเตือนขณะปิดแอป: ${message.notification?.title}');
}

// ฟังก์ชันหลักของแอป (entry point)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // เตรียม Flutter ให้พร้อมก่อนใช้งาน plugin ต่าง ๆ

  // เชื่อมต่อ Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ตั้งค่า Notification สำหรับ Android
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // กำหนด handler สำหรับเมื่อแอปอยู่ใน background แล้วมีการแจ้งเตือน
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // รันแอป โดยใช้ Riverpod และ Provider ผสมกัน (จัดการ state)
  runApp(
    ProviderScope(
      child: provider.MultiProvider(
        providers: [
          provider.ChangeNotifierProvider(create: (_) => CartProvider()), // สำหรับตะกร้าสินค้า
          provider.ChangeNotifierProvider(create: (_) => ProductProvider()), // สำหรับข้อมูลสินค้า
        ],
        child: const MyApp(),
      ),
    ),
  );
}

// widget หลักของแอป
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

// ส่วนจัดการ state หลักของแอป
class _MyAppState extends State<MyApp> {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance; // ใช้จัดการ FCM (Firebase Cloud Messaging)

  @override
  void initState() {
    super.initState();
    _initFCM(); // เริ่มต้นระบบแจ้งเตือน
  }

  // ฟังก์ชันตั้งค่าและขอ permission สำหรับแจ้งเตือน
  Future<void> _initFCM() async {
    // ขออนุญาตให้แสดงการแจ้งเตือน (โดยเฉพาะใน iOS)
    await _messaging.requestPermission();

    // อนุญาตให้แสดงการแจ้งเตือนแม้ขณะแอปเปิดอยู่ (Foreground)
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // ดึง token ของอุปกรณ์ (ใช้ระบุตัวเครื่องเพื่อส่งแจ้งเตือนเฉพาะ)
    final token = await _messaging.getToken();
    debugPrint('Device Token: $token');

    // ตรวจสอบว่าผู้ใช้เป็น admin หรือไม่ ถ้าใช่ ให้บันทึก token ลงใน Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final docSnapshot = await userDoc.get();

        if (docSnapshot.exists) {
          final role = docSnapshot.data()?['role'];
          if (role == 'admin') {
            await userDoc.update({'fcmToken': token});
            debugPrint("อัปเดต fcmToken ของแอดมินเรียบร้อย");
          } else {
            debugPrint("ผู้ใช้ทั่วไป ไม่ต้องอัปเดต token แอดมิน");
          }
        }
      }
    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการบันทึก token: $e");
    }

    // ขณะเปิดแอป (Foreground) จะฟังข้อความแจ้งเตือนแบบเรียลไทม์
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('แจ้งเตือนขณะเปิดแอป: ${message.notification?.title}');
      final notification = message.notification;

      if (notification != null) {
        // แสดงแถบแจ้งเตือนจริง (ในระบบ)
        flutterLocalNotificationsPlugin.show(
          0,
          notification.title ?? "แจ้งเตือนใหม่",
          notification.body ?? "ไม่มีข้อความ",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'default_channel',
              'Speedway Notifications',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
          ),
        );

        // แสดง SnackBar ล่างจอ เพื่อแจ้งเตือนผู้ใช้ใน UI
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${notification.title ?? "แจ้งเตือน"}: ${notification.body ?? "ไม่มีข้อความ"}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.blueAccent,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(12),
            ),
          );
        }
      }
    });

    // เมื่อผู้ใช้กดที่แจ้งเตือนเพื่อเปิดแอป (จาก Background → Foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('เปิดแอปจากแจ้งเตือน: ${message.notification?.title}');
      if (message.data['type'] == 'order' && context.mounted) {
        Navigator.pushNamed(context, '/dashboard'); // ไปหน้า Dashboard ถ้าเป็นแจ้งเตือนคำสั่งซื้อ
      }
    });
  }

  // ส่วนสร้าง MaterialApp และกำหนดเส้นทาง (routes)
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speedway Store', // ชื่อแอป
      theme: ThemeData(
        primaryColor: const Color(0xFF1565C0), // สีหลักของแอป
        scaffoldBackgroundColor: const Color(0xFF0B3D91), // สีพื้นหลังทั่วไป
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFFFFD600), // สีรอง (ใช้ในปุ่มหรือ accent)
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFFFD600)),
          bodyMedium: TextStyle(color: Color(0xFFFFD600)),
          bodySmall: TextStyle(color: Color(0xFFFFD600)),
          titleLarge: TextStyle(
            color: Color(0xFFFFD600),
            fontWeight: FontWeight.bold,
          ),
          titleMedium: TextStyle(color: Color(0xFFFFD600)),
        ),
      ),

      // หน้าแรกที่แสดงเมื่อเปิดแอป
      initialRoute: '/home',

      // เส้นทางทั้งหมดในแอป
      routes: {
        '/home': (_) => const HomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/cart': (_) => const CartScreen(),
        '/checkout': (_) => const CheckoutScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/manageproducts': (_) => const ManageProductScreen(),
        '/stock': (_) => const StockScreen(),
        '/sales-report': (_) => const SalesReportScreen(),
        '/orders': (_) => const OrderScreen(),
        '/chat': (_) => const ChatScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/edit-profile': (_) => const EditProfileScreen(),
        '/chat-admin': (_) => const ChatAdminScreen(),
        '/order-history': (context) => const OrderHistoryScreen(),
        '/edit-product': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return EditProductScreen(
            product: args["product"].cast<String, dynamic>(),
          );
        },
      },
    );
  }
}

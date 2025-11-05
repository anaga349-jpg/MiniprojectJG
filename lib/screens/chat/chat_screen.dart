import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// ✅ หน้าสนทนาระหว่าง “ลูกค้า” และ “แอดมิน”
/// ผู้ใช้จะส่งข้อความหรือภาพไปยัง collection ของตนเองใน Firestore.
/// โครงสร้างข้อมูล:
/// ─ chats (collection)
///    └── [user.uid] (document)
///        ├── lastMessage: String
///        ├── updatedAt: Timestamp
///        ├── unreadByAdmin: bool
///        ├── unreadByUser: bool
///        └── messages (subcollection)
///            ├── [autoDocId]
///            │     ├── sender: 'user' | 'admin'
///            │     ├── text: String
///            │     ├── imageUrl: String
///            │     ├── timestamp: Timestamp
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // --------------------------------------------------------
  // 🔧 ตัวแปรและ service หลักของระบบ
  // --------------------------------------------------------
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _controller = TextEditingController();
  final _picker = ImagePicker();

  // --------------------------------------------------------
  // 💬 ฟังก์ชันส่งข้อความ (ทั้งข้อความและภาพ)
  // --------------------------------------------------------
  Future<void> _sendMessage({String? imageUrl}) async {
    final user = _auth.currentUser;
    final text = _controller.text.trim();

    // 🔸 ป้องกันการส่งข้อความว่าง
    if (user == null || (text.isEmpty && imageUrl == null)) return;

    // 🔹 ชี้ document ของผู้ใช้ใน collection "chats"
    final chatRef = _firestore.collection('chats').doc(user.uid);
    final messageRef = chatRef.collection('messages').doc();

    // 🔹 อัปเดตหัวข้อแชต (lastMessage)
    await chatRef.set({
      'userName': user.displayName ?? user.email,
      'lastMessage': imageUrl != null ? '[📷 ส่งรูปภาพ]' : text,
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadByAdmin': true, // บอกว่าแอดมินยังไม่ได้อ่าน
      'unreadByUser': false, // ฝั่งผู้ใช้คือผู้ส่ง
    }, SetOptions(merge: true));

    // 🔹 เพิ่มข้อความจริงเข้า subcollection messages
    await messageRef.set({
      'sender': 'user',
      'text': text,
      'imageUrl': imageUrl ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });

    _controller.clear(); // เคลียร์ช่องพิมพ์หลังส่ง
  }

  // --------------------------------------------------------
  // 📷 ฟังก์ชันแนบรูปภาพ (เลือกจากแกลเลอรี)
  // --------------------------------------------------------
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storageRef =
        FirebaseStorage.instance.ref().child('chat_images/$fileName');

    // 🔹 แสดงวงกลมโหลดระหว่างอัปโหลด
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    try {
      // ✅ อัปโหลดไฟล์ไป Firebase Storage
      await storageRef.putFile(file);
      final imageUrl = await storageRef.getDownloadURL();

      if (context.mounted) Navigator.pop(context); // ปิดโหลด
      await _sendMessage(imageUrl: imageUrl); // ส่งลิงก์ภาพเป็นข้อความ
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("อัปโหลดรูปภาพไม่สำเร็จ: $e")),
      );
    }
  }

  // --------------------------------------------------------
  // 🧩 ส่วน UI หลัก
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFD600),
        centerTitle: true,
        elevation: 3,
        title: const Text(
          "💬 Chat Admin",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),

      // โครงสร้างหลักแบ่งเป็น 2 ส่วน: (1) ข้อความ (2) ช่องส่งข้อความ
      body: Column(
        children: [
          // --------------------------------------------------------
          // 📨 ส่วนแสดงรายการข้อความ (StreamBuilder)
          // --------------------------------------------------------
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(user?.uid)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "ยังไม่มีข้อความ",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                // ✅ แสดงข้อความแต่ละบับเบิลแบบเรียงตามเวลา
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isUser = msg['sender'] == 'user';
                    final imageUrl = msg['imageUrl'] ?? '';
                    final timestamp = msg['timestamp'] as Timestamp?;
                    final time = timestamp != null
                        ? DateFormat('HH:mm').format(timestamp.toDate())
                        : '';

                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: isUser
                              ? const Color(0xFF4A6FB1)
                              : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(isUser ? 14 : 0),
                            bottomRight: Radius.circular(isUser ? 0 : 14),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),

                        // ---------------------------------------------
                        // เนื้อหาภายใน bubble (รูปภาพ + ข้อความ + เวลา)
                        // ---------------------------------------------
                        child: Column(
                          crossAxisAlignment: isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            // 📷 ถ้ามีรูปภาพ
                            if (imageUrl.isNotEmpty)
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullImageView(imageUrl),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    imageUrl,
                                    width: 220,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, progress) {
                                      if (progress == null) return child;
                                      return const SizedBox(
                                        height: 180,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                              color: Colors.amber),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image,
                                      color: Colors.redAccent,
                                      size: 50,
                                    ),
                                  ),
                                ),
                              ),

                            // 📝 ข้อความ (text)
                            if (msg['text'] != null &&
                                msg['text'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  msg['text'],
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                    color: isUser
                                        ? Colors.white
                                        : const Color(0xFF1B3C73),
                                  ),
                                ),
                              ),

                            // ⏰ เวลา (timestamp)
                            const SizedBox(height: 4),
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    isUser ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // --------------------------------------------------------
          // 📩 ช่องพิมพ์ข้อความ + ปุ่มแนบรูป
          // --------------------------------------------------------
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.black12),
                ),
              ),
              child: Row(
                children: [
                  // 📷 ปุ่มแนบรูป
                  IconButton(
                    icon: const Icon(Icons.photo, color: Color(0xFF1B3C73)),
                    tooltip: "แนบรูปภาพ",
                    onPressed: _pickImage,
                  ),
                  // ✏️ ช่องพิมพ์ข้อความ
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: "พิมพ์ข้อความถึงแอดมิน...",
                        hintStyle: TextStyle(
                            color: Colors.grey.shade600, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  // 🚀 ปุ่มส่งข้อความ
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF1B3C73)),
                    tooltip: "ส่งข้อความ",
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------
// 🖼️ หน้าดูภาพเต็มจอ (รองรับ pinch zoom / scroll)
// --------------------------------------------------------
class FullImageView extends StatelessWidget {
  final String imageUrl;
  const FullImageView(this.imageUrl, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          panEnabled: true,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image,
              color: Colors.redAccent,
              size: 80,
            ),
          ),
        ),
      ),
    );
  }
}

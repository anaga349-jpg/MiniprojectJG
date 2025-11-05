import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// ✅ หน้ารายละเอียดแชตสำหรับ “ผู้ดูแลระบบ”
/// ใช้สำหรับดูและตอบข้อความของลูกค้าแบบ real-time
/// รับพารามิเตอร์ userId และ userName จากหน้ารวมรายชื่อผู้ใช้ (ChatListScreen)
class ChatDetailScreen extends StatefulWidget {
  final String userId;    // UID ของลูกค้า
  final String userName;  // ชื่อ/อีเมลลูกค้า (ไว้โชว์ใน AppBar)

  const ChatDetailScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _controller = TextEditingController();
  final _picker = ImagePicker();

  // --------------------------------------------------------
  // 🟨 initState: mark ว่าข้อความของลูกค้าถูกอ่านแล้ว
  // --------------------------------------------------------
  @override
  void initState() {
    super.initState();

    // ✅ อัปเดตสถานะ unreadByAdmin = false เพื่อให้ฝั่งผู้ใช้เห็นว่า admin อ่านแล้ว
    _firestore
        .collection('chats')
        .doc(widget.userId)
        .update({'unreadByAdmin': false});
  }

  // --------------------------------------------------------
  // 💬 ฟังก์ชันส่งข้อความ / ภาพจากฝั่งแอดมิน
  // --------------------------------------------------------
  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _controller.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    // 🔹 กำหนด document ของ userId ที่แอดมินกำลังคุยด้วย
    final chatRef = _firestore.collection('chats').doc(widget.userId);
    final messageRef = chatRef.collection('messages').doc();

    // 🔹 อัปเดตหัวข้อแชตหลัก (ใช้ในการแสดง list ของผู้ใช้ทั้งหมด)
    await chatRef.set({
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': imageUrl != null ? '[📷 ส่งรูปภาพ]' : text,
      'unreadByUser': true,  // แจ้งให้ฝั่ง user ทราบว่ามีข้อความใหม่
      'unreadByAdmin': false,
    }, SetOptions(merge: true));

    // 🔹 เพิ่มข้อความใหม่เข้า subcollection messages
    await messageRef.set({
      'sender': 'admin',
      'text': text,
      'imageUrl': imageUrl ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });

    _controller.clear();
  }

  // --------------------------------------------------------
  // 📸 ฟังก์ชันแนบรูปจากแกลเลอรี (แอดมินส่งภาพได้ด้วย)
  // --------------------------------------------------------
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storageRef =
        FirebaseStorage.instance.ref().child('chat_images/$fileName');

    // 🔹 แสดงโหลดระหว่างอัปโหลด
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    try {
      // ✅ อัปโหลดไป Firebase Storage
      await storageRef.putFile(file);
      final imageUrl = await storageRef.getDownloadURL();

      if (context.mounted) Navigator.pop(context);
      await _sendMessage(imageUrl: imageUrl);
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ: $e")),
      );
    }
  }

  // --------------------------------------------------------
  // 🧩 UI หลักของหน้าสนทนา (ฝั่งแอดมิน)
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFD600),
        centerTitle: true,
        elevation: 3,
        title: Text(
          "💬 Chat with ${widget.userName}",
          style:
              const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // --------------------------------------------------------
          // 📡 StreamBuilder: ดึงข้อความจาก Firestore แบบเรียลไทม์
          // --------------------------------------------------------
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(widget.userId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.yellow));
                }

                final messages = snapshot.data!.docs;
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      "ยังไม่มีข้อความ",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  );
                }

                // ✅ แสดงรายการข้อความ (เหมือนฝั่ง user แต่กลับสี)
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isAdmin = msg['sender'] == 'admin';
                    final imageUrl = msg['imageUrl'] ?? '';
                    final text = msg['text'] ?? '';
                    final timestamp = msg['timestamp'] as Timestamp?;
                    final time = timestamp != null
                        ? DateFormat('HH:mm').format(timestamp.toDate())
                        : '';

                    return Align(
                      alignment:
                          isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? const Color(0xFFFFD600)
                              : Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(isAdmin ? 14 : 0),
                            bottomRight: Radius.circular(isAdmin ? 0 : 14),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        // ---------------- เนื้อหาใน bubble ----------------
                        child: Column(
                          crossAxisAlignment: isAdmin
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            // 🖼️ รูปภาพ (แตะเพื่อดูเต็มจอ)
                            if (imageUrl.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FullImageView(imageUrl),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    imageUrl,
                                    width: 220,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, progress) {
                                      if (progress == null) return child;
                                      return SizedBox(
                                        height: 180,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: progress.expectedTotalBytes !=
                                                    null
                                                ? progress.cumulativeBytesLoaded /
                                                    (progress
                                                            .expectedTotalBytes ??
                                                        1)
                                                : null,
                                            color: Colors.amber,
                                          ),
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

                            // 📝 ข้อความ
                            if (text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                    color: isAdmin
                                        ? Colors.black
                                        : const Color(0xFF1B3C73),
                                  ),
                                ),
                              ),

                            // ⏰ เวลา
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                time,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isAdmin
                                      ? Colors.black54
                                      : Colors.grey[600],
                                ),
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
          // ✏️ กล่องพิมพ์ข้อความและปุ่มส่ง
          // --------------------------------------------------------
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo, color: Color(0xFF1B3C73)),
                    tooltip: "แนบรูปภาพ",
                    onPressed: _pickImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        hintText: "พิมพ์ข้อความถึงลูกค้า...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
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
// 🖼️ หน้าแสดงภาพแบบเต็มจอ (zoom, pan ได้)
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

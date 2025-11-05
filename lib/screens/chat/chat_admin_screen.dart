import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

// หน้าหลักของฝั่งแอดมิน แสดงรายชื่อผู้ใช้ทั้งหมดที่เคยคุยในแชต
class ChatAdminScreen extends StatelessWidget {
  const ChatAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // เชื่อมต่อกับ Firestore เพื่อใช้ดึงข้อมูลแบบเรียลไทม์
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFD600),
        title: const Text(
          "📨 Customer Messages",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 3,
      ),

      // StreamBuilder ใช้ฟังการเปลี่ยนแปลงข้อมูลแบบเรียลไทม์จาก Firestore
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('chats')
            .orderBy('updatedAt', descending: true) // เรียงตามเวลาล่าสุด
            .snapshots(),
        builder: (context, snapshot) {
          // ถ้ายังโหลดข้อมูลอยู่ จะแสดงวงกลมโหลด
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.yellow));
          }

          // ถ้าไม่มีข้อมูลหรือไม่มีแชตเลย
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "ยังไม่มีลูกค้าส่งข้อความมา",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          // เก็บเอกสารทั้งหมดจาก collection "chats"
          final users = snapshot.data!.docs;

          // สร้างรายชื่อผู้ใช้ใน ListView
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            itemBuilder: (context, index) {
              // ดึงข้อมูลแต่ละเอกสารมาเป็น Map
              final user = users[index].data() as Map<String, dynamic>;
              final userName = user['userName'] ?? "ลูกค้า";

              // แปลงเวลาจาก Timestamp ให้แสดงเป็นรูปแบบ dd/MM HH:mm
              final updatedAt = (user['updatedAt'] as Timestamp?)?.toDate();
              final formattedTime = updatedAt != null
                  ? DateFormat('dd/MM HH:mm').format(updatedAt)
                  : "—";

              // ตรวจสอบว่ามีข้อความที่ยังไม่ได้อ่านโดยแอดมินหรือไม่
              final unread = user['unreadByAdmin'] == true;

              // FutureBuilder ใช้ดึง "ข้อความล่าสุด" ของแต่ละผู้ใช้ (เพียง 1 ข้อความ)
              return FutureBuilder<QuerySnapshot>(
                future: firestore
                    .collection('chats')
                    .doc(users[index].id)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .get(),
                builder: (context, lastMsgSnapshot) {
                  String lastMessage = "ยังไม่มีข้อความ";
                  if (lastMsgSnapshot.hasData &&
                      lastMsgSnapshot.data!.docs.isNotEmpty) {
                    // ดึงข้อความล่าสุดใน subcollection messages
                    final msg = lastMsgSnapshot.data!.docs.first.data()
                        as Map<String, dynamic>;

                    // ถ้าเป็นรูปภาพ ให้แสดงแทนข้อความว่า "[📷 ส่งรูปภาพ]"
                    if (msg['imageUrl'] != null && msg['imageUrl'] != '') {
                      lastMessage = "[📷 ส่งรูปภาพ]";
                    } else {
                      lastMessage = msg['text'] ?? "ไม่มีข้อความ";
                    }
                  }

                  // แสดงการ์ดแต่ละรายการของลูกค้า
                  return Card(
                    color: unread ? Colors.yellow[100] : Colors.white,
                    elevation: unread ? 5 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xFF1E88E5),
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(
                        userName,
                        style: TextStyle(
                          fontWeight:
                              unread ? FontWeight.bold : FontWeight.normal,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unread ? Colors.black : Colors.black54,
                          fontStyle:
                              unread ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            formattedTime,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            Icons.chat_bubble_outline,
                            color: unread
                                ? Colors.redAccent
                                : const Color(0xFF1E88E5),
                          ),
                        ],
                      ),

                      // เมื่อแตะที่รายการ จะเปิดหน้าคุยกับลูกค้าคนนั้น
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatDetailScreen(
                              userId: users[index].id,
                              userName: userName,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// หน้าสนทนาแบบละเอียดของแอดมินกับลูกค้ารายคน
class ChatDetailScreen extends StatefulWidget {
  final String userId;
  final String userName;

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

  @override
  void initState() {
    super.initState();
    // เมื่อเปิดห้องแชต จะ mark ว่าแอดมินอ่านข้อความแล้ว
    _firestore
        .collection('chats')
        .doc(widget.userId)
        .update({'unreadByAdmin': false});
  }

  // ฟังก์ชันส่งข้อความ (ข้อความหรือรูปภาพ)
  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _controller.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    // อ้างอิงถึงเอกสารของลูกค้าใน collection "chats"
    final chatRef = _firestore.collection('chats').doc(widget.userId);
    // สร้างเอกสารใหม่ใน subcollection "messages"
    final messageRef = chatRef.collection('messages').doc();

    // อัปเดตข้อมูลระดับห้องแชต เช่น ข้อความล่าสุด เวลา และสถานะอ่าน
    await chatRef.set({
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': imageUrl != null ? '[📷 ส่งรูปภาพ]' : text,
      'unreadByUser': true,
      'unreadByAdmin': false,
    }, SetOptions(merge: true));

    // เพิ่มข้อความใหม่ใน subcollection messages
    await messageRef.set({
      'sender': 'admin',
      'text': text,
      'imageUrl': imageUrl ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });

    _controller.clear(); // ล้างกล่องข้อความหลังส่ง
  }

  // ฟังก์ชันแนบรูปภาพจากเครื่องและอัปโหลดไป Firebase Storage
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storageRef =
        FirebaseStorage.instance.ref().child('chat_images/$fileName');

    // แสดงหน้ารอโหลดขณะอัปโหลด
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.yellow)),
    );

    try {
      await storageRef.putFile(file); // อัปโหลดรูปไป Storage
      final imageUrl = await storageRef.getDownloadURL(); // ดึง URL
      if (mounted) Navigator.pop(context); // ปิด dialog
      await _sendMessage(imageUrl: imageUrl); // ส่งข้อความพร้อมรูป
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("อัปโหลดรูปภาพไม่สำเร็จ: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFD600),
        centerTitle: true,
        title: Text(
          "💬 Chat with ${widget.userName}",
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // ส่วนแสดงข้อความแชตแบบเรียลไทม์
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
                      child: CircularProgressIndicator(color: Colors.amber));
                }

                final messages = snapshot.data!.docs;
                if (messages.isEmpty) {
                  return const Center(
                    child: Text("ยังไม่มีข้อความ",
                        style: TextStyle(color: Colors.white)),
                  );
                }

                // แสดงข้อความทั้งหมดใน ListView
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

                    // กล่องข้อความแต่ละบับเบิ้ล
                    return Align(
                      alignment: isAdmin
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? const Color(0xFFFFD600)
                              : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(isAdmin ? 14 : 0),
                            bottomRight: Radius.circular(isAdmin ? 0 : 14),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isAdmin
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            // ถ้ามีรูปภาพในข้อความ จะแสดงภาพพร้อมโหลดสถานะ
                            if (imageUrl.isNotEmpty)
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullImageView(imageUrl),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
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
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.broken_image,
                                            color: Colors.redAccent),
                                  ),
                                ),
                              ),
                            // ถ้ามีข้อความ จะถูกแสดงใต้รูป
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
                            // แสดงเวลาส่งข้อความ
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

          // ช่องพิมพ์ข้อความและแนบรูปภาพด้านล่าง
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

// หน้าดูรูปภาพแบบเต็มหน้าจอ สามารถซูมเข้าออกได้
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
          panEnabled: true, // อนุญาตให้เลื่อนภาพ
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

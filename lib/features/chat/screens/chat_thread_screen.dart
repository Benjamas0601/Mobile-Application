import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/chat_message_model.dart';
import '../../../models/chat_thread_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../widgets/state_views.dart';


//ไฟลืนี้เป็นไฟล์ที่เก็บหน้าจอคุยกับร้านของผู้ใช้ โดยแสดงฟองข้อความของผู้ใช้และร้าน แถบพิมพ์ข้อความด้านล่าง และปุ่มส่งข้อความ และสามารถเลื่อนดูข้อความล่าสุดได้
/// One conversation. Reads the room (for the title and the unread counter) and
/// its message stream live, and writes a new message through
/// [sendChatMessageProvider].
///
/// The input bar stays visible even on an empty room: a thread is created the
/// moment the buyer taps "ส่งข้อความถึงร้าน", before any text exists.
/// หน้าคุย: ฟองข้อความ + แถบพิมพ์ ส่งแล้วเลื่อนลงล่าสุด และนับอ่านอัตโนมัติ
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// `ref.listen` ใช้ได้เฉพาะใน build — ที่นี่ต้องใช้ listenManual และปิดเอง
  ProviderSubscription<AsyncValue<List<ChatMessageModel>>>? _messagesSub;

  @override
  void initState() {
    super.initState();
    _markRead();
    _messagesSub = ref.listenManual<AsyncValue<List<ChatMessageModel>>>(
      chatMessagesProvider(widget.threadId),
      (_, _) {
        _markRead();
        _scrollToLatest();
      },
    );
  }

  @override
  void dispose() {
    _messagesSub?.close();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// ทำเครื่องหมายว่าอ่านแล้วทุกครั้งที่มีข้อความใหม่เข้ามาขณะเปิดหน้าอยู่
  /// เพื่อให้ออกจากหน้าไปโดยไม่เหลือข้อความที่ยังไม่อ่าน
  Future<void> _markRead() async {
    try {
      await ref.read(chatRepositoryProvider).markThreadRead(widget.threadId);
    } on Object {
      // best-effort: ล้างป้ายไม่สำเร็จก็ไม่ควรขึ้น error
    }
  }

  /// เลื่อนไปข้อความล่าสุดหลังเฟรมวาดเสร็จ
  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final String text = _input.text;
    final bool sent = await ref
        .read(sendChatMessageProvider.notifier)
        .send(threadId: widget.threadId, text: text);
    if (sent) {
      // หน้าอาจถูก pop ไปก่อน async ส่งเสร็จ — controller ถูก dispose แล้ว
      if (mounted) _input.clear();
      return;
    }
    // `sent == false` หมายถึงกดส่งซ้ำ (ข้อความยังอยู่ ไม่หาย) หรือช่องว่าง
    // จะเตือนเฉพาะเมื่อช่องมีข้อความจริง
    if (mounted && text.trim().isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text(AppStrings.chatSendFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ChatThreadModel?> threadState = ref.watch(
      chatThreadProvider(widget.threadId),
    );
    final AsyncValue<List<ChatMessageModel>> messages = ref.watch(
      chatMessagesProvider(widget.threadId),
    );
    final String myUid = ref.watch(authUserProvider).asData?.value?.uid ?? '';

    final String title = threadState.value?.storeName ?? AppStrings.chat;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: <Widget>[
          Expanded(
            child: messages.when(
              loading: () => const LoadingView(),
              error: (Object e, StackTrace _) => ErrorView(
                message: '${AppStrings.errorBody}: $e',
                onRetry: () => ref.invalidate(
                  chatMessagesProvider(widget.threadId),
                ),
              ),
              data: (List<ChatMessageModel> list) {
                if (list.isEmpty) {
                  return const EmptyView(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: AppStrings.chatEmptyRoom,
                    body: AppStrings.chatEmptyRoomHint,
                    compact: true,
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  itemCount: list.length,
                  itemBuilder: (BuildContext context, int index) => _Bubble(
                    message: list[index],
                    mine: list[index].isMine(myUid),
                  ),
                );
              },
            ),
          ),
          _Composer(controller: _input, onSend: _send),
        ],
      ),
    );
  }
}

/// แถบพิมพ์ข้อความด้านล่าง พร้อมปุ่มส่งกลม
class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: AppStrings.messageHint,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.pillRadius,
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.pillRadius,
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: onSend,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(14),
                minimumSize: const Size.square(48),
              ),
              child: const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// ฟองข้อความหนึ่งอัน ข้อความของตัวเองชิดขวาด้วยสีแบรนด์ ส่วนของคู่อีกฝั่ง
/// ชิดซ้ายด้วยสีหม่น พร้อมชื่อผู้ส่งเมื่อมี
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final ChatMessageModel message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          if (!mine && message.senderName.isNotEmpty) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: mine ? AppColors.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppRadius.lg),
                topRight: const Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(mine ? AppRadius.lg : 4),
                bottomRight: Radius.circular(mine ? 4 : AppRadius.lg),
              ),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: mine ? AppColors.onPrimary : scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
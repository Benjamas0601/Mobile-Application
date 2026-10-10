import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/chat_thread_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../widgets/state_views.dart';

/// The conversation inbox for both roles.
///
/// The same Firestore query serves the buyer and the seller:
/// `chat_threads where participantUids arrayContains me`, ordered by last
/// activity. The row therefore has to guess which title the other party wants:
/// buyers see the store name, and a seller sees the buyer's display name when
/// the sender name is on the thread (the store's own name would be unhelpful).
/// แสดงรายการห้องแชทของผู้ซื้อ/ผู้ขายเรียงตามข้อความล่าสุด
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String myUid = ref.watch(authUserProvider).asData?.value?.uid ?? '';
    final AsyncValue<List<ChatThreadModel>> threads = ref.watch(
      myChatThreadsProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.chat)),
      body: threads.when(
        loading: () => const LoadingView(),
        error: (Object e, StackTrace _) => ErrorView(
          message: AppStrings.errorBody,
          onRetry: () => ref.invalidate(myChatThreadsProvider),
        ),
        data: (List<ChatThreadModel> rooms) {
          if (rooms.isEmpty) {
            return const EmptyView(
              icon: Icons.forum_outlined,
              title: AppStrings.chatNoConversations,
              body: AppStrings.chatNoConversationsHint,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: rooms.length,
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(height: 1, indent: AppSpacing.xl),
            itemBuilder: (BuildContext context, int index) {
              final ChatThreadModel thread = rooms[index];
              return _ThreadRow(
                thread: thread,
                myUid: myUid,
                onTap: () => _open(context, ref, thread),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ChatThreadModel thread,
  ) async {
    // ล้างตัวนับก่อนนำทาง เพื่อไม่ให้ป้ายกระพริบตอนออกจากหน้า
    // การบันทึกว่าอ่านแล้วเป็น best-effort เขียน
    try {
      await ref.read(chatRepositoryProvider).markThreadRead(thread.id);
    } on Object {
      // ล้างไม่สำเร็จก็ไม่ควรบล็อกการเปิดห้อง
    }
    if (context.mounted) context.push(AppRoutes.chatThread(thread.id));
  }
}

/// แถวห้องแชทในรายการ แสดงชื่อร้าน ตัวอย่างข้อความ เวลา และป้ายยังไม่อ่าน
class _ThreadRow extends StatelessWidget {
  const _ThreadRow({
    required this.thread,
    required this.myUid,
    required this.onTap,
  });

  final ChatThreadModel thread;
  final String myUid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // thread รู้จักร้านเสมอ ถ้าผู้ซื้อของห้องคือผู้ขายที่ล็อกอินอยู่ (ห้องที่ลูกค้า
    // เปิด) ก็ให้แสดงชื่อร้านอยู่ดี เพราะเป็นธรรมเนียมของมาร์เก็ตเพลส
    final String title = thread.storeName.isEmpty
        ? (thread.storeId.isEmpty ? AppStrings.chat : 'ร้านค้า')
        : thread.storeName;

    // ฝั่งผู้ขาย คู่สนทนาคือผู้ซื้อ ซึ่งชื่อติดมากับข้อความแรก ถ้าไม่มีให้ย้อนไปใช้
    // ชื่อร้านแทน
    final String preview = thread.isEmpty
        ? AppStrings.chatNoConversations
        : thread.lastMessage;

    return Semantics(
      button: true,
      label: '$title — $preview',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              // อวตาร: ใช้สัญลักษณ์ร้านก็พอสำหรับห้องในมาร์เก็ตเพลส
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          _relative(thread.lastAt),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      preview,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: thread.hasUnreadFor(myUid)
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: thread.hasUnreadFor(myUid)
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (thread.hasUnreadFor(myUid)) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                _UnreadBadge(count: thread.unreadFor(myUid)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// `2 ชั่วโมงที่แล้ว` — the same relative stamp the seller dashboard uses.
  static String _relative(DateTime created) {
    final Duration age = DateTime.now().difference(created);
    if (age.inMinutes < 1) return 'เมื่อสักครู่';
    if (age.inMinutes < 60) return '${age.inMinutes} นาที';
    if (age.inHours < 24) return '${age.inHours} ชั่วโมง';
    return '${age.inDays} วัน';
  }
}

/// ป้ายตัวเลขยังไม่อ่าน (แสดง 99+ เมื่อเกิน 99)
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: AppColors.onPrimary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart' hide AsyncValue;
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/coupon_model.dart';
import '../../../models/store_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/coupon_provider.dart';
import '../../../widgets/state_views.dart';
import '../providers/admin_provider.dart'; 

/// หน้าจอผู้ดูแลสำหรับตรวจและจัดการข้อมูลหลักตามสิทธิ์ admin
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override 
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserModel?> auth = ref.watch(authUserProvider);
    final UserModel? user = auth.value;
    if (auth.isLoading) {
      return const Scaffold(body: LoadingView());
    }
    if (user?.isAdmin != true) {
      return Scaffold(
        body: EmptyView(
          icon: Icons.lock_outline_rounded,
          title: 'ไม่มีสิทธิ์เข้าถึง',
          body: 'หน้านี้สำหรับผู้ดูแลระบบเท่านั้น',
          actionLabel: AppStrings.backToHome,
          onAction: () => context.go(AppRoutes.home),
          secondaryActionLabel: AppStrings.logout,
          onSecondaryAction: () => ref.read(authRepositoryProvider).signOut(),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: AppSpacing.gutter,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('จัดการระบบ', style: AppTextStyles.headlineSmall),
              Text(
                '${user!.shortName} · ผู้ดูแลระบบ',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'ดูตลาด OTOP',
              icon: const Icon(Icons.storefront_outlined),
              onPressed: () => context.push(AppRoutes.stores),
            ),
            IconButton(
              tooltip: 'ออกจากระบบ',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(icon: Icon(Icons.store_outlined), text: 'ร้านค้า'),
              Tab(icon: Icon(Icons.people_outline_rounded), text: 'ผู้ใช้'),
              Tab(icon: Icon(Icons.local_offer_outlined), text: 'คูปอง'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[_StoresTab(), _UsersTab(), _CouponsTab()],
        ),
      ),
    );
  }
}

class _StoresTab extends ConsumerStatefulWidget {
  const _StoresTab();

  @override
  ConsumerState<_StoresTab> createState() => _StoresTabState();
}

class _StoresTabState extends ConsumerState<_StoresTab> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String? _deletingId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(adminStoresProvider)
        .when(
          loading: () => const LoadingView(),
          error: (Object error, StackTrace stack) => ErrorView(
            message: '$error',
            onRetry: () => ref.invalidate(adminStoresProvider),
          ),
          data: (List<StoreModel> stores) {
            final List<StoreModel> visible = stores.where((StoreModel store) {
              final String value = <String>[
                store.name,
                store.province,
                store.region,
                store.community,
                store.ownerUid,
              ].join(' ').toLowerCase();
              return value.contains(_search.toLowerCase());
            }).toList();

            return Column(
              children: <Widget>[
                _SearchBox(
                  controller: _searchController,
                  onChanged: (String value) => setState(() => _search = value),
                  hint: 'ค้นหาร้านหรือจังหวัด',
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(adminStoresProvider);
                    },
                    child: visible.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: <Widget>[
                              SizedBox(
                                height: 300,
                                child: EmptyView(
                                  icon: Icons.store_outlined,
                                  title: _search.isEmpty
                                      ? 'ยังไม่มีร้านค้า'
                                      : 'ไม่พบร้านค้าที่ค้นหา',
                                  body: _search.isEmpty
                                      ? 'ร้านค้าที่ลงทะเบียนจะแสดงในหน้านี้'
                                      : 'ลองค้นหาด้วยชื่อร้าน ชุมชน หรือจังหวัด',
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(
                              left: AppSpacing.gutter,
                              right: AppSpacing.gutter,
                              bottom: AppSpacing.xxl,
                            ),
                            itemCount: visible.length,
                            separatorBuilder:
                                (BuildContext context, int index) =>
                                    const Divider(height: 1),
                            itemBuilder: (BuildContext context, int index) {
                              final StoreModel store = visible[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(
                                  child: Icon(Icons.storefront_outlined),
                                ),
                                title: Text(
                                  store.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  <String>[
                                    if (store.community.isNotEmpty)
                                      store.community,
                                    if (store.province.isNotEmpty)
                                      store.province,
                                    if (store.otopCertified) 'OTOP รับรอง',
                                  ].join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    IconButton(
                                      tooltip: 'แก้ไขข้อมูลร้าน',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _editStore(store),
                                    ),
                                    IconButton(
                                      tooltip: 'ลบร้านค้า',
                                      icon: _deletingId == store.id
                                          ? const SizedBox.square(
                                              dimension: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.delete_outline_rounded,
                                              color: AppColors.danger,
                                            ),
                                      onPressed: _deletingId == store.id
                                          ? null
                                          : () => _deleteStore(store),
                                    ),
                                  ],
                                ),
                                onTap: () => _showStoreDetails(store),
                              );
                            },
                          ),
                  ),
                ),
              ],
            );
          },
        );
  }

  Future<void> _showStoreDetails(StoreModel store) async {
    final bool? edit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(store.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _DetailLine('ผู้ดูแลร้าน', store.ownerUid),
              _DetailLine('ชุมชน', store.community),
              _DetailLine('จังหวัด', store.province),
              _DetailLine('ภูมิภาค', _regionLabel(store.region)),
              _DetailLine('รายละเอียด', store.description),
              _DetailLine(
                'การรับรอง OTOP',
                store.otopCertified ? 'รับรองแล้ว' : 'ยังไม่รับรอง',
              ),
              _DetailLine(
                'คะแนน',
                '${store.ratingAvg.toStringAsFixed(1)} (${store.ratingCount})',
              ),
              _DetailLine(
                'ค่าคอมมิชชัน',
                '${(store.commissionRate * 100).toStringAsFixed(1)}%',
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('แก้ข้อมูล'),
          ),
        ],
      ),
    );
    if (edit == true) await _editStore(store);
  }

  Future<void> _editStore(StoreModel store) async { 
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => _StoreEditor(store: store),
    );
    if (saved == true && mounted) {
      ref.invalidate(adminStoresProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลร้านแล้ว')));
    }
  }

  Future<void> _deleteStore(StoreModel store) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('ลบร้านค้า'),
        content: Text(
          'จะลบร้าน "${store.name}" พร้อมสินค้าและสินค้าย่อยทั้งหมดในร้าน '
          'อย่างถาวร (ประวัติคำสั่งซื้อจะยังถูกเก็บไว้)\n\n'
          'การกระทำนี้ย้อนกลับไม่ได้ ยืนยันที่จะลบหรือไม่?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingId = store.id);
    try {
      await ref.read(adminRepositoryProvider).deleteStore(store.id);
      if (!mounted) return;
      ref.invalidate(adminStoresProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ลบร้าน "${store.name}" แล้ว')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ลบร้านไม่สำเร็จ: $error')));
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String? _deletingId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override //เพื่อให้หน้าผู้ใช้สามารถค้นหาและจัดการผู้ใช้ได้อย่างสะดวก โดยมีการแสดงผลลัพธ์ที่เหมาะสมตามสถานะการโหลดและข้อผิดพลาด
  Widget build(BuildContext context) {
    return ref
        .watch(adminUsersProvider)
        .when(
          loading: () => const LoadingView(),
          error: (Object error, StackTrace stack) => ErrorView(
            message: '$error',
            onRetry: () => ref.invalidate(adminUsersProvider),
          ),
          data: (List<UserModel> users) {
            final String actingUid =
                ref.read(authUserProvider).asData?.value?.uid ?? '';
            final List<UserModel> visible = users.where((UserModel user) {
              final String value = <String>[
                user.displayName,
                user.email,
                user.phone,
                user.province,
                ...user.roles.map((UserRole role) => role.label),
              ].join(' ').toLowerCase();
              return value.contains(_search.toLowerCase());
            }).toList();

            return Column(
              children: <Widget>[
                _SearchBox(
                  controller: _searchController,
                  onChanged: (String value) => setState(() => _search = value),
                  hint: 'ค้นหาชื่อ อีเมล หรือบทบาท',
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(adminUsersProvider);
                    },
                    child: visible.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: <Widget>[
                              SizedBox(
                                height: 300,
                                child: EmptyView(
                                  icon: Icons.people_outline_rounded,
                                  title: _search.isEmpty
                                      ? 'ยังไม่มีผู้ใช้'
                                      : 'ไม่พบผู้ใช้',
                                  body: 'บัญชีผู้ใช้และบทบาทจะแสดงในหน้านี้',
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(
                              left: AppSpacing.gutter,
                              right: AppSpacing.gutter,
                              bottom: AppSpacing.xxl,
                            ),
                            itemCount: visible.length,
                            separatorBuilder:
                                (BuildContext context, int index) =>
                                    const Divider(height: 1),
                            itemBuilder: (BuildContext context, int index) {
                              final UserModel user = visible[index];
                              final bool isSelf = user.uid == actingUid;
                              final IconData deleteIcon = isSelf
                                  ? Icons.person_outline_rounded
                                  : Icons.delete_outline_rounded;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  child: Text(_initials(user.displayName)),
                                ),
                                title: Text(
                                  user.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  <String>[
                                        user.email,
                                        if (user.roles.isNotEmpty)
                                          user.roles
                                              .map(
                                                (UserRole role) => role.label,
                                              )
                                              .join(' · '),
                                      ]
                                      .where((String part) => part.isNotEmpty)
                                      .join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    IconButton(
                                      tooltip: 'แก้ไขข้อมูลผู้ใช้',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _editUser(user),
                                    ),
                                    IconButton(
                                      tooltip: isSelf
                                          ? 'ลบบัญชีตัวเองไม่ได้'
                                          : 'ลบผู้ใช้',
                                      icon: _deletingId == user.uid
                                          ? const SizedBox.square(
                                              dimension: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Icon(
                                              deleteIcon,
                                              color: user.isAdmin
                                                  ? AppColors.inkMuted
                                                  : AppColors.danger,
                                            ),
                                      onPressed: user.isAdmin ||
                                              isSelf ||
                                              _deletingId == user.uid
                                          ? null
                                          : () => _deleteUser(user),
                                    ),
                                  ],
                                ),
                                onTap: () => _showUserDetails(user),
                              );
                            },
                          ),
                  ),
                ),
              ],
            );
          },
        );
  }

  Future<void> _showUserDetails(UserModel user) async {
    final bool? edit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(user.displayName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _DetailLine('อีเมล', user.email),
              _DetailLine('โทรศัพท์', user.phone),
              _DetailLine('จังหวัด', user.province),
              _DetailLine(
                'บทบาท',
                user.roles.map((UserRole role) => role.label).join(' · '),
              ),
              _DetailLine('User ID', user.uid),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('แก้ข้อมูล'),
          ),
        ],
      ),
    );
    if (edit == true) await _editUser(user);
  }

  Future<void> _editUser(UserModel user) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => _UserEditor(user: user),
    );
    if (saved == true && mounted) {
      ref.invalidate(adminUsersProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลผู้ใช้แล้ว')));
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('ลบผู้ใช้'),
        content: Text(
          'จะลบข้อมูลของ "${user.displayName}" (${user.email}) อย่างถาวร — '
          'โปรไฟล์ ร้านค้าและสินค้าที่เป็นเจ้าของทั้งหมด\n\n'
          ' บัญชี (Firebase Auth) จะยังอยู่โดยไม่สามารถ '
          'ใช้งานแอปได้ ถ้าต้องการลบออกจากระบบจริง ต้องลบใน Firebase Console '
          'หลังลบแล้ว\n\n'
          'ประวัติคำสั่งซื้อที่คนนี้เคยสั่งยังถูกเก็บไว้ '
          'การกระทำนี้ย้อนกลับไม่ได้ ยืนยันที่จะลบหรือไม่ หากจะลบลบได้เลยค่พ?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final String actingUid =
        ref.read(authUserProvider).asData?.value?.uid ?? '';
    setState(() => _deletingId = user.uid);
    try {
      await ref
          .read(adminRepositoryProvider)
          .deleteUser(uid: user.uid, actingAdminUid: actingUid);
      if (!mounted) return;
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminStoresProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ลบข้อมูลผู้ใช้ "${user.displayName}" แล้ว (โพรไฟล์/ร้าน/สินค้า) — '
            'บัญชีเข้าสู่ระบบยังอยู่ใน Firebase Auth ถ้าต้องการลบจริง '
            'ให้ลบใน Firebase Console (แผนฟรี)',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ลบผู้ใช้ไม่สำเร็จ: $error')));
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }
}

class _CouponsTab extends ConsumerStatefulWidget {
  const _CouponsTab();

  @override
  ConsumerState<_CouponsTab> createState() => _CouponsTabState();
}

class _CouponsTabState extends ConsumerState<_CouponsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String? _deletingId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(adminCouponsProvider)
        .when(
          loading: () => const LoadingView(),
          error: (Object error, StackTrace stack) => ErrorView(
            message: '$error',
            onRetry: () => ref.invalidate(adminCouponsProvider),
          ),
          data: (List<CouponModel> coupons) {
            final List<CouponModel> visible = coupons
                .where(
                  (CouponModel coupon) =>
                      coupon.code.toLowerCase().contains(_search.toLowerCase()),
                )
                .toList();

            return Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _SearchBox(
                        controller: _searchController,
                        onChanged: (String value) =>
                            setState(() => _search = value),
                        hint: 'ค้นหารหัสคูปอง',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        right: AppSpacing.gutter,
                        top: AppSpacing.md,
                      ),
                      child: IconButton.filled(
                        tooltip: 'สร้างคูปองใหม่',
                        icon: const Icon(Icons.add_rounded),
                        onPressed: _createCoupon,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(adminCouponsProvider);
                    },
                    child: visible.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: <Widget>[
                              SizedBox(
                                height: 300,
                                child: EmptyView(
                                  icon: Icons.local_offer_outlined,
                                  title: _search.isEmpty
                                      ? 'ยังไม่มีคูปอง'
                                      : 'ไม่พบคูปองที่ค้นหา',
                                  body: _search.isEmpty
                                      ? 'คูปองที่สร้างจะแสดงในหน้านี้'
                                      : 'ลองค้นหาด้วยรหัสคูปองอีกครั้ง',
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(
                              left: AppSpacing.gutter,
                              right: AppSpacing.gutter,
                              bottom: AppSpacing.xxl,
                            ),
                            itemCount: visible.length,
                            separatorBuilder:
                                (BuildContext context, int index) =>
                                    const Divider(height: 1),
                            itemBuilder: (BuildContext context, int index) {
                              final CouponModel coupon = visible[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: coupon.active
                                      ? AppColors.gold
                                      : AppColors.clayLight,
                                  foregroundColor: coupon.active
                                      ? AppColors.ink
                                      : AppColors.clayDark,
                                  child: const Icon(
                                    Icons.local_offer_outlined,
                                  ),
                                ),
                                title: Row(
                                  children: <Widget>[
                                    Flexible(
                                      child: Text(
                                        coupon.code,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (!coupon.active)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: AppSpacing.sm,
                                        ),
                                        child: _StatusChip(label: 'ปิดใช้งาน'),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  _couponSummary(coupon),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Switch(
                                      value: coupon.active,
                                      onChanged: _deletingId == coupon.id
                                          ? null
                                          : (bool value) =>
                                                _toggleCoupon(coupon),
                                    ),
                                    IconButton(
                                      tooltip: 'แก้ไขคูปอง',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _editCoupon(coupon),
                                    ),
                                    IconButton(
                                      tooltip: 'ลบคูปอง',
                                      icon: _deletingId == coupon.id
                                          ? const SizedBox.square(
                                              dimension: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.delete_outline_rounded,
                                              color: AppColors.danger,
                                            ),
                                      onPressed: _deletingId == coupon.id
                                          ? null
                                          : () => _deleteCoupon(coupon),
                                    ),
                                  ],
                                ),
                                onTap: () => _editCoupon(coupon),
                              );
                            },
                          ),
                  ),
                ),
              ],
            );
          },
        );
  }

  Future<void> _createCoupon() async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => const _CouponEditor(),
    );
    if (saved == true && mounted) {
      ref.invalidate(adminCouponsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('สร้างคูปองแล้ว')));
    }
  }

  Future<void> _editCoupon(CouponModel coupon) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => _CouponEditor(coupon: coupon),
    );
    if (saved == true && mounted) {
      ref.invalidate(adminCouponsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('บันทึกคูปองแล้ว')));
    }
  }

  Future<void> _toggleCoupon(CouponModel coupon) async {
    try {
      await ref
          .read(couponRepositoryProvider)
          .setActive(coupon.id, !coupon.active);
      ref.invalidate(adminCouponsProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เปลี่ยนสถานะไม่สำเร็จ: $error')));
    }
  }

  Future<void> _deleteCoupon(CouponModel coupon) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('ลบคูปอง'),
        content: Text(
          'จะลบคูปอง "${coupon.code}" อย่างถาวร\n\n'
          'คูปองที่อยู่ระหว่างการชำระเงินของลูกค้าอาจใช้ต่อไม่ได้ '
          'การกระทำนี้ย้อนกลับไม่ได้ ยืนยันที่จะลบหรือไม่?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deletingId = coupon.id);
    try {
      await ref.read(couponRepositoryProvider).delete(coupon.id);
      ref.invalidate(adminCouponsProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ลบคูปองไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }
}

String _couponSummary(CouponModel coupon) {
  final String discount = switch (coupon.type) {
    CouponType.percentage => '${coupon.value.toStringAsFixed(0)}%',
    CouponType.fixed => '${coupon.value.toStringAsFixed(0)} บาท',
  };
  final String spend = coupon.minSpend > 0
      ? 'ขั้นต่ำ ${coupon.minSpend.toStringAsFixed(0)} บาท'
      : 'ไม่จำกัดขั้นต่ำ';
  final String usage = coupon.usageLimit == null
      ? 'ใช้แล้ว ${coupon.usedCount} ครั้ง'
      : 'ใช้แล้ว ${coupon.usedCount}/${coupon.usageLimit} ครั้ง';
  return '$discount · $spend · $usage';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.clayLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.clayDark),
      ),
    );
  }
}

class _CouponEditor extends ConsumerStatefulWidget {
  const _CouponEditor({this.coupon});

  final CouponModel? coupon;

  @override
  ConsumerState<_CouponEditor> createState() => _CouponEditorState();
}

class _CouponEditorState extends ConsumerState<_CouponEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _code = TextEditingController(
    text: widget.coupon?.code ?? '',
  );
  late final TextEditingController _value = TextEditingController(
    text: widget.coupon?.value.toStringAsFixed(0) ?? '',
  );
  late final TextEditingController _minSpend = TextEditingController(
    text: (widget.coupon?.minSpend ?? 0) > 0
        ? widget.coupon!.minSpend.toStringAsFixed(0)
        : '',
  );
  late final TextEditingController _maxDiscount = TextEditingController(
    text: widget.coupon?.maxDiscount?.toStringAsFixed(0) ?? '',
  );
  late final TextEditingController _usageLimit = TextEditingController(
    text: widget.coupon?.usageLimit?.toString() ?? '',
  );
  late CouponType _type = widget.coupon?.type ?? CouponType.percentage;
  late DateTime? _startsAt = widget.coupon?.startsAt;
  late DateTime? _expiresAt = widget.coupon?.expiresAt;
  late bool _active = widget.coupon?.active ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _minSpend.dispose();
    _maxDiscount.dispose();
    _usageLimit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.coupon == null ? 'สร้างคูปอง' : 'แก้ไขคูปอง'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(
                    labelText: 'รหัสคูปอง',
                    hintText: 'เช่น SAVE20',
                    helperText: 'กรอกด้วยตัวอักษรภาษาอังกฤษตัวใหญ่',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'กรุณากรอกรหัสคูปอง';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<CouponType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'ประเภทส่วนลด'),
                  items: <DropdownMenuItem<CouponType>>[
                    DropdownMenuItem<CouponType>(
                      value: CouponType.percentage,
                      child: const Text('ลดตามสัดส่วน (%)'),
                    ),
                    DropdownMenuItem<CouponType>(
                      value: CouponType.fixed,
                      child: const Text('ลดแบบเหมาจ่าย (บาท)'),
                    ),
                  ],
                  onChanged: (CouponType? value) {
                    if (value != null) setState(() => _type = value);
                  },
                ),
                TextFormField(
                  controller: _value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _type == CouponType.percentage
                        ? 'จำนวนส่วนลด (%)'
                        : 'จำนวนส่วนลด (บาท)',
                  ),
                  validator: (String? value) {
                    final double? parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'กรุณากรอกตัวเลขที่มากกว่า 0';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _minSpend,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'ยอดขั้นต่ำ (บาท)',
                    helperText: 'เว้นว่าง = ไม่จำกัด',
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final double? parsed = double.tryParse(value);
                    if (parsed == null || parsed < 0) {
                      return 'กรุณากรอกตัวเลขที่ถูกต้อง';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _maxDiscount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'ส่วนลดสูงสุด (บาท)',
                    helperText: 'เฉพาะประเภทเปอร์เซ็นต์ · เว้นว่าง = ไม่จำกัด',
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final double? parsed = double.tryParse(value);
                    if (parsed == null || parsed < 0) {
                      return 'กรุณากรอกตัวเลขที่ถูกต้อง';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _usageLimit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'จำนวนครั้งที่ใช้ได้',
                    helperText: 'เว้นว่าง = ใช้ได้ไม่จำกัด',
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final int? parsed = int.tryParse(value);
                    if (parsed == null || parsed < 1) {
                      return 'กรุณากรอกจำนวนเต็มที่มากกว่า 0';
                    }
                    return null;
                  },
                ),
                _DateField(
                  label: 'วันเริ่มต้นใช้',
                  value: _startsAt,
                  onChanged: (DateTime? value) =>
                      setState(() => _startsAt = value),
                ),
                _DateField(
                  label: 'วันหมดอายุ',
                  value: _expiresAt,
                  onChanged: (DateTime? value) =>
                      setState(() => _expiresAt = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('เปิดใช้งานคูปอง'),
                  subtitle: const Text('ปิดแล้วจะใช้รหัสนี้ไม่ได้'),
                  value: _active,
                  onChanged: (bool value) => setState(() => _active = value),
                ),
                if (_error != null) _DialogError(_error!),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('บันทึก'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final CouponModel draft = CouponModel(
        id: widget.coupon?.id ?? '',
        code: _code.text.trim().toUpperCase(),
        type: _type,
        value: double.parse(_value.text),
        minSpend: _minSpend.text.trim().isEmpty
            ? 0
            : double.parse(_minSpend.text),
        maxDiscount: _maxDiscount.text.trim().isEmpty
            ? null
            : double.parse(_maxDiscount.text),
        startsAt: _startsAt,
        expiresAt: _expiresAt,
        usageLimit: _usageLimit.text.trim().isEmpty
            ? null
            : int.parse(_usageLimit.text),
        usedCount: widget.coupon?.usedCount ?? 0,
        active: _active,
      );
      if (widget.coupon == null) {
        await ref.read(couponRepositoryProvider).create(draft.toFirestore());
      } else {
        await ref
            .read(couponRepositoryProvider)
            .update(widget.coupon!.id, draft.toFirestore());
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          hintText: 'เลือกวันที่ (เว้นว่างได้)',
          suffixIcon: IconButton(
            tooltip: 'ล้างวันที่',
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed:
                value == null ? null : () => onChanged(null),
          ),
        ),
        child: InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              helpText: 'เลือก$label',
            );
            if (picked != null) onChanged(picked);
          },
          child: Text(
            value == null
                ? 'ยังไม่กำหนด'
                : _formatDate(value!),
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final String year = (date.year + 543).toString();
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '$day/$month/$year';
}

class _StoreEditor extends ConsumerStatefulWidget {
  const _StoreEditor({required this.store});

  final StoreModel store;

  @override
  ConsumerState<_StoreEditor> createState() => _StoreEditorState();
}

class _StoreEditorState extends ConsumerState<_StoreEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.store.name,
  );
  late final TextEditingController _province = TextEditingController(
    text: widget.store.province,
  );
  late final TextEditingController _community = TextEditingController(
    text: widget.store.community,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.store.description,
  );
  late ThaiRegion _region =
      ThaiRegion.fromValue(widget.store.region) ?? ThaiRegion.central;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _province.dispose();
    _community.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('แก้ข้อมูลร้านค้า'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'ชื่อร้าน'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _province,
                  decoration: const InputDecoration(labelText: 'จังหวัด'),
                  validator: _required,
                ),
                DropdownButtonFormField<ThaiRegion>(
                  initialValue: _region,
                  decoration: const InputDecoration(labelText: 'ภูมิภาค'),
                  items: ThaiRegion.values
                      .map(
                        (ThaiRegion region) => DropdownMenuItem<ThaiRegion>(
                          value: region,
                          child: Text(region.label),
                        ),
                      )
                      .toList(),
                  onChanged: (ThaiRegion? value) {
                    if (value != null) setState(() => _region = value);
                  },
                ),
                TextFormField(
                  controller: _community,
                  decoration: const InputDecoration(labelText: 'ชุมชน'),
                ),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'รายละเอียดร้าน',
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                if (_error != null) _DialogError(_error!),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('บันทึก'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateStoreBasics(
            store: widget.store,
            name: _name.text,
            province: _province.text,
            region: _region.value,
            community: _community.text,
            description: _description.text,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _UserEditor extends ConsumerStatefulWidget {
  const _UserEditor({required this.user});

  final UserModel user;

  @override
  ConsumerState<_UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends ConsumerState<_UserEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.user.displayName,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.user.phone,
  );
  late final TextEditingController _province = TextEditingController(
    text: widget.user.province,
  );
  // กล่องนี้ปล่อยให้แก้แค่ customer/seller — admin ถ้าเป็นอยู่ก็ถูกตัดออก
    // ไม่ให้แก้ผ่าน UI เพื่อกัน privilege escalation
    late final Set<UserRole> _roles = widget.user.roles
      .where((UserRole role) => role != UserRole.admin)
      .toSet();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _province.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('แก้ข้อมูลผู้ใช้'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  initialValue: widget.user.email,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'อีเมล'),
                ),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'ชื่อที่แสดง'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'โทรศัพท์'),
                  keyboardType: TextInputType.phone,
                ),
                TextFormField(
                  controller: _province,
                  decoration: const InputDecoration(labelText: 'จังหวัด'),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: AppSpacing.md),
                    child: Text('บทบาท'),
                  ),
                ),
                for (final UserRole role in <UserRole>[
                  UserRole.customer,
                  UserRole.seller,
                ])
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(role.label),
                    value: _roles.contains(role),
                    onChanged: _saving
                        ? null
                        : (bool? selected) {
                            setState(() {
                              if (selected == true) {
                                _roles.add(role);
                              } else {
                                _roles.remove(role);
                              }
                            });
                          },
                  ),
                if (widget.user.isAdmin)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(Icons.admin_panel_settings_outlined),
                    title: Text('ผู้ดูแลระบบ'),
                    subtitle: Text('เปลี่ยนบทบาทนี้ไม่ได้'),
                  ),
                if (_error != null) _DialogError(_error!),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('บันทึก'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final List<UserRole> roles = <UserRole>[
      ..._roles,
      if (widget.user.isAdmin) UserRole.admin,
    ];
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateUserBasics(
            user: widget.user,
            displayName: _name.text,
            phone: _phone.text,
            province: _province.text,
            roles: roles,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.hint,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'ล้างคำค้น',
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.xxs),
          SelectableText(value, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _DialogError extends StatelessWidget {
  const _DialogError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        message,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
      ),
    );
  }
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'กรุณากรอกข้อมูล' : null;

String _regionLabel(String value) =>
    ThaiRegion.fromValue(value)?.label ?? (value.isEmpty ? 'ไม่ระบุ' : value);

String _initials(String value) {
  final String name = value.trim();
  if (name.isEmpty) return '?';
  return name.characters.first.toUpperCase();
}

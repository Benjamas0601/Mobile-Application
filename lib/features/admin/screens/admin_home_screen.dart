import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/store_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/state_views.dart';
import '../providers/admin_provider.dart';

/// หน้าจอผู้ดูแลสำหรับตรวจและจัดการข้อมูลหลักตามสิทธิ์ admin
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserModel? user = ref.watch(authUserProvider).asData?.value;
    if (user?.isAdmin != true) {
      return const Scaffold(
        body: EmptyView(
          icon: Icons.lock_outline_rounded,
          title: 'ไม่มีสิทธิ์เข้าถึง',
          body: 'หน้านี้สำหรับผู้ดูแลระบบเท่านั้น',
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
            ],
          ),
        ),
        body: const TabBarView(children: <Widget>[_StoresTab(), _UsersTab()]),
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
                    onRefresh: () => ref.refresh(adminStoresProvider.future),
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
                                trailing: IconButton(
                                  tooltip: 'แก้ไขข้อมูลร้าน',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editStore(store),
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
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
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
                    onRefresh: () => ref.refresh(adminUsersProvider.future),
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
                                trailing: IconButton(
                                  tooltip: 'แก้ไขข้อมูลผู้ใช้',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editUser(user),
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

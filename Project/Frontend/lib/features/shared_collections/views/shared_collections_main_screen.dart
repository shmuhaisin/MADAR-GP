// shared_collections_main_screen.dart

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/app_confirm_dialog.dart';
import '../../../common_theme/ui/app_top_message.dart';
import '../../../common_theme/ui/navy_header_clip.dart';

import '../viewmodel/shared_collections_main_vm.dart';
import '../widgets/collection_card.dart';
import '../widgets/collection_pager.dart';
import '../views/owned_collections_details_screen.dart';
import './joined_collections_details_screen.dart';
import '../viewmodel/shared_collections_details_vm.dart';

enum _CollectionsViewMode { cards, list }

class SharedCollectionScreen extends StatefulWidget {
  const SharedCollectionScreen({super.key});

  @override
  State<SharedCollectionScreen> createState() =>
      _SharedCollectionsScreenState();
}

class _SharedCollectionsScreenState extends State<SharedCollectionScreen>
    with WidgetsBindingObserver {
  static const String _offlineCacheMessage =
      'أنت غير متصل بالإنترنت، يتم عرض آخر بيانات محفوظة';

  _CollectionsViewMode _mode = _CollectionsViewMode.cards;

  StreamSubscription<dynamic>? _connectivitySub;
  Timer? _internetVerifyTimer;

  bool _showOfflineCacheWarning = false;
  bool _checkingConnection = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    Future.microtask(() async {
      if (!mounted) return;

      final vm = context.read<SharedCollectionsViewModel>();
      await vm.loadAll();

      if (!mounted) return;

      _syncOfflineWarningFromVm(vm);
      await _refreshConnectionState(reloadWhenOnline: false);
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (!mounted) return;
      unawaited(_handleConnectivityChanged(result));
    });

    _internetVerifyTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      unawaited(_refreshConnectionState(reloadWhenOnline: false));
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _internetVerifyTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    unawaited(_refreshConnectionState(reloadWhenOnline: true));
  }

  void _setOfflineWarning(bool value) {
    if (!mounted || _showOfflineCacheWarning == value) return;

    setState(() {
      _showOfflineCacheWarning = value;
    });
  }

  void _syncOfflineWarningFromVm(SharedCollectionsViewModel vm) {
    if (_isOfflineApiMessage(vm.apiError)) {
      _setOfflineWarning(true);
    }
  }

  bool _isConnectivityNone(dynamic result) {
    if (result is ConnectivityResult) {
      return result == ConnectivityResult.none;
    }

    if (result is List<ConnectivityResult>) {
      return result.isEmpty ||
          result.every((item) => item == ConnectivityResult.none);
    }

    return false;
  }

  Future<void> _handleConnectivityChanged(dynamic result) async {
    if (_isConnectivityNone(result)) {
      _setOfflineWarning(true);
      return;
    }

    await _refreshConnectionState(reloadWhenOnline: true);
  }

  Future<void> _refreshConnectionState({
    required bool reloadWhenOnline,
  }) async {
    if (_checkingConnection) return;

    _checkingConnection = true;

    try {
      final dynamic connectivity = await Connectivity().checkConnectivity();

      if (!mounted) return;

      if (_isConnectivityNone(connectivity)) {
        _setOfflineWarning(true);
        return;
      }

      final online = await _hasInternetConnection();

      if (!mounted) return;

      if (!online) {
        _setOfflineWarning(true);
        return;
      }

      final vm = context.read<SharedCollectionsViewModel>();

      if (reloadWhenOnline ||
          _showOfflineCacheWarning ||
          _isOfflineApiMessage(vm.apiError)) {
        await vm.loadAll();

        if (!mounted) return;
      }

      if (_isOfflineApiMessage(vm.apiError)) {
        _setOfflineWarning(true);
      } else {
        _setOfflineWarning(false);
      }
    } finally {
      _checkingConnection = false;
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(milliseconds: 900),
      );

      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _isOfflineLikeError(Object? error) {
    final msg = (error ?? '').toString().trim();
    final lower = msg.toLowerCase();

    return lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout') ||
        lower.contains('internet') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection error') ||
        lower.contains('connection failed') ||
        lower.contains('connection refused') ||
        msg.contains('لا يوجد اتصال') ||
        msg.contains('غير متصل') ||
        msg.contains('بدون إنترنت') ||
        msg.contains('آخر بيانات محفوظة');
  }

  Future<bool> _ensureOnlineForAction(String message) async {
    await _refreshConnectionState(reloadWhenOnline: false);

    if (!mounted) return false;

    if (_showOfflineCacheWarning) {
      AppTopMessage.show(
        context,
        text: message,
        type: TopMsgType.error,
      );
      return false;
    }

    return true;
  }

bool _isOfflineApiMessage(String? message) {
  final m = (message ?? '').trim();

  return m.contains('غير متصل') ||
      m.contains('لا يوجد اتصال') ||
      m.contains('آخر بيانات محفوظة');
}

Widget _offlineBanner(String message) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFC9C9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 7),
            color: Colors.red.withOpacity(0.08),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE3E3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFE53935),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'NotoSansArabic',
                  color: Color(0xFFC62828),
                  fontSize: 12.8,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _cleanError(Object? error) {    final msg = (error ?? '').toString().trim();
    final lower = msg.toLowerCase();

    if (msg.isEmpty) {
      return 'حدث خطأ أثناء تنفيذ العملية';
    }

    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        msg.contains('غير مصرح')) {
      return 'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى';
    }

    if (lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout')) {
      return 'تعذّر الاتصال بالخادم، تحقق من الإنترنت';
    }

    if (lower.contains('404') ||
        lower.contains('not found') ||
        msg.contains('غير موجود')) {
      return 'لم يتم العثور على المجموعة';
    }

    if (lower.contains('409') ||
        lower.contains('conflict') ||
        msg.contains('موجود') ||
        msg.contains('مسبق')) {
      return 'تم تنفيذ هذه العملية مسبقًا';
    }

    if (lower.contains('500') || lower.contains('internal server')) {
      return 'حدث خطأ في الخادم، حاول مرة أخرى لاحقًا';
    }

    if (msg.startsWith('Exception:')) {
      final clean = msg.replaceFirst('Exception:', '').trim();
      return clean.isEmpty ? 'حدث خطأ أثناء تنفيذ العملية' : clean;
    }

    if (msg.startsWith('HTTP')) {
      return 'حدث خطأ أثناء تنفيذ العملية';
    }

    return msg;
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    AppTopMessage.show(
      context,
      text: message,
      type: TopMsgType.success,
    );
  }

  void _showError(Object error) {
    if (!mounted) return;

    AppTopMessage.show(
      context,
      text: _cleanError(error),
      type: TopMsgType.error,
    );
  }

  Future<void> _safeAfterClose(Future<void> Function() action) async {
    await Future.delayed(const Duration(milliseconds: 140));

    if (!mounted) return;

    await action();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SharedCollectionsViewModel>();

    final hasVisibleCachedData =
        vm.ownedCollections.isNotEmpty || vm.joinedCollections.isNotEmpty;

    final shouldShowOfflineBanner = hasVisibleCachedData &&
        (_showOfflineCacheWarning || _isOfflineApiMessage(vm.apiError));

    return Scaffold(
      backgroundColor: AppColors.softBg,
      floatingActionButton: SizedBox(
        width: 55,
        height: 55,
        child: FloatingActionButton(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          onPressed: () async {
            final online = await _ensureOnlineForAction(
              'لا يمكن إنشاء مجموعة بدون إنترنت',
            );

            if (!online) return;

            await _openCreateCollectionSheet(context);
          },
          child: const Icon(Icons.add, size: 20),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
         SliverToBoxAdapter(
  child: MadarNavyHeaderClip(
    headerHeight: 92,
    overlap: 0,
    sheetRadius: 0,
    child: const SizedBox(
      height: 70,
      child: Center(
        child: Text(
          'المجموعات',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: 'NotoSansArabic',
          ),
        ),
      ),
    ),
  ),
),
            if (shouldShowOfflineBanner)
  SliverToBoxAdapter(
    child: _offlineBanner(_offlineCacheMessage),
  ),

SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
    child: Align(
      alignment: Alignment.centerRight,
      child: _PillToggle(
        value: _mode,
        onChanged: (v) async {
          if (v == _CollectionsViewMode.cards) {
            setState(() => _mode = _CollectionsViewMode.cards);
            return;
          }

          setState(() => _mode = _CollectionsViewMode.list);

          await _openCollectionsSheet(context, vm);

          if (!mounted) return;

          setState(() => _mode = _CollectionsViewMode.cards);
        },
      ),
    ),
  ),
),

              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedSectionHeader(
                  title: 'مجموعاتي المشتركة',
                  dotColor: AppColors.accentBlue,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                sliver: SliverToBoxAdapter(
                  child: vm.ownedCollections.isEmpty
                      ? Center(
                          child: Text(
                            'لم تقم بإنشاء مجموعات مشتركة بعد',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppColors.text.withOpacity(0.70),
                            ),
                          ),
                        )
                      : CollectionsPager(
                          items: vm.ownedCollections,
                          itemsPerPage: 2,
                          itemHeight: ownedCard.cardHeight,
                          itemBuilder: (context, g, index) {
                            return ownedCard(
                              collectionId: g.id,
                              title: g.collectionName,
                              description: g.collectionDescription,
                              onView: () async {
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChangeNotifierProvider(
                                      create: (_) =>
                                          OwnedCollectionDetailsViewModel(
                                        collectionId: g.id,
                                      ),
                                      child: OwnedDetailsScreen(
                                        collectionId: g.id,
                                      ),
                                    ),
                                  ),
                                );

                                if (!context.mounted) return;

                                if (changed == true) {
                                  await vm.loadAll();
                                }
                              },
                              onEdit: () async {
                                final online = await _ensureOnlineForAction(
                                  'لا يمكن تعديل المجموعة بدون إنترنت',
                                );

                                if (!online) return;

                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChangeNotifierProvider(
                                      create: (_) =>
                                          OwnedCollectionDetailsViewModel(
                                        collectionId: g.id,
                                      ),
                                      child: OwnedDetailsScreen(
                                        collectionId: g.id,
                                        openEditDirectly: true,
                                      ),
                                    ),
                                  ),
                                );

                                if (context.mounted) {
                                  await vm.loadAll();
                                }
                              },
                              onDelete: () async {
                                await _handleDeleteFromList(
                                  context,
                                  vm,
                                  g.id,
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedSectionHeader(
                  title: 'مجموعات انضممت إليها',
                  dotColor:  Color(0xFF8B3258),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: vm.joinedCollections.isEmpty
                      ? Center(
                          child: Text(
                            'لم تنضم إلى  مجموعات مشتركة بعد',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppColors.text.withOpacity(0.70),
                            ),
                          ),
                        )
                      : CollectionsPager(
                          items: vm.joinedCollections,
                          itemsPerPage: 2,
                          itemHeight: JoinedCard.cardHeight,
                          itemBuilder: (context, g, index) {
                            return JoinedCard(
                              title: g.collectionName,
                              description: g.collectionDescription,
                              ownerHandle: g.ownerUsername ?? '',
                              onView: () async {
                                final left = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChangeNotifierProvider(
                                      create: (_) =>
                                          JoinedCollectionDetailsViewModel(
                                        collectionId: g.id,
                                      ),
                                      child: JoinedCollectionDetailsScreen(
                                        collectionId: g.id,
                                      ),
                                    ),
                                  ),
                                );

                                if (left == true && context.mounted) {
                                  await vm.loadAll();
                                }
                              },
                              onLeave: () async {
                                await _handleLeaveCollection(
                                  context: context,
                                  vm: vm,
                                  collectionId: g.id,
                                  collectionTitle: g.collectionName,
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
          if (vm.loading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.08),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          if (vm.error != null &&
              (vm.error ?? '').trim().isNotEmpty &&
              !_isOfflineLikeError(vm.error))
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Material(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _cleanError(vm.error),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: 'NotoSansArabic',
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: vm.clearError,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openCreateCollectionSheet(BuildContext context) async {
    final pageContext = context;

    await showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ChangeNotifierProvider(
          create: (_) => CreateCollectionViewModel(),
          child: _CreateCollectionSheet(pageContext: pageContext),
        );
      },
    );
  }

  Future<void> _showCollectionOptionsSheet({
    required BuildContext context,
    required String collectionId,
    required String collectionTitle,
    required bool isOwned,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    Future<void> Function()? onLeave,
  }) {
    final title = collectionTitle.trim();
    final pageContext = context;

    return showModalBottomSheet(
      context: pageContext,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: false,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.collections_bookmark,
                          color: AppColors.navy,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title.isEmpty ? 'المجموعة' : title,
                            textAlign: TextAlign.right,
                            softWrap: true,
                            style: const TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppColors.navy,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1, color: AppColors.divider),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1, color: AppColors.divider),
                  ),
                  if (isOwned) ...[
                    _SheetTile(
                      icon: Icons.edit,
                      iconColor: AppColors.navy,
                      title: 'تحرير المجموعة',
                      onTap: () {
                        Navigator.of(sheetCtx).pop();

                        Future.delayed(const Duration(milliseconds: 140), () {
                          if (!pageContext.mounted) return;
                          onEdit?.call();
                        });
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1, color: AppColors.divider),
                    ),
                    _SheetTile(
                      icon: Icons.delete,
                      iconColor: AppColors.danger,
                      title: 'حذف المجموعة',
                      titleColor: AppColors.danger,
                      onTap: () {
                        Navigator.of(sheetCtx).pop();

                        Future.delayed(const Duration(milliseconds: 140), () {
                          if (!pageContext.mounted) return;
                          onDelete?.call();
                        });
                      },
                    ),
                  ] else ...[
                    _SheetTile(
                      icon: Icons.logout,
                      iconColor: AppColors.danger,
                      title: 'غادر المجموعة',
                      titleColor: AppColors.danger,
                      onTap: () {
                        Navigator.of(sheetCtx).pop();

                        Future.delayed(const Duration(milliseconds: 140), () {
                          if (!pageContext.mounted) return;
                          onLeave?.call();
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCollectionsSheet(
    BuildContext context,
    SharedCollectionsViewModel vm,
  ) async {
    final pageContext = context;

    await showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.softBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                blurRadius: 30,
                offset: const Offset(0, -10),
                color: Colors.black.withOpacity(0.12),
              ),
            ],
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.35,
            maxChildSize: 0.92,
            builder: (_, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            'المجموعات',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _SheetSectionHeader(
                    title: 'مجموعاتي المشتركة',
                    dotColor: AppColors.accentBlue,
                  ),
                  const SizedBox(height: 10),
                  if (vm.ownedCollections.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'لم تقم بإنشاء مجموعات مشتركة بعد',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'NotoSansArabic',
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.text.withOpacity(0.70),
                          ),
                        ),
                      ),
                    )
                  else
                    ...vm.ownedCollections.map((c) {
                      return  _CollectionListTile(
  title: c.collectionName,
  isOwned: true,
  onTap: () async {
    Navigator.of(sheetContext).pop();

    await Future.delayed(const Duration(milliseconds: 140));

    if (!pageContext.mounted) return;

    final changed = await Navigator.of(pageContext).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => OwnedCollectionDetailsViewModel(
            collectionId: c.id,
          ),
          child: OwnedDetailsScreen(
            collectionId: c.id,
          ),
        ),
      ),
    );

    if (!pageContext.mounted) return;

    if (changed == true) {
      await vm.loadAll();
    }
  },
  onOptions: () async {
                          Navigator.of(sheetContext).pop();

                          await Future.delayed(
                            const Duration(milliseconds: 140),
                          );

                          if (!pageContext.mounted) return;

                          await _showCollectionOptionsSheet(
                            context: pageContext,
                            collectionId: c.id,
                            collectionTitle: c.collectionName,
                            isOwned: true,
                            onEdit: () async {
                              final online = await _ensureOnlineForAction(
                                'لا يمكن تعديل المجموعة بدون إنترنت',
                              );

                              if (!online) return;

                              await Navigator.of(pageContext).push(
                                MaterialPageRoute(
                                  builder: (_) => ChangeNotifierProvider(
                                    create: (_) =>
                                        OwnedCollectionDetailsViewModel(
                                      collectionId: c.id,
                                    ),
                                    child: OwnedDetailsScreen(
                                      collectionId: c.id,
                                      openEditDirectly: true,
                                    ),
                                  ),
                                ),
                              );

                              if (pageContext.mounted) {
                                await vm.loadAll();
                              }
                            },
                            onDelete: () async {
                              await _handleDeleteFromList(
                                pageContext,
                                vm,
                                c.id,
                              );
                            },
                          );
                        },
                      );
                    }),
                  const SizedBox(height: 16),
                  const _SheetSectionHeader(
                    title: 'مجموعات انضممت إليها',
                    dotColor: Color(0xFF8B3258),
                  ),
                  const SizedBox(height: 10),
                  if (vm.joinedCollections.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'لم تنضم إلى مجموعات مشتركة بعد',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'NotoSansArabic',
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.text.withOpacity(0.70),
                          ),
                        ),
                      ),
                    )
                  else
                    ...vm.joinedCollections.map((c) {
                      return  _CollectionListTile(
  title: c.collectionName,
  isOwned: false,
  onTap: () async {
    Navigator.of(sheetContext).pop();

    await Future.delayed(const Duration(milliseconds: 140));

    if (!pageContext.mounted) return;

    final left = await Navigator.of(pageContext).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => JoinedCollectionDetailsViewModel(
            collectionId: c.id,
          ),
          child: JoinedCollectionDetailsScreen(
            collectionId: c.id,
          ),
        ),
      ),
    );

    if (left == true && pageContext.mounted) {
      await vm.loadAll();
    }
  },
  onOptions: () async {
    Navigator.of(sheetContext).pop();

    await Future.delayed(const Duration(milliseconds: 140));

    if (!pageContext.mounted) return;

    await _handleLeaveCollection(
      context: pageContext,
      vm: vm,
      collectionId: c.id,
      collectionTitle: c.collectionName,
    );
  },
);
                    }),
                  const SizedBox(height: 18),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleDeleteFromList(
    BuildContext context,
    SharedCollectionsViewModel vm,
    String collectionId,
  ) async {
    final online = await _ensureOnlineForAction(
      'لا يمكن حذف المجموعة بدون إنترنت',
    );

    if (!online || !context.mounted) return;

    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'حذف المجموعة',
      message:
          'هل أنت متأكد من حذف هذه المجموعة؟ لا يمكن التراجع عن هذه العملية.',
      confirmText: 'نعم',
      cancelText: 'لا',
      confirmColor: const Color(0xFFF05260),
    );

    if (!confirmed || !context.mounted) return;

    final error = await vm.deleteCollection(collectionId);

    if (!context.mounted) return;

    if (error != null) {
      if (_isOfflineLikeError(error)) {
        _setOfflineWarning(true);
      }

      _showError(error);
      return;
    }

    await vm.loadAll();

    if (!context.mounted) return;

    _showSuccess('تم حذف المجموعة بنجاح');
  }

  Future<void> _handleLeaveCollection({
    required BuildContext context,
    required SharedCollectionsViewModel vm,
    required String collectionId,
    required String collectionTitle,
  }) async {
    final online = await _ensureOnlineForAction(
      'لا يمكن مغادرة المجموعة بدون إنترنت',
    );

    if (!online || !context.mounted) return;

    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'مغادرة المجموعة',
      message: collectionTitle.trim().isEmpty
          ? 'هل أنت متأكد من مغادرة هذه المجموعة؟'
          : 'هل أنت متأكد من مغادرة "$collectionTitle"؟',
      confirmText: 'نعم',
      cancelText: 'لا',
      confirmColor: const Color(0xFFF05260),
    );

    if (!confirmed || !context.mounted) return;

    final error = await vm.leaveCollection(collectionId);

    if (!context.mounted) return;

    if (error != null) {
      if (_isOfflineLikeError(error)) {
        _setOfflineWarning(true);
      }

      _showError(error);
      return;
    }

    await vm.loadAll();

    if (!context.mounted) return;

    _showSuccess('تمت مغادرة المجموعة بنجاح');
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'NotoSansArabic',
          fontWeight: FontWeight.w800,
          fontSize: 15.5,
          color: titleColor ?? AppColors.navy,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _PillToggle extends StatelessWidget {
  final _CollectionsViewMode value;
  final ValueChanged<_CollectionsViewMode> onChanged;

  const _PillToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.navy.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillIconItem(
            icon: Icons.view_carousel_outlined,
            selected: value == _CollectionsViewMode.cards,
            tooltip: 'البطاقات',
            onTap: () => onChanged(_CollectionsViewMode.cards),
          ),
          const SizedBox(width: 6),
          _PillIconItem(
            icon: Icons.view_list_rounded,
            selected: value == _CollectionsViewMode.list,
            tooltip: 'القائمة',
            onTap: () => onChanged(_CollectionsViewMode.list),
          ),
        ],
      ),
    );
  }
}

class _PillIconItem extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  const _PillIconItem({
    required this.icon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                      color: Colors.black.withOpacity(0.16),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected ? Colors.white : AppColors.navy,
          ),
        ),
      ),
    );
  }
}

class _SheetSectionHeader extends StatelessWidget {
  final String title;
  final Color dotColor;

  const _SheetSectionHeader({
    required this.title,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }
}

class _CollectionListTile extends StatelessWidget {
  final String title;
  final Future<void> Function()? onOptions;
    final VoidCallback? onTap;
  final bool isOwned;

  const _CollectionListTile({
    required this.title,
    this.onOptions,
      this.onTap,
    required this.isOwned,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 16.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (isOwned)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        AppColors.accentBlue2,
                        Color.fromARGB(255, 25, 41, 87),
                      ],
                    ),
                  ),
                ),
              ),
            if (!isOwned)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient:LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF5E80C2), // atmospheric blue
      Color(0xFF4262AC), // royal blue
      Color(0xFF2A4282), // navy presence
      Color(0xFF553568), // rich amethyst
      Color(0xFF8B3258), // wine
      Color(0xFFB23E5C), // rosy burgundy
    ],
    stops: [0.0, 0.18, 0.40, 0.60, 0.80, 1.0],
  ),
                  ),
                ),
              ),
            if (!isOwned)
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.16)),
              ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withOpacity(0.16),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
            ),
            ListTile(
              onTap: onTap,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              leading: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconPillButton(icon: Icons.collections_bookmark),
                ],
              ),
              title: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
             trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    _IconPillButton(
      tooltip: isOwned ? 'خيارات' : 'مغادرة',
      icon: isOwned ? Icons.more_horiz : Icons.logout,
      iconColor: Colors.white ,
      bgColor: Colors.white.withOpacity(0.16),
      onPressed: () async => await onOptions?.call(),
    ),
  ],
),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconPillButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback? onPressed;

  const _IconPillButton({
    required this.icon,
    this.tooltip = '',
    this.onPressed,
    this.iconColor = Colors.white,
    this.bgColor = const Color.fromARGB(60, 255, 255, 255),
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}

class _PinnedSectionHeader extends SliverPersistentHeaderDelegate {
  final String title;
  final Color dotColor;

  _PinnedSectionHeader({
    required this.title,
    required this.dotColor,
  });

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.softBg,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedSectionHeader oldDelegate) {
    return oldDelegate.title != title || oldDelegate.dotColor != dotColor;
  }
}

class _CreateCollectionSheet extends StatelessWidget {
  final BuildContext pageContext;

  const _CreateCollectionSheet({
    required this.pageContext,
  });

  String _cleanError(Object? error) {
    final msg = (error ?? '').toString().trim();
    final lower = msg.toLowerCase();

    if (msg.isEmpty) {
      return 'حدث خطأ أثناء تنفيذ العملية';
    }

    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        msg.contains('غير مصرح')) {
      return 'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى';
    }

    if (lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout')) {
      return 'تعذّر الاتصال بالخادم، تحقق من الإنترنت';
    }

    if (lower.contains('409') ||
        lower.contains('conflict') ||
        msg.contains('موجود') ||
        msg.contains('مسبق')) {
      return 'اسم المجموعة مستخدم أو موجود مسبقًا';
    }

    if (lower.contains('500') || lower.contains('internal server')) {
      return 'حدث خطأ في الخادم، حاول مرة أخرى لاحقًا';
    }

    if (msg.startsWith('Exception:')) {
      final clean = msg.replaceFirst('Exception:', '').trim();
      return clean.isEmpty ? 'حدث خطأ أثناء تنفيذ العملية' : clean;
    }

    if (msg.startsWith('HTTP')) {
      return 'حدث خطأ أثناء تنفيذ العملية';
    }

    return msg;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CreateCollectionViewModel>();
    final mainVm = context.read<SharedCollectionsViewModel>();
    final titleHasError = vm.titleError != null;
    final descHasError = vm.descError != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(
                fontFamily: 'NotoSansArabic',
              ),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.97,
          snap: true,
          snapSizes: const [0.60, 0.82, 0.97],
          builder: (sheetInnerContext, scrollController) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetInnerContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.softBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 30,
                      offset: const Offset(0, -10),
                      color: Colors.black.withOpacity(0.12),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                        child: LayoutBuilder(
                          builder: (context, c) {
                            const pillWidth = 50.0;
                            const gap = 5.0;

                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _CreatePillButton(
                                    enabled: vm.canSubmit &&
                                        !vm.submitting &&
                                        !mainVm.loading,
                                    onPressed: () => vm.submit(
                                      mainVm: mainVm,
                                      onSuccess: () {
                                        Navigator.of(context).pop();

                                        Future.delayed(
                                          const Duration(milliseconds: 140),
                                          () {
                                            if (!pageContext.mounted) return;

                                            AppTopMessage.show(
                                              pageContext,
                                              text:
                                                  'تم إنشاء المجموعة بنجاح',
                                              type: TopMsgType.success,
                                            );
                                          },
                                        );
                                      },
                                      onError: (msg) {
                                        if (!context.mounted) return;

                                        AppTopMessage.show(
                                          context,
                                          text: _cleanError(msg),
                                          type: TopMsgType.error,
                                        );
                                      },
                                    ),
                                    onDisabledTap: vm.markAllTouched,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: pillWidth + gap,
                                  ),
                                  child: const Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      'إنشاء مجموعة مشتركة',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.navy,
                                        fontFamily: 'NotoSansArabic',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            const _FieldLabel(
                              label: 'اسم المجموعة',
                              requiredMark: true,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              onChanged: vm.onTitleChanged,
                              textInputAction: TextInputAction.next,
                              maxLength: CreateCollectionViewModel.titleMax,
                              maxLengthEnforcement:
                                  MaxLengthEnforcement.enforced,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(
                                  CreateCollectionViewModel.titleMax,
                                ),
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\u0600-\u06FFa-zA-Z0-9\s\-_()]'),
                                ),
                              ],
                              decoration: _inputDecoration(
                                hint: 'مثال: أخبار تقنية',
                                hasError: titleHasError,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _MetaRow(
                              errorText: vm.titleHelper,
                              counterText:
                                  '${vm.titleLen}/${CreateCollectionViewModel.titleMax}',
                            ),
                            const SizedBox(height: 14),
                            const _FieldLabel(
                              label: 'وصف المجموعة',
                              requiredMark: true,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              onChanged: vm.onDescChanged,
                              maxLines: 4,
                              minLines: 3,
                              maxLength: CreateCollectionViewModel.descMax,
                              maxLengthEnforcement:
                                  MaxLengthEnforcement.enforced,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(
                                  CreateCollectionViewModel.descMax,
                                ),
                              ],
                              decoration: _inputDecoration(
                                hint: 'اكتب وصف قصير للمجموعة',
                                hasError: descHasError,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _MetaRow(
                              errorText: vm.descHelper,
                              counterText:
                                  '${vm.descLen}/${CreateCollectionViewModel.descMax}',
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required bool hasError,
  }) {
    final borderColor = hasError ? AppColors.danger : AppColors.divider;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.text.withOpacity(0.45),
        fontWeight: FontWeight.w700,
        fontFamily: 'NotoSansArabic',
      ),
      filled: true,
      fillColor: Colors.white,
      counterText: '',
      errorText: null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: hasError ? AppColors.danger : AppColors.navy,
          width: 1.2,
        ),
      ),
    );
  }
}

class _CreatePillButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  final VoidCallback onDisabledTap;

  const _CreatePillButton({
    required this.enabled,
    required this.onPressed,
    required this.onDisabledTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: enabled ? onPressed : onDisabledTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: enabled ? AppColors.navy : AppColors.text.withOpacity(0.20),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withOpacity(enabled ? 0.25 : 0.18),
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                    color: Colors.black.withOpacity(0.14),
                  ),
                ]
              : null,
        ),
        child: const Text(
          'إنشاء',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            fontFamily: 'NotoSansArabic',
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool requiredMark;

  const _FieldLabel({
    required this.label,
    required this.requiredMark,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'NotoSansArabic',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
          children: [
            TextSpan(text: label),
            if (requiredMark) ...[
              const TextSpan(text: ' '),
              const TextSpan(
                text: '*',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String? errorText;
  final String counterText;

  const _MetaRow({
    required this.errorText,
    required this.counterText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              counterText,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.text.withOpacity(0.55),
                fontWeight: FontWeight.w700,
                fontFamily: 'NotoSansArabic',
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              errorText ?? '',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'NotoSansArabic',
                color:
                    errorText != null ? AppColors.danger : Colors.transparent,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
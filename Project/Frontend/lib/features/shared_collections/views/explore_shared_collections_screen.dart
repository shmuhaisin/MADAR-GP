import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/app_confirm_dialog.dart';
import '../../../common_theme/ui/app_top_message.dart';
import '../../../common_theme/ui/navy_header_clip.dart';

import '../viewmodel/explore_vm.dart';
import '../widgets/explore_collection_card.dart';
import '../views/explore_collection_details_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with WidgetsBindingObserver {
  static const String _offlineCacheMessage =
      'أنت غير متصل بالإنترنت، يتم عرض آخر بيانات محفوظة';

  StreamSubscription<dynamic>? _connectivitySub;
  Timer? _internetVerifyTimer;
  Timer? _onlineRefreshTimer;

  bool _showOfflineCacheWarning = false;
  bool _checkingConnection = false;
  bool _refreshingExplore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    Future.microtask(() async {
      if (!mounted) return;
      await _reloadExploreFromServer(force: true);
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (!mounted) return;
      unawaited(_handleConnectivityChanged(result));
    });

    // Checks actual internet state. Some devices are connected to Wi-Fi
    // but the Wi-Fi itself has no internet.
    _internetVerifyTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      unawaited(_refreshConnectionState(reloadWhenOnline: false));
    });

    // REST API is not real-time by itself.
    // This keeps Explore near-real-time while the user stays on the page.
    _onlineRefreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      unawaited(_reloadExploreFromServer());
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _internetVerifyTimer?.cancel();
    _onlineRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_reloadExploreFromServer(force: true));
  }

  void _setOfflineWarning(bool value) {
    if (!mounted || _showOfflineCacheWarning == value) return;

    setState(() {
      _showOfflineCacheWarning = value;
    });
  }

  void _syncOfflineWarningFromVm(ExploreViewModel vm) {
    if (_isOfflineApiMessage(vm.apiError)) {
      _setOfflineWarning(true);
    } else if (!_isOfflineApiMessage(vm.error)) {
      _setOfflineWarning(false);
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

    await _reloadExploreFromServer(force: true);
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

      if (reloadWhenOnline) {
        await _reloadExploreFromServer(
          force: true,
          skipConnectionCheck: true,
        );
        return;
      }

      final vm = context.read<ExploreViewModel>();

      if (_isOfflineApiMessage(vm.apiError)) {
        _setOfflineWarning(true);
      } else {
        _setOfflineWarning(false);
      }
    } finally {
      _checkingConnection = false;
    }
  }

  Future<void> _reloadExploreFromServer({
    bool force = false,
    bool skipConnectionCheck = false,
  }) async {
    if (_refreshingExplore && !force) return;

    _refreshingExplore = true;

    try {
      if (!skipConnectionCheck) {
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
      }

      final vm = context.read<ExploreViewModel>();

      await vm.loadAll();

      if (!mounted) return;

      if (_isOfflineApiMessage(vm.apiError)) {
        _setOfflineWarning(true);
      } else {
        _setOfflineWarning(false);
      }
    } finally {
      _refreshingExplore = false;
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

  String _cleanError(Object error) {
    final msg = error.toString().trim();
    final lower = msg.toLowerCase();

    if (msg.isEmpty) {
      return 'حدث خطأ أثناء تنفيذ العملية';
    }

    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        msg.contains('غير مصرح')) {
      return 'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى';
    }

    if (lower.contains('409') ||
        lower.contains('conflict') ||
        msg.contains('موجود') ||
        msg.contains('مسبق')) {
      return 'تم إرسال طلب الانضمام مسبقًا';
    }

    if (lower.contains('connection') ||
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
        msg.contains('بدون إنترنت')) {
      return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';
    }

    if (lower.contains('404') ||
        lower.contains('not found') ||
        msg.contains('غير موجود')) {
      return 'لم يتم العثور على المجموعة';
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

  Future<void> _handleJoinRequest({
    required String collectionId,
    required String collectionName,
  }) async {
    await _refreshConnectionState(reloadWhenOnline: false);

    if (!mounted) return;

    if (_showOfflineCacheWarning) {
      AppTopMessage.show(
        context,
        text: 'لا يمكن إرسال طلب الانضمام بدون إنترنت',
        type: TopMsgType.error,
      );
      return;
    }

    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'طلب الانضمام',
      message: 'هل تريد إرسال طلب انضمام إلى "$collectionName"؟',
      confirmText: 'نعم',
      cancelText: 'لا',
      confirmColor: const Color(0xFFF05260),
    );

    if (!confirmed || !mounted) return;

    final vm = context.read<ExploreViewModel>();
    final errorMessage = await vm.joinAction(collectionId);

    if (!mounted) return;

    if (errorMessage == null) {
      await _reloadExploreFromServer(
        force: true,
        skipConnectionCheck: true,
      );

      if (!mounted) return;

      _setOfflineWarning(false);

      AppTopMessage.show(
        context,
        text: 'تم إرسال طلب الانضمام بنجاح',
        type: TopMsgType.success,
      );
    } else {
      if (_isOfflineApiMessage(errorMessage) ||
          errorMessage.contains('بدون إنترنت') ||
          _isOfflineLikeError(errorMessage)) {
        _setOfflineWarning(true);
        AppTopMessage.show(
          context,
          text: 'لا يمكن إرسال طلب الانضمام بدون إنترنت',
          type: TopMsgType.error,
        );
        return;
      }

      await _reloadExploreFromServer(
        force: true,
        skipConnectionCheck: true,
      );

      if (!mounted) return;

      AppTopMessage.show(
        context,
        text: _cleanError(errorMessage),
        type: TopMsgType.error,
      );
    }
  }

  Future<void> _openDetails({
    required BuildContext context,
    required ExploreViewModel vm,
    required dynamic item,
  }) async {
    try {
      await _refreshConnectionState(reloadWhenOnline: false);
      await vm.incrementViewOnce(item.id);

      if (!context.mounted) return;

      final updatedItem = vm.collections.firstWhere(
        (c) => c.id == item.id,
        orElse: () => item,
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExploreCollectionDetailsScreen(
            collection: updatedItem,
            onJoin: () async {
              await _handleJoinRequest(
                collectionId: item.id,
                collectionName: updatedItem.collectionName,
              );
            },
            onBack: () => Navigator.pop(context),
          ),
        ),
      );

      if (!mounted) return;

      await _reloadExploreFromServer(
        force: true,
        skipConnectionCheck: false,
      );
    } catch (e) {
      if (!mounted) return;

      if (_isOfflineLikeError(e)) {
        _setOfflineWarning(true);
        return;
      }

      AppTopMessage.show(
        context,
        text: _cleanError(e),
        type: TopMsgType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ExploreViewModel>();
    final apiError = vm.apiError;

    final shouldShowOfflineBanner =
        _showOfflineCacheWarning || _isOfflineApiMessage(apiError);

    return Scaffold(
      backgroundColor: AppColors.softBg,
      body: RefreshIndicator(
        onRefresh: () async {
          await _reloadExploreFromServer(force: true);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: MadarNavyHeaderClip(
                child: const SizedBox(
                  height: 92,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: 18),
                      child: Text(
                        'المجموعات المشتركة',
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
            ),
            if (shouldShowOfflineBanner)
              SliverToBoxAdapter(
                child: _offlineBanner(_offlineCacheMessage),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
              sliver: Builder(
                builder: (context) {
                  final items = vm.collections;

                  if (vm.error != null && (vm.error ?? '').trim().isNotEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _cleanError(vm.error!),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.danger,
                                  fontFamily: 'NotoSansArabic',
                                  fontWeight: FontWeight.w800,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await _reloadExploreFromServer(force: true);

                                    if (!mounted) return;

                                    _syncOfflineWarningFromVm(vm);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.navy,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: const Text(
                                    'إعادة المحاولة',
                                    style: TextStyle(
                                      fontFamily: 'NotoSansArabic',
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (vm.loading && !vm.hasLoadedOnce) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (!vm.loading && vm.hasLoadedOnce && items.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'لا توجد مجموعات مشتركة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'NotoSansArabic',
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: AppColors.text.withOpacity(0.70),
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = items[index];

                        return ExploreCollectionCard(
                          model: item,
                          onView: () async {
                            await _openDetails(
                              context: context,
                              vm: vm,
                              item: item,
                            );
                          },
                          onJoin: () async {
                            await _handleJoinRequest(
                              collectionId: item.id,
                              collectionName: item.collectionName,
                            );
                          },
                        );
                      },
                      childCount: items.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 5,
                      childAspectRatio: 0.88,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
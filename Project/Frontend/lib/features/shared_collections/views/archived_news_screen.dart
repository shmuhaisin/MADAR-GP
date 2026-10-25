import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/app_top_message.dart';
import '../../../common_theme/ui/navy_header_clip.dart';
import '../model/added_news_model.dart';
import '../viewmodel/shared_collections_details_vm.dart';
import '../widgets/added_news.dart';
import 'added_news_detail_screen.dart';

class ArchivedNewsScreen extends StatefulWidget {
  const ArchivedNewsScreen({super.key});

  @override
  State<ArchivedNewsScreen> createState() => _ArchivedNewsScreenState();
}

class _ArchivedNewsScreenState extends State<ArchivedNewsScreen>
    with WidgetsBindingObserver {
  static const String _offlineCacheMessage =
      'أنت غير متصل بالإنترنت، يتم عرض آخر بيانات محفوظة';

  static const LinearGradient _ownedHeaderGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [
      AppColors.accentBlue2,
      Color.fromARGB(255, 25, 41, 87),
    ],
  );

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

      final vm = context.read<OwnedCollectionDetailsViewModel>();
      await vm.loadArchivedNews();

      if (!mounted) return;

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

      _setOfflineWarning(false);

      if (reloadWhenOnline) {
        final vm = context.read<OwnedCollectionDetailsViewModel>();
        await vm.loadArchivedNews();

        if (!mounted) return;
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

  void _showSuccess(String message) {
    if (!mounted) return;

    AppTopMessage.show(
      context,
      text: message,
      type: TopMsgType.success,
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    AppTopMessage.show(
      context,
      text: message,
      type: TopMsgType.error,
    );
  }

  String _cleanError(String? message) {
    final msg = (message ?? '').trim();

    if (msg.isEmpty) {
      return 'حدث خطأ أثناء تنفيذ العملية';
    }

    final lower = msg.toLowerCase();

    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        msg.contains('غير مصرح')) {
      return 'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى';
    }

    if (_isOfflineLikeError(msg)) {
      return 'أنت غير متصل بالإنترنت، يتم عرض آخر بيانات محفوظة';
    }

    if (lower.contains('404') ||
        lower.contains('not found') ||
        msg.contains('غير موجود')) {
      return 'لم يتم العثور على الخبر';
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

  Widget _glossyBackButton({
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withOpacity(0.15),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.28),
                  width: 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.24),
                    Colors.white.withOpacity(0.08),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                    color: Colors.black.withOpacity(0.12),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openArchivedDetails({
    required AddedNewsModel news,
    required OwnedCollectionDetailsViewModel vm,
  }) async {
    final changed = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AddedNewsDetailsScreen(
          addedNews: news,
          collectionId: vm.collectionId,
          isOwnedScreen: true,
          isExploreScreen: false,
          isArchivedScreen: true,
          onRestorePressed: (ctx, item) async {
            final online = await _hasInternetConnection();

            if (!ctx.mounted) return;

            if (!online) {
              AppTopMessage.show(
                ctx,
                text: 'لا يمكن استعادة الخبر بدون إنترنت',
                type: TopMsgType.error,
              );
              return;
            }

            final ok = await vm.restoreNews(item.id);

            if (!ctx.mounted) return;

            if (!ok) {
              throw Exception(vm.archivedError ?? 'تعذر استعادة الخبر');
            }

            Navigator.pop(ctx, 'restored');
          },
          onRemovePressed: (ctx, item) async {
            final online = await _hasInternetConnection();

            if (!ctx.mounted) return;

            if (!online) {
              AppTopMessage.show(
                ctx,
                text: 'لا يمكن حذف الخبر بدون إنترنت',
                type: TopMsgType.error,
              );
              return;
            }

            final msg = await vm.deleteNews(item.id);

            if (!ctx.mounted) return;

            if (msg != null) {
              throw Exception(msg);
            }

            Navigator.pop(ctx, 'deleted');
          },
        ),
      ),
    );

    if (!mounted) return;

    if (changed == 'restored') {
      await vm.loadArchivedNews();

      if (!mounted) return;

      _showSuccess('تمت استعادة الخبر بنجاح');
      return;
    }

    if (changed == 'deleted') {
      await vm.loadArchivedNews();

      if (!mounted) return;

      _showSuccess('تم حذف الخبر بنجاح');
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OwnedCollectionDetailsViewModel>();
    final items = vm.archivedNews;

    final showOfflineBanner = items.isNotEmpty &&
        (_showOfflineCacheWarning || _isOfflineApiMessage(vm.archivedError));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.softBg,
        body: Column(
          children: [
            MadarNavyHeaderClip(
              headerHeight: 92,
              overlap: 15,
              sheetRadius: 28,
              child: SizedBox(
                height: 92,
                child: Stack(
                  children: [
                    const Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: 18),
                        child: Text(
                          'الأخبار المؤرشفة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'NotoSansArabic',
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12, right: 12),
                        child: _glossyBackButton(
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showOfflineBanner) _offlineBanner(_offlineCacheMessage),
            Expanded(
              child: Builder(
                builder: (_) {
                  if (vm.archivedLoading && items.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (vm.archivedError != null &&
                      !_isOfflineLikeError(vm.archivedError) &&
                      items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _cleanError(vm.archivedError),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.subText,
                                fontFamily: 'NotoSansArabic',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: () async {
                                  await vm.loadArchivedNews();

                                  if (!mounted) return;

                                  if (vm.archivedError != null &&
                                      !_isOfflineLikeError(vm.archivedError)) {
                                    _showError(_cleanError(vm.archivedError));
                                  }
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
                    );
                  }

                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'لا توجد أخبار مؤرشفة',
                        style: TextStyle(
                          fontFamily: 'NotoSansArabic',
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: AppColors.text.withOpacity(0.70),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final AddedNewsModel n = items[i];
                      final addedByUsername =
                          vm.usernameForUserId(n.addedByUserId);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AddedNewsCard(
                          item: n,
                          ownerHandle: addedByUsername,
                          ownerPillGradient: _ownedHeaderGradient,
                          isOwnedScreen: true,
                          showActions: false,
                          isMine: n.isAddedByMe,
                          onDelete: null,
                          onReport: null,
                          onView: () async {
                            try {
                              await _openArchivedDetails(
                                news: n,
                                vm: vm,
                              );
                            } catch (e) {
                              if (!mounted) return;

                              if (_isOfflineLikeError(e)) {
                                _setOfflineWarning(true);
                                return;
                              }

                              _showError(
                                _cleanError(e.toString()),
                              );
                            }
                          },
                        ),
                      );
                    },
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

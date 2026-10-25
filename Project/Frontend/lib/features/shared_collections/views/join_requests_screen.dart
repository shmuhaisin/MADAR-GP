import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/app_confirm_dialog.dart';
import '../../../common_theme/ui/app_top_message.dart';
import '../../../common_theme/ui/navy_header_clip.dart';
import '../viewmodel/shared_collections_details_vm.dart';

class JoinRequestsScreen extends StatefulWidget {
  const JoinRequestsScreen({super.key});

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen>
    with WidgetsBindingObserver {
  static const String _offlineCacheMessage =
      'أنت غير متصل بالإنترنت، يتم عرض آخر بيانات محفوظة';

  StreamSubscription<dynamic>? _connectivitySub;
  Timer? _internetVerifyTimer;

  bool _showOfflineCacheWarning = false;
  bool _checkingConnection = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<OwnedCollectionDetailsViewModel>().loadJoinRequests();
      unawaited(_refreshConnectionState(reloadWhenOnline: false));
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

      final vm = context.read<OwnedCollectionDetailsViewModel>();
      final hasStaleOfflineError = _isOfflineApiMessage(vm.joinRequestsError);

      if (reloadWhenOnline || hasStaleOfflineError) {
        await vm.loadJoinRequests();

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

  String _dateOnly(String iso) {
    final s = iso.trim();

    if (s.isEmpty) return '';
    if (s.length >= 10) return s.substring(0, 10);

    return s;
  }

  bool _isOfflineApiMessage(String? message) {
    final m = (message ?? '').trim();

    return m.contains('غير متصل') ||
        m.contains('لا يوجد اتصال') ||
        m.contains('بدون إنترنت') ||
        m.contains('آخر بيانات محفوظة') ||
        m.toLowerCase().contains('connection') ||
        m.toLowerCase().contains('network') ||
        m.toLowerCase().contains('socket') ||
        m.toLowerCase().contains('timeout');
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

    if (lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout')) {
      return 'تعذّر الاتصال بالخادم، تحقق من الإنترنت';
    }

    if (lower.contains('404') ||
        lower.contains('not found') ||
        msg.contains('غير موجود')) {
      return 'لم يتم العثور على الطلب';
    }

    if (lower.contains('409') ||
        lower.contains('conflict') ||
        msg.contains('موجود') ||
        msg.contains('مسبق')) {
      return 'تم التعامل مع هذا الطلب مسبقًا';
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

  void _showError(String message) {
    if (!mounted) return;

    if (_isOfflineLikeError(message)) {
      _setOfflineWarning(true);
      return;
    }

    AppTopMessage.show(
      context,
      text: _cleanError(message),
      type: TopMsgType.error,
    );
  }

  void _showActionOfflineMessage(String message) {
    if (!mounted) return;

    _setOfflineWarning(true);

    AppTopMessage.show(
      context,
      text: message,
      type: TopMsgType.error,
    );
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

  Future<void> _acceptRequest({
    required OwnedCollectionDetailsViewModel vm,
    required String requestId,
    required String username,
  }) async {
    final online = await _ensureOnlineForAction(
      'لا يمكن قبول طلب الانضمام بدون إنترنت',
    );

    if (!online || !mounted) return;

    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'قبول الطلب',
      message: username.trim().isEmpty
          ? 'هل تريد قبول هذا العضو إلى مجموعتك؟'
          : 'هل تريد قبول "$username" إلى مجموعتك؟',
      confirmText: 'نعم',
      cancelText: 'لا',
      confirmColor: const Color(0xFFF05260),
    );

    if (!confirmed || !mounted) return;

    try {
      await vm.acceptRequest(requestId);

      if (!mounted) return;

      if (vm.joinRequestsError != null &&
          vm.joinRequestsError!.trim().isNotEmpty) {
        if (_isOfflineLikeError(vm.joinRequestsError)) {
          _showActionOfflineMessage(
            'لا يمكن قبول طلب الانضمام بدون إنترنت',
          );
          return;
        }

        _showError(vm.joinRequestsError!);
        return;
      }

      _showSuccess('تم قبول طلب الانضمام بنجاح');
    } catch (e) {
      if (!mounted) return;

      if (_isOfflineLikeError(e)) {
        _showActionOfflineMessage(
          'لا يمكن قبول طلب الانضمام بدون إنترنت',
        );
        return;
      }

      _showError(e.toString());
    }
  }

  Future<void> _rejectRequest({
    required OwnedCollectionDetailsViewModel vm,
    required String requestId,
    required String username,
  }) async {
    final online = await _ensureOnlineForAction(
      'لا يمكن رفض طلب الانضمام بدون إنترنت',
    );

    if (!online || !mounted) return;

    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'رفض الطلب',
      message: username.trim().isEmpty
          ? 'هل أنت متأكد من رفض هذا الطلب؟'
          : 'هل أنت متأكد من رفض طلب "$username"؟',
      confirmText: 'نعم',
      cancelText: 'لا',
      confirmColor: const Color(0xFFF05260),
    );

    if (!confirmed || !mounted) return;

    try {
      await vm.rejectRequest(requestId);

      if (!mounted) return;

      if (vm.joinRequestsError != null &&
          vm.joinRequestsError!.trim().isNotEmpty) {
        if (_isOfflineLikeError(vm.joinRequestsError)) {
          _showActionOfflineMessage(
            'لا يمكن رفض طلب الانضمام بدون إنترنت',
          );
          return;
        }

        _showError(vm.joinRequestsError!);
        return;
      }

      _showSuccess('تم رفض طلب الانضمام بنجاح');
    } catch (e) {
      if (!mounted) return;

      if (_isOfflineLikeError(e)) {
        _showActionOfflineMessage(
          'لا يمكن رفض طلب الانضمام بدون إنترنت',
        );
        return;
      }

      _showError(e.toString());
    }
  }

  Future<void> _retryLoadRequests(OwnedCollectionDetailsViewModel vm) async {
    await vm.loadJoinRequests();

    if (!mounted) return;

    if (vm.joinRequestsError != null &&
        vm.joinRequestsError!.trim().isNotEmpty) {
      if (_isOfflineLikeError(vm.joinRequestsError)) {
        _setOfflineWarning(true);
        return;
      }

      _showError(vm.joinRequestsError!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OwnedCollectionDetailsViewModel>();

    final shouldShowOfflineBanner =
        _showOfflineCacheWarning || _isOfflineApiMessage(vm.joinRequestsError);

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
                          'طلبات الانضمام',
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
            if (shouldShowOfflineBanner)
              _offlineBanner(_offlineCacheMessage),
            Expanded(
              child: Builder(
                builder: (_) {
                  if (vm.joinRequestsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (vm.joinRequestsError != null &&
                      !_isOfflineApiMessage(vm.joinRequestsError)) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _cleanError(vm.joinRequestsError),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.subText,
                                fontFamily: 'NotoSansArabic',
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: () => _retryLoadRequests(vm),
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

                  final requests = vm.joinRequests;

                  if (requests.isEmpty) {
                    return Center(
                      child: Text(
                        'لا توجد طلبات انضمام',
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
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, i) {
                      final request = requests[i];
                      final dateText = _dateOnly(request.requestDate);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                                color: Colors.black.withOpacity(0.08),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.navy,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text(
                                        request.username,
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.navy,
                                          fontFamily: 'NotoSansArabic',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.calendar_month,
                                          size: 16,
                                          color: AppColors.subText,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          dateText,
                                          style: const TextStyle(
                                            color: AppColors.subText,
                                            fontSize: 13,
                                            fontFamily: 'NotoSansArabic',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              InkWell(
                                onTap: () => _acceptRequest(
                                  vm: vm,
                                  requestId: request.id,
                                  username: request.username,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Color.fromARGB(255, 5, 198, 140),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              InkWell(
                                onTap: () => _rejectRequest(
                                  vm: vm,
                                  requestId: request.id,
                                  username: request.username,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: AppColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 24,
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
          ],
        ),
      ),
    );
  }
}

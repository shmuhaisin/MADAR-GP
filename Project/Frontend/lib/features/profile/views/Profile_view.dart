// ignore_for_file: file_names

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/navy_header_clip.dart';
import '../../../common_theme/ui/app_top_message.dart';
import '../../../common_theme/ui/app_confirm_dialog.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/auth_api.dart';

import '../../login-signup/views/login_view.dart';
import '../../login-signup/views/otp_verify_view.dart';
import '../../login-signup/viewmodel/login_viewmodel.dart';

import '../../notifications/viewmodel/notifications_history_vm.dart';
import '../../notifications/viewmodel/semantic_notifications_vm.dart';

import '../model/profile_model.dart';
import '../viewmodel/profile_viewmodel.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _phoneDigitsCtrl = TextEditingController();

  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _dobFocus = FocusNode();

  bool _filledOnceForEdit = false;
  bool _prevEditing = false;
  bool _showEditOfflineWarning = false;

  String _selectedProfileDialCode = '+966';
  String _selectedProfileCountryCode = 'SA';

  Color _op(Color c, double o) => c.withAlpha((o * 255).round());

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final vm = context.read<ProfileViewModel>();

      if (vm.profile == null && !vm.loading) {
        vm.loadProfile();
      }
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    _phoneDigitsCtrl.dispose();

    _usernameFocus.dispose();
    _emailFocus.dispose();
    _dobFocus.dispose();

    super.dispose();
  }

  void _clearOtherSessionProviders() {
    context.read<NotificationHistoryVM>().clear();
    context.read<SemanticNotificationsVM>().clear();
    context.read<LoginViewModel>().clear();
  }

  void _goToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
      (_) => false,
    );
  }

  String _formatDob(DateTime? d) {
    if (d == null) return '';

    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');

    return '${d.year}-$mm-$dd';
  }

  Future<void> _pickDate(BuildContext context, ProfileViewModel vm) async {
    final now = DateTime.now();
    final maxAllowedDob = DateTime(now.year - 17, now.month, now.day);

    DateTime initial = maxAllowedDob;

    final current = _dobCtrl.text.trim();

    if (current.isNotEmpty) {
      final parsed = DateTime.tryParse(current);

      if (parsed != null) {
        final parsedOnly = DateTime(parsed.year, parsed.month, parsed.day);

        if (!parsedOnly.isAfter(maxAllowedDob)) {
          initial = parsedOnly;
        }
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: maxAllowedDob,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.navy,
                ),
          ),
          child: child!,
        ),
      ),
    );

    if (picked != null) {
      _dobCtrl.text = _formatDob(picked);
      vm.onBirthdateChanged(_dobCtrl.text);
    }
  }

  String _extractLocalDigits(String phone) {
    var d = phone.replaceAll(RegExp(r'\D'), '');

    if (phone.trim().startsWith('+966') && d.startsWith('966')) {
      d = d.substring(3);
    } else if (phone.trim().startsWith('+971') && d.startsWith('971')) {
      d = d.substring(3);
    } else if (phone.trim().startsWith('+20') && d.startsWith('20')) {
      d = d.substring(2);
    }

    d = d.replaceFirst(RegExp(r'^0+'), '');

    return d;
  }

  String _buildFullPhoneFromDialAndDigits(
    String dialCode,
    String localDigits,
  ) {
    var local = localDigits.replaceAll(RegExp(r'\D'), '');
    local = local.replaceFirst(RegExp(r'^0+'), '');

    return '$dialCode$local';
  }

  String _normalizePhoneForCompare(String phone) {
    return phone.replaceAll(RegExp(r'\s+'), '');
  }

  bool _isNoInternetError(Object error) {
    if (error is DioException) {
      if (error.error is SocketException) return true;

      final raw = '${error.error ?? ''} ${error.message ?? ''}'.toLowerCase();

      return raw.contains('failed host lookup') ||
          raw.contains('network is unreachable') ||
          raw.contains('no address associated with hostname') ||
          raw.contains('temporary failure in name resolution');
    }

    final raw = error.toString().toLowerCase();

    return raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('no address associated with hostname') ||
        raw.contains('temporary failure in name resolution');
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 3),
      );

      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _requestAndVerifyPhoneChangeOtp({
    required ProfileViewModel vm,
    required String newPhoneFull,
  }) async {
    try {
      final authApi = AuthApi(ApiClient());

      await authApi.requestPhoneChangeOtp(phoneNumber: newPhoneFull);

      if (!mounted) return null;

      final result = await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => OtpVerifyView(
            phone: newPhoneFull,
            flow: OtpFlow.changePhone,
          ),
        ),
      );

      if (result is Map) {
        final token = result['phoneChangeVerificationToken']?.toString();

        if (token != null && token.trim().isNotEmpty) {
          return token.trim();
        }
      }

      return null;
    } catch (e) {
      if (!mounted) return null;

      final msg = ApiClient.formatDioError(e).toLowerCase();

      if (msg.contains('http 401')) {
        vm.applyApiError('انتهت الجلسة. سجّل الدخول مرة أخرى');
      } else if (msg.contains('phone already exists') ||
          msg.contains('duplicate phone')) {
        vm.applyExternalPhoneError('رقم الجوال مستخدم بالفعل');
      } else if (msg.contains('same as current')) {
        vm.applyExternalPhoneError('رقم الجوال الجديد مطابق للرقم الحالي');
      } else if (_isNoInternetError(e)) {
        vm.applyApiError('لا يوجد اتصال بالإنترنت على هذا الجهاز');
      } else if (msg.contains('500') ||
          msg.contains('502') ||
          msg.contains('503') ||
          msg.contains('504') ||
          msg.contains('server error') ||
          msg.contains('internal server error')) {
        vm.applyApiError(
          'حدث خطأ في الخادم أو في التطبيق. يرجى المحاولة مرة أخرى لاحقًا',
        );
      } else {
        vm.applyApiError('فشل إرسال رمز التحقق');
      }

      return null;
    }
  }

  void _fillControllersFromProfile(ProfileModel p) {
    _usernameCtrl.text = p.username;
    _emailCtrl.text = p.email;
    _dobCtrl.text = p.birthdate;

    final phone = p.phoneNumber.trim();

    if (phone.startsWith('+966')) {
      _selectedProfileDialCode = '+966';
      _selectedProfileCountryCode = 'SA';
    } else if (phone.startsWith('+971')) {
      _selectedProfileDialCode = '+971';
      _selectedProfileCountryCode = 'AE';
    } else if (phone.startsWith('+20')) {
      _selectedProfileDialCode = '+20';
      _selectedProfileCountryCode = 'EG';
    } else {
      _selectedProfileDialCode = '+966';
      _selectedProfileCountryCode = 'SA';
    }

    _phoneDigitsCtrl.text = _extractLocalDigits(phone);
  }

  InputDecoration _pillDec({
    required String label,
    required IconData icon,
    bool requiredMark = true,
    Widget? suffix,
    String? errorText,
    String? hint,
    TextDirection hintDir = TextDirection.rtl,
    Widget? prefixIconOverride,
  }) {
    return InputDecoration(
      label: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'NotoSansArabic',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.text.withOpacity(0.55),
          ),
          children: [
            TextSpan(text: label),
            if (requiredMark) ...const [
              TextSpan(text: ' '),
              TextSpan(
                text: '*',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'NotoSansArabic',
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      hintText: hint,
      hintTextDirection: hintDir,
      hintStyle: TextStyle(
        color: AppColors.text.withOpacity(0.35),
        fontWeight: FontWeight.w800,
        fontFamily: 'NotoSansArabic',
        fontSize: 13,
      ),
      errorText: errorText,
      filled: true,
      fillColor: Colors.white,
      prefixIcon:
          prefixIconOverride ?? Icon(icon, color: AppColors.navy, size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(
          color: AppColors.divider.withOpacity(0.9),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(
          color: AppColors.navy,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(
          color: AppColors.danger,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(
          color: AppColors.danger,
          width: 1.3,
        ),
      ),
      counterText: '',
    );
  }

  Widget _cardShell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.divider.withOpacity(0.85),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.045),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: child,
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    bool ltrValue = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.text.withOpacity(0.70),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textDirection: ltrValue ? TextDirection.ltr : TextDirection.rtl,
            textAlign: TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, ProfileViewModel vm) {
    return MadarNavyHeaderClip(
      headerHeight: 92,
      overlap: 0,
      sheetRadius: 0,
      child: SizedBox(
        height: 82,
        child: Center(
          child: Text(
            vm.isEditing ? 'تعديل الملف الشخصي' : 'ملفي الشخصي',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              fontFamily: 'NotoSansArabic',
            ),
          ),
        ),
      ),
    );
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
    );
  }

  Widget _interestChip(ProfileViewModel vm, Interest tag) {
    final selected = vm.selectedInterests.contains(tag);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: vm.isEditing
          ? () async {
              await vm.toggleInterest(tag);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [AppColors.navy, AppColors.accentBlue],
                )
              : null,
          color: selected ? null : Colors.white,
          border: Border.all(
            color: selected
                ? Colors.white.withOpacity(0.20)
                : AppColors.divider.withOpacity(0.9),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: selected ? 14 : 10,
              offset: const Offset(0, 8),
              color: selected
                  ? AppColors.accentBlue2.withOpacity(0.25)
                  : Colors.black.withOpacity(0.04),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              tag.labelAr,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : AppColors.navy,
                fontFamily: 'NotoSansArabic',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _apiErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.danger.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.danger,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.danger,
                fontFamily: 'NotoSansArabic',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profilePhoneIntlField(ProfileViewModel vm) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: IntlPhoneField(
        controller: _phoneDigitsCtrl,
        initialCountryCode: _selectedProfileCountryCode,
        disableLengthCheck: true,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        autovalidateMode: AutovalidateMode.disabled,
        languageCode: 'ar',
        enabled: vm.isEditing,
        style: const TextStyle(
          fontFamily: 'NotoSansArabic',
          fontWeight: FontWeight.w900,
          fontSize: 14,
          color: AppColors.navy,
        ),
        dropdownTextStyle: const TextStyle(
          fontFamily: 'NotoSansArabic',
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: AppColors.navy,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')),
          TextInputFormatter.withFunction((oldValue, newValue) {
            final text = newValue.text;

            final converted = text
                .replaceAll('٠', '0')
                .replaceAll('١', '1')
                .replaceAll('٢', '2')
                .replaceAll('٣', '3')
                .replaceAll('٤', '4')
                .replaceAll('٥', '5')
                .replaceAll('٦', '6')
                .replaceAll('٧', '7')
                .replaceAll('٨', '8')
                .replaceAll('٩', '9');

            return TextEditingValue(
              text: converted,
              selection: TextSelection.collapsed(offset: converted.length),
            );
          }),
        ],
        decoration: _pillDec(
          label: 'رقم الجوال',
          icon: Icons.phone_iphone,
          hint: _selectedProfileDialCode == '+966' ? '5XXXXXXXX' : 'رقم الهاتف',
          hintDir: TextDirection.ltr,
          errorText: vm.phoneError,
          prefixIconOverride: null,
        ).copyWith(
          prefixIcon: null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 14,
          ),
          counterText: '',
          hintTextDirection: TextDirection.ltr,
        ),
        dropdownIconPosition: IconPosition.trailing,
        flagsButtonPadding: const EdgeInsetsDirectional.only(
          start: 8,
          end: 4,
        ),
        showCountryFlag: true,
        showDropdownIcon: true,
        onCountryChanged: (country) {
          setState(() {
            _selectedProfileDialCode = '+${country.dialCode}';
            _selectedProfileCountryCode = country.code;
          });

          vm.onPhoneChanged(
            dialCode: _selectedProfileDialCode,
            localDigits: _phoneDigitsCtrl.text,
          );
        },
        onChanged: (phone) {
          _selectedProfileDialCode = phone.countryCode;

          vm.onPhoneChanged(
            dialCode: phone.countryCode,
            localDigits: phone.number,
          );
        },
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  Future<bool> _confirmDelete() {
    return AppConfirmDialog.show(
      context,
      title: 'حذف الحساب',
      message: 'هل أنت متأكد أنك تريد حذف هذا الحساب؟',
      confirmText: 'نعم',
      cancelText: 'لا',
      confirmColor: const Color(0xFFF05260),
    );
  }

  Future<bool> _confirmUpdateProfile() {
    return AppConfirmDialog.show(
      context,
      title: 'حفظ التعديلات',
      message: 'هل تريد حفظ التعديلات على ملفك الشخصي؟',
      confirmText: 'نعم',
      cancelText: 'لا',
      confirmColor: const Color(0xFFF05260),
    );
  }

  Future<void> _save(ProfileViewModel vm) async {
    FocusScope.of(context).unfocus();

    final currentPhone = vm.profile?.phoneNumber ?? '';

    final newPhoneFull = _buildFullPhoneFromDialAndDigits(
      _selectedProfileDialCode,
      _phoneDigitsCtrl.text,
    );

    final isValid = vm.validateForSave(
      username: _usernameCtrl.text,
      email: _emailCtrl.text,
      birthdate: _dobCtrl.text,
      phoneNumber: newPhoneFull,
    );

    if (!isValid) return;

    String? phoneChangeVerificationToken;

    final phoneChanged = _normalizePhoneForCompare(newPhoneFull) !=
        _normalizePhoneForCompare(currentPhone);

    if (phoneChanged) {
      phoneChangeVerificationToken = await _requestAndVerifyPhoneChangeOtp(
        vm: vm,
        newPhoneFull: newPhoneFull,
      );

      if (!mounted) return;

      if (phoneChangeVerificationToken == null ||
          phoneChangeVerificationToken.trim().isEmpty) {
        return;
      }
    } else {
      final confirmed = await _confirmUpdateProfile();

      if (!confirmed) return;
    }

    final msg = await vm.saveProfile(
      username: _usernameCtrl.text,
      email: _emailCtrl.text,
      birthdate: _dobCtrl.text,
      phoneNumber: newPhoneFull,
      phoneChangeVerificationToken: phoneChangeVerificationToken,
    );

    if (!mounted) return;

    final hasFieldError =
        vm.usernameError != null ||
        vm.emailError != null ||
        vm.birthdateError != null ||
        vm.phoneError != null ||
        vm.interestsError != null;

    if (msg != null) {
      if (!hasFieldError) {
        AppTopMessage.show(
          context,
          text: msg,
          type: TopMsgType.error,
        );
      }
      return;
    }

    setState(() {
      _showEditOfflineWarning = false;
    });

    AppTopMessage.show(
      context,
      text: 'تم حفظ التعديلات بنجاح',
      type: TopMsgType.success,
    );
  }

  Future<void> _startEditing(ProfileViewModel vm) async {
    final online = await _hasInternetConnection();

    if (!mounted) return;

    if (!online) {
      setState(() {
        _showEditOfflineWarning = true;
      });

      AppTopMessage.show(
        context,
        text: 'لا يوجد اتصال بالإنترنت. لا يمكن تعديل الملف الشخصي حاليًا',
        type: TopMsgType.error,
      );

      return;
    }

    setState(() {
      _showEditOfflineWarning = false;
    });

    vm.startEdit();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(
                fontFamily: 'NotoSansArabic',
              ),
        ),
        child: Scaffold(
          backgroundColor: AppColors.softBg,
          body: Consumer<ProfileViewModel>(
            builder: (context, vm, _) {
              if (vm.isEditing != _prevEditing) {
                _prevEditing = vm.isEditing;
                _filledOnceForEdit = false;
              }

              if (vm.isEditing && vm.profile != null && !_filledOnceForEdit) {
                _filledOnceForEdit = true;
                _fillControllersFromProfile(vm.profile!);
              }

              return CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(context, vm)),

                  if (_isOfflineApiMessage(vm.apiError) ||
                      _showEditOfflineWarning)
                    SliverToBoxAdapter(
                      child: _offlineBanner(
                        _showEditOfflineWarning
                            ? 'أنت غير متصل بالإنترنت. يتم عرض آخر بيانات محفوظة.'
                            : vm.apiError!,
                      ),
                    ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    sliver: SliverToBoxAdapter(
                      child: _cardShell(
                        child: Builder(
                          builder: (_) {
                            if (vm.loading && vm.profile == null) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 30),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (vm.error != null) {
                              return Column(
                                children: [
                                  Text(
                                    vm.error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 46,
                                    child: ElevatedButton(
                                      onPressed: vm.loadProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.navy,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: const Text(
                                        'إعادة المحاولة',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            if (vm.profile == null) {
                              return const SizedBox.shrink();
                            }

                            final p = vm.profile!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'بيانات الحساب',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 11),
                                if (!vm.isEditing) ...[
                                  Center(
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: AppColors.softBg,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.divider,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.person_rounded,
                                        color: AppColors.navy,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  Center(
                                    child: Text(
                                      p.username,
                                      textDirection: TextDirection.ltr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        p.email,
                                        textDirection: TextDirection.ltr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: _op(AppColors.text, 0.70),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 11),
                                  Divider(
                                    color: AppColors.divider.withOpacity(0.60),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 10),
                                  _infoRow(
                                    label: 'سنة الميلاد',
                                    value: p.birthdate,
                                    ltrValue: true,
                                  ),
                                  const SizedBox(height: 10),
                                  Divider(
                                    color: AppColors.divider.withOpacity(0.60),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 10),
                                  _infoRow(
                                    label: 'رقم الجوال',
                                    value: p.phoneNumber,
                                    ltrValue: true,
                                  ),
                                ] else ...[
                                  TextField(
                                    controller: _usernameCtrl,
                                    focusNode: _usernameFocus,
                                    textDirection: TextDirection.ltr,
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[a-zA-Z0-9]'),
                                      ),
                                      LengthLimitingTextInputFormatter(8),
                                    ],
                                    decoration: _pillDec(
                                      label: 'اسم المستخدم',
                                      icon: Icons.person_outline,
                                      errorText: vm.usernameError,
                                      hint: 'مثال: userx12',
                                      hintDir: TextDirection.ltr,
                                    ),
                                    onChanged: vm.onUsernameChanged,
                                    onSubmitted: (_) {
                                      FocusScope.of(context).requestFocus(
                                        _emailFocus,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _emailCtrl,
                                    focusNode: _emailFocus,
                                    textDirection: TextDirection.ltr,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.deny(
                                        RegExp(
                                          r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
                                        ),
                                      ),
                                    ],
                                    decoration: _pillDec(
                                      label: 'البريد الإلكتروني',
                                      icon: Icons.mail_outline_rounded,
                                      errorText: vm.emailError,
                                    ),
                                    onChanged: vm.onEmailChanged,
                                    onSubmitted: (_) {
                                      FocusScope.of(context).requestFocus(
                                        _dobFocus,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _dobCtrl,
                                    focusNode: _dobFocus,
                                    readOnly: true,
                                    textDirection: TextDirection.ltr,
                                    onTap: () => _pickDate(context, vm),
                                    decoration: _pillDec(
                                      label: 'تاريخ الميلاد',
                                      icon: Icons.calendar_month_outlined,
                                      errorText: vm.birthdateError,
                                      suffix: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: AppColors.navy,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _profilePhoneIntlField(vm),
                                ],
                                if (vm.apiError != null &&
                                    !_isOfflineApiMessage(vm.apiError)) ...[
                                  const SizedBox(height: 12),
                                  _apiErrorBox(vm.apiError!),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    sliver: SliverToBoxAdapter(
                      child: (vm.profile == null)
                          ? const SizedBox.shrink()
                          : _cardShell(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color:
                                              AppColors.navy.withOpacity(0.10),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.interests_rounded,
                                          color: AppColors.navy,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          'اهتماماتي',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.navy,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.softBg,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: AppColors.divider,
                                          ),
                                        ),
                                        child: Text(
                                          '${vm.interestsCount} اهتمامات',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: _op(AppColors.text, 0.65),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'اختر اهتماماتك (واحدة على الأقل)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.text.withOpacity(0.85),
                                    ),
                                  ),
                                  if (vm.interestsError != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      vm.interestsError!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.danger,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'NotoSansArabic',
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: vm.allInterests
                                        .map((e) => _interestChip(vm, e))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 120),
                    sliver: SliverToBoxAdapter(
                      child: (vm.profile == null)
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.navy,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                    onPressed: vm.loading
                                        ? null
                                        : () async {
                                            if (!vm.isEditing) {
                                              await _startEditing(vm);
                                              return;
                                            }

                                            await _save(vm);
                                          },
                                    child: vm.loading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            vm.isEditing
                                                ? 'حفظ التعديلات'
                                                : 'تعديل الملف الشخصي',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              fontFamily: 'NotoSansArabic',
                                              fontSize: 15,
                                            ),
                                          ),
                                  ),
                                ),
                                if (vm.isEditing) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 52,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        vm.cancelEdit();

                                        setState(() {
                                          _showEditOfflineWarning = false;
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: _op(AppColors.text, 0.22),
                                          width: 1.6,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                      ),
                                      child: const Text(
                                        'إلغاء',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.navy,
                                          fontFamily: 'NotoSansArabic',
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 52,
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        final ok = await vm.signOut();

                                        if (!mounted) return;

                                        if (ok) {
                                          _clearOtherSessionProviders();
                                          _goToLogin();
                                        }
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: _op(AppColors.text, 0.22),
                                          width: 1.6,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                      ),
                                      child: Text(
                                        'تسجيل الخروج',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: _op(AppColors.text, 0.75),
                                          fontFamily: 'NotoSansArabic',
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 52,
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        final confirm = await _confirmDelete();

                                        if (!confirm) return;

                                        final ok = await vm.deleteAccount();

                                        if (!mounted) return;

                                        if (ok) {
                                          _clearOtherSessionProviders();
                                          _goToLogin();
                                        } else {
                                          AppTopMessage.show(
                                            context,
                                            text: 'فشل حذف الحساب',
                                            type: TopMsgType.error,
                                          );
                                        }
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: AppColors.danger,
                                          width: 1.6,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                      ),
                                      child: const Text(
                                        'حذف الحساب',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.danger,
                                          fontFamily: 'NotoSansArabic',
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
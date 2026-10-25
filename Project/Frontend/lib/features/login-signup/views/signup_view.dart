// signup_view.dart
// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/app_top_message.dart';
import '../model/auth_model.dart';
import '../viewmodel/signup_viewmodel.dart';
import 'login_view.dart';
import 'otp_verify_view.dart';

class SignUpView extends StatefulWidget {
  const SignUpView({super.key});

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView>
    with TickerProviderStateMixin {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _dobCtrl = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _dobFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  late final AnimationController _backgroundController;
  late final AnimationController _fadeController;

  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  final List<Interest> allInterests = Interest.values;

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();

    _fade = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.045),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _fadeController.dispose();

    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _dobCtrl.dispose();

    _nameFocus.dispose();
    _emailFocus.dispose();
    _dobFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();

    super.dispose();
  }

  String _formatDob(DateTime? date) {
    if (date == null) return '';
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  void _syncControllersFromVm(SignUpViewModel vm) {
    if (_nameCtrl.text != vm.username) {
      _nameCtrl.text = vm.username;
      _nameCtrl.selection =
          TextSelection.collapsed(offset: _nameCtrl.text.length);
    }

    if (_emailCtrl.text != vm.email) {
      _emailCtrl.text = vm.email;
      _emailCtrl.selection =
          TextSelection.collapsed(offset: _emailCtrl.text.length);
    }

    if (_phoneCtrl.text != vm.phoneDigits) {
      _phoneCtrl.text = vm.phoneDigits;
      _phoneCtrl.selection =
          TextSelection.collapsed(offset: _phoneCtrl.text.length);
    }

    if (_passwordCtrl.text != vm.password) {
      _passwordCtrl.text = vm.password;
      _passwordCtrl.selection =
          TextSelection.collapsed(offset: _passwordCtrl.text.length);
    }

    final wantedDob = _formatDob(vm.birthdate);
    if (_dobCtrl.text != wantedDob) {
      _dobCtrl.text = wantedDob;
      _dobCtrl.selection =
          TextSelection.collapsed(offset: _dobCtrl.text.length);
    }
  }

  Future<void> _pickDate(BuildContext context, SignUpViewModel vm) async {
    final now = DateTime.now();

    // Older than 16.
    final maxAllowedDob = DateTime(now.year - 17, now.month, now.day);

    final initial = vm.birthdate ?? maxAllowedDob;

    final picked = await showDatePicker(
      context: context,
      locale: const Locale('ar'),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'اختر سنة الميلاد',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
      errorFormatText: 'صيغة غير صحيحة',
      errorInvalidText: 'تاريخ غير صالح',
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: maxAllowedDob,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: AppColors.navy,
                  ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      vm.setDob(picked);
      _dobCtrl.text = _formatDob(picked);
    }
  }

  Future<void> _submit(SignUpViewModel vm) async {
    FocusScope.of(context).unfocus();

    if (vm.loading) return;

    final ok = await vm.submitStart();
    if (!mounted) return;

    if (!ok) return;

    AppTopMessage.show(
      context,
      text: 'تم إرسال رمز التحقق بنجاح',
      type: TopMsgType.success,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerifyView(
          phone: vm.phoneNumberFull,
          flow: OtpFlow.signup,
          prefillIdentifier: vm.email.trim(),
        ),
      ),
    );
  }

  Widget _logoCore(double size) {
    final radius = size * 0.24;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            blurRadius: 38,
            spreadRadius: 4,
            color: AppColors.accentBlue.withOpacity(0.28),
          ),
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, 14),
            color: Colors.black.withOpacity(0.22),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: EdgeInsets.all(size * 0.08),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withOpacity(0.24),
                width: 1.2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.06),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius * 0.72),
              child: Image.asset(
                'assets/images/madar-logo1.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _labelWithStar(String text, {bool required = false}) {
    return RichText(
      textDirection: TextDirection.rtl,
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'NotoSansArabic',
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: AppColors.text.withOpacity(0.58),
        ),
        children: [
          TextSpan(text: text),
          if (required) ...const [
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
    );
  }

  InputDecoration _pillDec({
    required String label,
    required IconData icon,
    bool requiredMark = false,
    Widget? suffix,
    String? errorText,
    String? hint,
    TextDirection hintDir = TextDirection.rtl,
  }) {
    return InputDecoration(
      label: _labelWithStar(label, required: requiredMark),
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
      errorMaxLines: 2,
      errorStyle: const TextStyle(
        fontFamily: 'NotoSansArabic',
        color: Color(0xFFFFD6D6),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(
        icon,
        color: AppColors.navy,
        size: 20,
      ),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.75),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(
          color: AppColors.accentBlue.withOpacity(0.95),
          width: 1.5,
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
          width: 1.4,
        ),
      ),
      counterText: '',
    );
  }

  Widget _primaryBtn({
    required String label,
    required VoidCallback onTap,
    required bool loading,
    required bool enabled,
    required double scale,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54 * scale,
      child: ElevatedButton(
        onPressed: enabled && !loading ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withOpacity(0.35),
          foregroundColor: AppColors.navy,
          disabledForegroundColor: Colors.white.withOpacity(0.70),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.navy,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                  fontFamily: 'NotoSansArabic',
                ),
              ),
      ),
    );
  }

  Widget _dividerOr(double scale) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.white.withOpacity(0.24),
            height: 1,
          ),
        ),
        SizedBox(width: 10 * scale),
        Text(
          'أو',
          style: TextStyle(
            fontSize: 12 * scale,
            fontWeight: FontWeight.w900,
            color: Colors.white.withOpacity(0.65),
            fontFamily: 'NotoSansArabic',
          ),
        ),
        SizedBox(width: 10 * scale),
        Expanded(
          child: Divider(
            color: Colors.white.withOpacity(0.24),
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _interestChip(SignUpViewModel vm, Interest tag, double scale) {
    final selected = vm.interests.contains(tag);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => vm.toggleInterest(tag),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 10 * scale,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? Colors.white : Colors.white.withOpacity(0.10),
          border: Border.all(
            color: selected
                ? Colors.white
                : Colors.white.withOpacity(0.18),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: selected ? 16 : 10,
              offset: const Offset(0, 8),
              color: selected
                  ? AppColors.accentBlue.withOpacity(0.20)
                  : Colors.black.withOpacity(0.06),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.navy,
                size: 16,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              tag.labelAr,
              style: TextStyle(
                fontSize: 13 * scale,
                fontWeight: FontWeight.w900,
                color: selected ? AppColors.navy : Colors.white,
                fontFamily: 'NotoSansArabic',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _apiErrorBox(String message) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.danger.withOpacity(0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.danger.withOpacity(0.35),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFFD6D6),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD6D6),
                    height: 1.4,
                    fontFamily: 'NotoSansArabic',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneField(SignUpViewModel vm) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: IntlPhoneField(
        initialCountryCode: 'SA',
        disableLengthCheck: true,
        keyboardType: TextInputType.phone,
        languageCode: 'ar',
        controller: _phoneCtrl,
        textInputAction: TextInputAction.next,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')),
          TextInputFormatter.withFunction((oldValue, newValue) {
            final converted = newValue.text
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
          requiredMark: true,
          icon: Icons.phone_iphone,
          errorText: vm.phoneError ?? vm.countryCodeError,
          hint: vm.countryDialCode == '+966' ? '5XXXXXXXX' : 'رقم الهاتف',
          hintDir: TextDirection.ltr,
        ),
        dropdownTextStyle: const TextStyle(
          fontFamily: 'NotoSansArabic',
          fontWeight: FontWeight.w900,
          fontSize: 13,
          color: AppColors.navy,
        ),
        style: const TextStyle(
          fontFamily: 'NotoSansArabic',
          fontWeight: FontWeight.w900,
          fontSize: 14,
          color: AppColors.navy,
        ),
        dropdownIconPosition: IconPosition.trailing,
        flagsButtonPadding: const EdgeInsetsDirectional.only(start: 10, end: 6),
        showCountryFlag: true,
        showDropdownIcon: true,
        onCountryChanged: (country) {
          vm.setCountryDialCode('+${country.dialCode}');
        },
        onChanged: (phone) {
          vm.setCountryDialCode(phone.countryCode);
          vm.setPhoneDigits(phone.number);
        },
        onSubmitted: (_) {
          FocusScope.of(context).requestFocus(_passwordFocus);
        },
      ),
    );
  }

  Widget _form(SignUpViewModel vm, double scale) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'إنشاء حساب جديد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20 * scale,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontFamily: 'NotoSansArabic',
            ),
          ),

          SizedBox(height: 8 * scale),

          Text(
            'ابدأ رحلتك مع مدار ببيانات بسيطة واهتمامات تختارها أنت.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13 * scale,
              fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.78),
              height: 1.55,
              fontFamily: 'NotoSansArabic',
            ),
          ),

          SizedBox(height: 24 * scale),

          TextFormField(
            controller: _nameCtrl,
            focusNode: _nameFocus,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: _pillDec(
              label: 'اسم المستخدم',
              requiredMark: true,
              icon: Icons.person_outline_rounded,
              errorText: vm.nameError,
              hint: 'مثال: userx12',
              hintDir: TextDirection.ltr,
            ),
            onChanged: vm.setName,
            onFieldSubmitted: (_) {
              FocusScope.of(context).requestFocus(_emailFocus);
            },
          ),

          SizedBox(height: 13 * scale),

          TextFormField(
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
              requiredMark: true,
              icon: Icons.mail_outline_rounded,
              errorText: vm.emailError,
            ),
            onChanged: vm.setEmail,
            onFieldSubmitted: (_) {
              FocusScope.of(context).requestFocus(_dobFocus);
            },
          ),

          SizedBox(height: 13 * scale),

          TextFormField(
            controller: _dobCtrl,
            focusNode: _dobFocus,
            readOnly: true,
            textDirection: TextDirection.ltr,
            onTap: () => _pickDate(context, vm),
            decoration: _pillDec(
              label: 'تاريخ الميلاد',
              requiredMark: true,
              icon: Icons.calendar_month_outlined,
              errorText: vm.dobError,
              suffix: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.navy,
              ),
            ),
          ),

          SizedBox(height: 13 * scale),

          _phoneField(vm),

          SizedBox(height: 13 * scale),

          TextFormField(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            textDirection: TextDirection.ltr,
            obscureText: vm.obscure,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.deny(
                RegExp(
                  r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
                ),
              ),
            ],
            onFieldSubmitted: (_) {
              if (vm.canSubmit && !vm.loading) {
                _submit(vm);
              }
            },
            decoration: _pillDec(
              label: 'كلمة المرور',
              requiredMark: true,
              icon: Icons.lock_outline_rounded,
              errorText: vm.passError,
              suffix: IconButton(
                onPressed: vm.toggleObscure,
                icon: Icon(
                  vm.obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.navy,
                ),
              ),
            ),
            onChanged: vm.setPassword,
          ),

          SizedBox(height: 18 * scale),

          Text(
            'اختر اهتماماتك (واحدة على الأقل)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5 * scale,
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.86),
              fontFamily: 'NotoSansArabic',
            ),
          ),

          if (vm.interestsError != null) ...[
            SizedBox(height: 6 * scale),
            Text(
              vm.interestsError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFD6D6),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontFamily: 'NotoSansArabic',
              ),
            ),
          ],

          SizedBox(height: 12 * scale),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10 * scale,
            runSpacing: 10 * scale,
            children: allInterests
                .map((interest) => _interestChip(vm, interest, scale))
                .toList(),
          ),

          if (vm.apiError != null) ...[
            SizedBox(height: 16 * scale),
            _apiErrorBox(vm.apiError!),
          ],

          SizedBox(height: 20 * scale),

          _primaryBtn(
            label: 'إنشاء حساب',
            loading: vm.loading,
            enabled: vm.canSubmit,
            scale: scale,
            onTap: () => _submit(vm),
          ),

          SizedBox(height: 16 * scale),

          _dividerOr(scale),

          SizedBox(height: 16 * scale),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'لديك حساب بالفعل؟ ',
                style: TextStyle(
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.72),
                  fontFamily: 'NotoSansArabic',
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginView()),
                  );
                },
                child: Text(
                  'تسجيل الدخول',
                  style: TextStyle(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                    fontFamily: 'NotoSansArabic',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SignUpViewModel(),
      child: Consumer<SignUpViewModel>(
        builder: (context, vm, _) {
          _syncControllersFromVm(vm);

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Theme(
              data: Theme.of(context).copyWith(
                textTheme: Theme.of(context).textTheme.apply(
                      fontFamily: 'NotoSansArabic',
                    ),
              ),
              child: Scaffold(
                backgroundColor: AppColors.navy,
                body: AnimatedBuilder(
                  animation: _backgroundController,
                  builder: (context, _) {
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                                colors: [
                                  Color(0xFF06152F),
                                  Color(0xFF173B7E),
                                  Color(0xFF05132B),
                                ],
                              ),
                            ),
                          ),
                        ),

                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SoftParticlesPainter(
                              progress: _backgroundController.value,
                            ),
                          ),
                        ),

                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SoftRibbonsPainter(
                              progress: _backgroundController.value,
                            ),
                          ),
                        ),

                        Positioned(
                          top: -130,
                          right: -90,
                          child: Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.045),
                            ),
                          ),
                        ),

                        Positioned(
                          bottom: -160,
                          left: -115,
                          child: Container(
                            width: 340,
                            height: 340,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accentBlue.withOpacity(0.10),
                            ),
                          ),
                        ),

                        SafeArea(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final h = constraints.maxHeight;
                              final compact = h < 760;
                              final scale = compact ? 0.90 : 1.0;
                              final logoSize = compact ? 118.0 : 135.0;

                              return SingleChildScrollView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minHeight: h),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      24,
                                      compact ? 24 : 34,
                                      24,
                                      24,
                                    ),
                                    child: FadeTransition(
                                      opacity: _fade,
                                      child: SlideTransition(
                                        position: _slide,
                                        child: Column(
                                          children: [
                                            _logoCore(logoSize),
                                            SizedBox(height: 28 * scale),
                                            _form(vm, scale),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SoftParticlesPainter extends CustomPainter {
  final double progress;

  _SoftParticlesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = Colors.white.withOpacity(0.20);

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.040)
      ..strokeWidth = 1;

    final points = <Offset>[];

    for (int i = 0; i < 24; i++) {
      final seed = i * 39.0;

      final x =
          (math.sin(seed + progress * math.pi * 2) * 0.5 + 0.5) * size.width;

      final y = ((i * 79.0) % size.height) +
          math.sin(progress * math.pi * 2 + i) * 8;

      points.add(Offset(x, y % size.height));
    }

    for (int i = 0; i < points.length; i++) {
      final p = points[i];

      canvas.drawCircle(
        p,
        i % 4 == 0 ? 1.8 : 1.1,
        dotPaint,
      );

      if (i > 0 && i % 4 == 0) {
        final prev = points[i - 1];

        if ((p - prev).distance < 140) {
          canvas.drawLine(p, prev, linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SoftParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SoftRibbonsPainter extends CustomPainter {
  final double progress;

  _SoftRibbonsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.025);

    final paint2 = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.accentBlue.withOpacity(0.035);

    final shift = math.sin(progress * math.pi * 2) * 18;

    final path1 = Path()
      ..moveTo(-40, size.height * 0.18 + shift)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.10 + shift,
        size.width + 40,
        size.height * 0.22 + shift,
      )
      ..lineTo(size.width + 40, size.height * 0.36 + shift)
      ..quadraticBezierTo(
        size.width * 0.40,
        size.height * 0.24 + shift,
        -40,
        size.height * 0.32 + shift,
      )
      ..close();

    final path2 = Path()
      ..moveTo(-40, size.height * 0.68 - shift)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.56 - shift,
        size.width + 40,
        size.height * 0.72 - shift,
      )
      ..lineTo(size.width + 40, size.height * 0.90 - shift)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.78 - shift,
        -40,
        size.height * 0.86 - shift,
      )
      ..close();

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _SoftRibbonsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
// forgot_password_phone_view.dart
// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/app_top_message.dart';
import '../viewmodel/forgot_password_viewmodel.dart';
import 'otp_verify_view.dart';

class ForgotPasswordPhoneView extends StatefulWidget {
  const ForgotPasswordPhoneView({super.key});

  @override
  State<ForgotPasswordPhoneView> createState() =>
      _ForgotPasswordPhoneViewState();
}

class _ForgotPasswordPhoneViewState extends State<ForgotPasswordPhoneView>
    with TickerProviderStateMixin {
  final TextEditingController _phoneCtrl = TextEditingController();

  late final AnimationController _backgroundController;
  late final AnimationController _fadeController;

  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

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
    _phoneCtrl.dispose();
    super.dispose();
  }

  Color _withAlpha(Color color, double alpha) {
    return color.withAlpha((255 * alpha).round());
  }

  Future<void> _sendCode(ForgotPasswordPhoneViewModel vm) async {
    FocusScope.of(context).unfocus();

    if (vm.loading) return;

    final bool ok = await vm.submit();
    if (!mounted) return;

    if (!ok) return;

    AppTopMessage.show(
      context,
      text: 'تم إرسال رمز التحقق',
      type: TopMsgType.success,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerifyView(
          phone: vm.phoneFull,
          flow: OtpFlow.forgotPassword,
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

  Widget _requiredLabel(String text) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'NotoSansArabic',
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: AppColors.text.withOpacity(0.58),
        ),
        children: [
          TextSpan(text: text),
          const TextSpan(text: ' '),
          const TextSpan(
            text: '*',
            style: TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _pillDec({
    required Widget label,
    String? errorText,
    String? hint,
    TextDirection hintDir = TextDirection.ltr,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      label: label,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      hintText: hint,
      hintTextDirection: hintDir,
      hintStyle: TextStyle(
        color: _withAlpha(AppColors.text, 0.35),
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

  Widget _phoneField(ForgotPasswordPhoneViewModel vm) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: IntlPhoneField(
        controller: _phoneCtrl,
        initialCountryCode: 'SA',
        disableLengthCheck: true,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        autovalidateMode: AutovalidateMode.disabled,
        languageCode: 'ar',
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')),
          TextInputFormatter.withFunction((oldValue, newValue) {
            final String converted = newValue.text
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
          label: _requiredLabel('رقم الجوال'),
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
        onSubmitted: (_) => _sendCode(vm),
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
                    fontFamily: 'NotoSansArabic',
                    color: Color(0xFFFFD6D6),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
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
                  fontFamily: 'NotoSansArabic',
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }

  Widget _form(ForgotPasswordPhoneViewModel vm, double scale) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'نسيت كلمة المرور؟',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'NotoSansArabic',
              fontSize: 19 * scale,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),

          SizedBox(height: 8 * scale),

          Text(
            'اكتب رقم جوالك وسنرسل لك رمز تحقق لإعادة تعيين كلمة المرور.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'NotoSansArabic',
              fontSize: 13 * scale,
              fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.78),
              height: 1.55,
            ),
          ),

          SizedBox(height: 22 * scale),

          _phoneField(vm),

          if (vm.apiError != null) ...[
            SizedBox(height: 10 * scale),
            _apiErrorBox(vm.apiError!),
          ],

          SizedBox(height: 16 * scale),

          _primaryBtn(
            label: 'إرسال رمز التحقق',
            loading: vm.loading,
            enabled: vm.canSubmit,
            scale: scale,
            onTap: () => _sendCode(vm),
          ),

          SizedBox(height: 16 * scale),

          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                'رجوع إلى تسجيل الدخول',
                style: TextStyle(
                  fontFamily: 'NotoSansArabic',
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ForgotPasswordPhoneViewModel(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(
                  fontFamily: 'NotoSansArabic',
                ),
          ),
          child: Scaffold(
            backgroundColor: AppColors.navy,
            body: Consumer<ForgotPasswordPhoneViewModel>(
              builder: (context, vm, _) {
                if (_phoneCtrl.text != vm.phoneDigits) {
                  _phoneCtrl.text = vm.phoneDigits;
                  _phoneCtrl.selection = TextSelection.collapsed(
                    offset: _phoneCtrl.text.length,
                  );
                }

                return AnimatedBuilder(
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
                              final logoSize = compact ? 126.0 : 145.0;

                              return SingleChildScrollView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minHeight: h),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      24,
                                      compact ? 28 : 42,
                                      24,
                                      22,
                                    ),
                                    child: FadeTransition(
                                      opacity: _fade,
                                      child: SlideTransition(
                                        position: _slide,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _logoCore(logoSize),
                                            SizedBox(height: 38 * scale),
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
                );
              },
            ),
          ),
        ),
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
// login_view.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common_theme/ui/app_colors.dart';

import '../../../HomeShell.dart';
import '../viewmodel/login_viewmodel.dart';
import 'forgot_password_phone_view.dart';
import 'signup_view.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginView();
  }
}

class LoginView extends StatefulWidget {
  final String? prefillIdentifier;

  const LoginView({super.key, this.prefillIdentifier});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> with TickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  late final AnimationController _backgroundController;
  late final AnimationController _fadeController;

  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  bool _prefilledOnce = false;

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

    final prefill = widget.prefillIdentifier?.trim() ?? '';
    if (prefill.isNotEmpty) {
      _prefilledOnce = true;
      _userCtrl.text = prefill;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<LoginViewModel>().setUser(prefill);
      });
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _fadeController.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(LoginViewModel vm) async {
    FocusScope.of(context).unfocus();

    final ok = await vm.submit();
    if (!mounted) return;

    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    }
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
    required IconData icon,
    required Widget label,
    String? errorText,
    Widget? suffix,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      label: label,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      errorText: errorText,
      errorMaxLines: 2,
      errorStyle: const TextStyle(
        fontFamily: 'NotoSansArabic',
        color: Color(0xFFFFD6D6),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
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
      hintText: '',
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

  Widget _loginButton(LoginViewModel vm, double scale) {
    final enabled = vm.canSubmit && !vm.loading;

    return SizedBox(
      width: double.infinity,
      height: 54 * scale,
      child: ElevatedButton(
        onPressed: enabled ? () => _submit(vm) : null,
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
        child: vm.loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.navy,
                ),
              )
            : Text(
                'تسجيل الدخول',
                style: TextStyle(
                  fontFamily: 'NotoSansArabic',
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }

  Widget _signupLink(double scale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'ليس لديك حساب؟ ',
          style: TextStyle(
            fontFamily: 'NotoSansArabic',
            fontSize: 13 * scale,
            fontWeight: FontWeight.w800,
            color: Colors.white.withOpacity(0.72),
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignUpView()),
            );
          },
          child: Text(
            'أنشئ حساب',
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
      ],
    );
  }

  Widget _form(LoginViewModel vm, double scale) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _userCtrl,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.deny(
                RegExp(
                  r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
                ),
              ),
            ],
            decoration: _pillDec(
              icon: Icons.person_outline_rounded,
              errorText: vm.userError,
              label: _requiredLabel('اسم المستخدم / البريد الإلكتروني'),
            ),
            onChanged: vm.setUser,
          ),

          SizedBox(height: 13 * scale),

          TextField(
            controller: _passCtrl,
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
            onSubmitted: (_) {
              if (vm.canSubmit && !vm.loading) _submit(vm);
            },
            decoration: _pillDec(
              icon: Icons.lock_outline_rounded,
              errorText: vm.passError,
              label: _requiredLabel('كلمة المرور'),
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

          SizedBox(height: 7 * scale),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ForgotPasswordPhoneView(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withOpacity(0.82),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              ),
              child: const Text(
                'نسيت كلمة المرور؟',
                style: TextStyle(
                  fontFamily: 'NotoSansArabic',
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
              ),
            ),
          ),

          if (vm.apiError != null) ...[
            SizedBox(height: 8 * scale),
            _apiErrorBox(vm.apiError!),
          ],

          SizedBox(height: 14 * scale),

          _loginButton(vm, scale),

          SizedBox(height: 18 * scale),

          _signupLink(scale),
        ],
      ),
    );
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
          backgroundColor: AppColors.navy,
          body: Consumer<LoginViewModel>(
            builder: (context, vm, _) {
              final prefill = widget.prefillIdentifier?.trim() ?? '';

              if (!_prefilledOnce &&
                  prefill.isNotEmpty &&
                  vm.usernameOrEmail.trim().isEmpty) {
                _prefilledOnce = true;
                vm.setUser(prefill);
              }

              if (_userCtrl.text != vm.usernameOrEmail) {
                _userCtrl.text = vm.usernameOrEmail;
                _userCtrl.selection = TextSelection.collapsed(
                  offset: _userCtrl.text.length,
                );
              }

              if (_passCtrl.text != vm.password) {
                _passCtrl.text = vm.password;
                _passCtrl.selection = TextSelection.collapsed(
                  offset: _passCtrl.text.length,
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
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'نعم',
    String cancelText = 'لا',
    Color? confirmColor,
    IconData? icon,
    Color? iconBgColor,
  }) async {
    final visual = _resolveVisual(
      title: title,
      message: message,
      icon: icon,
    );

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.white,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: visual.color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          visual.icon,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: 'NotoSansArabic',
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: AppColors.navy,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _HighlightedMessageText(message: message),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.navy,
                              side: BorderSide(
                                color: AppColors.navy.withOpacity(0.22),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              cancelText,
                              style: const TextStyle(
                                fontFamily: 'NotoSansArabic',
                                fontWeight: FontWeight.w900,
                                fontSize: 13.6,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: visual.color,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              confirmText,
                              style: const TextStyle(
                                fontFamily: 'NotoSansArabic',
                                fontWeight: FontWeight.w900,
                                fontSize: 13.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return result == true;
  }

  static _DialogVisual _resolveVisual({
    required String title,
    required String message,
    IconData? icon,
  }) {
    final text = '$title $message'.toLowerCase();

    // JOIN = GREEN
    if (_containsAny(text, [
      'طلب الانضمام',
      'انضمام',
      'join',
      'request to join',
    ])) {
      return _DialogVisual(
        icon: icon ?? Icons.person_add_alt_1_rounded,
        color: const Color(0xFF1AA37A),
      );
    }

    // LEAVE GROUP = RED
    if (_containsAny(text, [
      'مغادرة',
      'مغادرة المجموعة',
      'leave group',
      'leave',
    ])) {
      return _DialogVisual(
        icon: icon ?? Icons.logout_rounded,
        color: const Color(0xFFF05260),
      );
    }

    // REPORT = RED
    if (_containsAny(text, [
      'إبلاغ',
      'ابلاغ',
      'بلاغ',
      'report',
    ])) {
      return _DialogVisual(
        icon: icon ?? Icons.flag_rounded,
        color: const Color(0xFFF05260),
      );
    }

    // DELETE = RED
    if (_containsAny(text, [
      'حذف',
      'delete',
      'remove',
      'مسح',
    ])) {
      return _DialogVisual(
        icon: icon ?? Icons.delete_outline_rounded,
        color: const Color(0xFFF05260),
      );
    }

    // IMPORTANT / URGENT = RED
    if (_containsAny(text, [
      'مهم',
      'important',
      'عاجل',
      'urgent',
      'خطير',
    ])) {
      return _DialogVisual(
        icon: icon ?? Icons.priority_high_rounded,
        color: const Color(0xFFF05260),
      );
    }

    // WARNING = YELLOW
    if (_containsAny(text, [
      'تحذير',
      'warning',
      'تنبيه',
      'alert',
    ])) {
      return _DialogVisual(
        icon: icon ?? Icons.warning_amber_rounded,
        color: const Color(0xFFFFB300),
      );
    }

    // LOGOUT = ORANGE
    if (_containsAny(text, [
      'خروج',
      'logout',
      'تسجيل الخروج',
    ])) {
      return _DialogVisual(
        icon: icon ?? Icons.logout_rounded,
        color: const Color(0xFFFF9800),
      );
    }

    // SUCCESS / APPROVE = GREEN
    if (_containsAny(text, [
      'نجاح',
      'success',
      'قبول',
      'accept',
      'approve',
      'موافقة',
    ])) {
      return _DialogVisual(
        icon: icon ?? Icons.check_rounded,
        color: const Color(0xFF1AA37A),
      );
    }

    return _DialogVisual(
      icon: icon ?? Icons.help_outline_rounded,
      color: AppColors.navy,
    );
  }

  static bool _containsAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}

class _HighlightedMessageText extends StatelessWidget {
  final String message;

  const _HighlightedMessageText({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'NotoSansArabic',
          fontSize: 13.6,
          height: 1.55,
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
        ),
        children: _buildSpans(message),
      ),
    );
  }

  List<TextSpan> _buildSpans(String text) {
    final spans = <TextSpan>[];
    final buffer = StringBuffer();

    bool highlight = false;

    bool isQuote(String char) {
      return char == '"' ||
          char == '“' ||
          char == '”' ||
          char == '«' ||
          char == '»';
    }

    void flush() {
      if (buffer.isEmpty) return;

      spans.add(
        TextSpan(
          text: buffer.toString(),
          style: TextStyle(
            fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
      );

      buffer.clear();
    }

    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);

      if (isQuote(char)) {
        flush();
        highlight = !highlight;
      } else {
        buffer.write(char);
      }
    }

    flush();

    return spans;
  }
}

class _DialogVisual {
  final IconData icon;
  final Color color;

  const _DialogVisual({
    required this.icon,
    required this.color,
  });
}
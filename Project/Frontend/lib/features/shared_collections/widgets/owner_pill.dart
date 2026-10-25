import 'package:flutter/material.dart';


class OwnerPill extends StatelessWidget {
  final String owner;
  final bool useGradient;
  final bool isAddedByMe;

  
  final LinearGradient? gradient;

  const OwnerPill._({
    super.key,
    required this.owner,
    required this.useGradient,
    required this.isAddedByMe,
    this.gradient, 
  });

  factory OwnerPill.glass({
    Key? key,
    required String owner,
    bool isAddedByMe = false,
  }) {
    return OwnerPill._(
      key: key,
      owner: owner,
      useGradient: false,
      isAddedByMe: isAddedByMe,
      gradient: null, 
    );
  }


  factory OwnerPill.gradient({
    Key? key,
    required String owner,
    required LinearGradient gradient, 
    bool isAddedByMe = false,
  }) {
    return OwnerPill._(
      key: key,
      owner: owner,
      useGradient: true,
      isAddedByMe: isAddedByMe,
      gradient: gradient, 
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = owner.trim();
    final displayText = isAddedByMe ? 'أضيفت بواسطتك' : v;
    if (displayText.isEmpty) return const SizedBox.shrink();

    final borderRadius = BorderRadius.circular(999);

    final double iconSize = useGradient ? 16 : 18;
    final double fontSize = useGradient ? 12 : 13;
    final EdgeInsets pad = useGradient
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 8);
    final double maxW = useGradient ? 150 : 180;
    final double gap = useGradient ? 6 : 8;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
      
        gradient: useGradient ? gradient : null,
        color: useGradient ? null : Colors.white.withOpacity(0.16),
        border: Border.all(
          color: useGradient
              ? Colors.white.withOpacity(0.22)
              : Colors.white.withOpacity(0.16),
        ),
      ),
      child: Padding(
        padding: pad,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAddedByMe ? Icons.check_circle_rounded : Icons.person,
              color: Colors.white,
              size: iconSize,
            ),
            SizedBox(width: gap),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Text(
                displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'NotoSansArabic',
                  fontSize: fontSize,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
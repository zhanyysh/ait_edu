import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomAnimatedButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final List<Color> gradientColors;
  final String? label;
  final IconData? icon;
  final String currentTheme;
  final double horizontalPadding;
  final double verticalPadding;
  final double fontSize;
  final double iconSize;
  final TextStyle? textStyle;
  final bool isHeader; // New parameter to indicate header usage

  const CustomAnimatedButton({
    super.key,
    required this.onPressed,
    required this.gradientColors,
    this.label,
    this.icon,
    required this.currentTheme,
    this.horizontalPadding = 16.0,
    this.verticalPadding = 12.0,
    this.fontSize = 16.0,
    this.iconSize = 24.0,
    this.textStyle,
    this.isHeader = false,
  });

  @override
  CustomAnimatedButtonState createState() => CustomAnimatedButtonState();
}

class CustomAnimatedButtonState extends State<CustomAnimatedButton> with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: widget.label ?? 'Button',
      child: GestureDetector(
        onTap: isEnabled ? widget.onPressed : null,
        onTapDown: isEnabled ? _onTapDown : null,
        onTapUp: isEnabled ? _onTapUp : null,
        onTapCancel: isEnabled ? _onTapCancel : null,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isEnabled
                        ? widget.gradientColors
                        : widget.gradientColors.map((c) => c.withOpacity(0.5)).toList(),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: widget.currentTheme == 'light' && isEnabled
                      ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                      : [],
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.horizontalPadding,
                  vertical: widget.verticalPadding,
                ),
                child: widget.icon != null
                    ? Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: Colors.white,
                )
                    : Text(
                  widget.label ?? '',
                  style: widget.textStyle ??
                      (widget.isHeader
                          ? GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      )
                          : TextStyle(
                        color: Colors.white,
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      )),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

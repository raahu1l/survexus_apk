import 'package:flutter/material.dart';

class AnimatedLogo extends StatefulWidget {
  const AnimatedLogo({super.key});

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _zoomController;
  late final Animation<double> _zoomAnimation;

  @override
  void initState() {
    super.initState();

    // Smooth zoom-in and zoom-out animation
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _zoomAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _zoomAnimation,
        child: Image.asset(
          'assets/survexus_icon.jpg', // ✅ your single logo file
          width: 150,
          height: 150,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

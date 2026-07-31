import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

/// In-app animated splash shown on every device right after the (static)
/// native splash. Displays the Zipx Movies artwork with a spinner, then
/// moves on to the main app. Because it uses the same image as the native
/// splash on a black background, the hand-off looks seamless - the only
/// visible change is the spinner appearing.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) context.go('/');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The Zipx artwork, centered on black (contained so it isn't
          // cropped on wide TV screens).
          Image.asset(
            'assets/splash/zipx_splash.png',
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
          // Spinner pinned near the bottom, below the "Zipx Movies" wordmark.
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: Colors.white,
                size: 44,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

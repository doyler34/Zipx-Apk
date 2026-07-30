import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

/// Shown while a provider's embed page is loading.
class PlayerLoadingView extends StatelessWidget {
  const PlayerLoadingView({super.key, required this.providerName});

  final String providerName;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingAnimationWidget.beat(color: Colors.white, size: 48),
          const SizedBox(height: 16),
          Text('Loading $providerName...', style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

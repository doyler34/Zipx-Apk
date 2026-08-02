import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:movie_bloc_app/core/utils/helpers/helper_functions.dart';

import '../../core/utils/strings/url_strings.dart';
import 'zipx_ui.dart';

class Styles {
  final BuildContext context;
  late BoxDecoration cardBoxDecoration;
  String imagePath;
  late List<Shadow> iconShadows;
  late List<BoxShadow>? containerShadows;
  late List<Shadow> textShadows;
  final bool isStarIcon;

  Styles({required this.context, this.imagePath = '', this.isStarIcon = false}) {
    final isDark = HelperFunctions.isDarkMode(context);

    // Clean dark surface tile used across the app - no red fill or red glow.
    cardBoxDecoration = BoxDecoration(
      color: ZipxUi.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white10, width: 1),
      image: imagePath.trim() != ''
          ? DecorationImage(
              image: ExtendedNetworkImageProvider(UrlStrings.imageUrl + imagePath, cache: true, printError: false),
              fit: BoxFit.cover,
            )
          : null,
    );

    iconShadows = isStarIcon
        ? [
            const Shadow(
              color: Colors.grey,
              offset: Offset(0, 0),
              blurRadius: 2,
            ),
          ]
        : [
            const Shadow(
              color: Colors.black,
              offset: Offset(0, 0),
              blurRadius: 5,
            ),
          ];

    containerShadows = [
      const BoxShadow(
        color: Colors.black,
        offset: Offset(0, 0),
        spreadRadius: 2,
        blurRadius: 5,
      ),
    ];

    textShadows = [
      Shadow(
        color: !isDark ? Colors.white : Colors.black,
        offset: const Offset(0, 0),
        blurRadius: 5,
      ),
    ];
  }
}

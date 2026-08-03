import 'package:flutter/material.dart';
import 'package:movie_bloc_app/core/dependency_injection/di.dart';
import 'package:movie_bloc_app/core/playback/services/playback_history_service.dart';
import 'package:movie_bloc_app/core/utils/enums/enums.dart';
import 'package:movie_bloc_app/core/utils/helpers/helper_functions.dart';
import 'package:movie_bloc_app/features/personalization/presentation/widgets/settings/setting_tile.dart';

/// Settings action to wipe the "Continue Watching" list (playback history).
/// The list is stored locally on this device only, so this clears just this
/// install's history.
class ClearContinueWatchingTile extends StatelessWidget {
  const ClearContinueWatchingTile({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingTile(
      title: 'Clear Continue Watching',
      type: SettingsTileType.buttonType,
      buttonTitle: 'Clear',
      onTapButton: () {
        sl<PlaybackHistoryService>().clear();
        HelperFunctions.showSnackBar(context, 'Continue watching cleared');
      },
    );
  }
}

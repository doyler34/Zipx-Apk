import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movie_bloc_app/core/settings/supported_languages.dart';
import 'package:movie_bloc_app/core/utils/enums/enums.dart';
import 'package:movie_bloc_app/core/utils/helpers/helper_functions.dart';
import 'package:movie_bloc_app/features/movies/presentation/blocs/home/home/home_bloc.dart';

import '../../blocs/settings/settings_bloc.dart';
import 'setting_tile.dart';

class ChangeLanguageTile extends StatelessWidget {
  const ChangeLanguageTile({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      bloc: context.read<SettingsBloc>(),
      builder: (context, state) {
        if (state is! SettingsChanged) return const SizedBox.shrink();

        return SettingTile(
          title: 'Change Language',
          type: SettingsTileType.buttonType,
          buttonTitle: languageNameForCode(state.language),
          onTapButton: () => _openPicker(context, state.language),
        );
      },
    );
  }

  void _openPicker(BuildContext context, String currentCode) {
    final settingsBloc = context.read<SettingsBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Choose Language'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final lang in kSupportedLanguages)
                  RadioListTile<String>(
                    title: Text(lang.name),
                    value: lang.code,
                    groupValue: currentCode,
                    onChanged: (value) {
                      Navigator.of(dialogContext).pop();
                      if (value != null && value != currentCode) {
                        settingsBloc.add(ChangeSettings(language: value));
                        _promptRefresh(context, languageNameForCode(value));
                      }
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// After the language changes, offer to reload content right away so the
  /// new language shows immediately instead of only on the next fetch.
  void _promptRefresh(BuildContext context, String languageName) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Language changed'),
          content: Text('Language set to $languageName. Refresh content now to apply it everywhere?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                try {
                  context.read<HomeBloc>().add(LoadHome());
                  HelperFunctions.showSnackBar(context, 'Content refreshed in $languageName.');
                } catch (_) {
                  HelperFunctions.showSnackBar(context, 'Language will apply as content reloads.');
                }
              },
              child: const Text('Refresh'),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movie_bloc_app/core/settings/supported_languages.dart';
import 'package:movie_bloc_app/core/utils/enums/enums.dart';
import 'package:movie_bloc_app/core/utils/helpers/helper_functions.dart';

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
    final bloc = context.read<SettingsBloc>();
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
                      if (value != null && value != currentCode) {
                        bloc.add(ChangeSettings(language: value));
                        HelperFunctions.showSnackBar(context, 'Language updated. Refresh or reopen a page to see it applied.');
                      }
                      Navigator.of(dialogContext).pop();
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
}

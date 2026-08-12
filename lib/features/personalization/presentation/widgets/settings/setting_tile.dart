import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movie_bloc_app/core/dependency_injection/di.dart';
import 'package:movie_bloc_app/core/settings/user_settings.dart';

import '../../../../../common/styles/zipx_ui.dart';
import '../../../../../core/utils/enums/enums.dart';
import '../../blocs/settings/settings_bloc.dart';

class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    required this.title,
    this.onTapSwitch,
    this.type = SettingsTileType.buttonType,
    this.onTapButton,
    this.buttonTitle = 'Edit',
    this.onTapToggleButtons,
  });

  final String title;
  final Function(bool)? onTapSwitch;
  final SettingsTileType type;
  final VoidCallback? onTapButton;
  final String buttonTitle;
  final Function(int)? onTapToggleButtons;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder(
      bloc: context.read<SettingsBloc>(),
      builder: (context, state) {
        if (state is SettingsChanged) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ZipxUi.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title takes the remaining space; the control keeps its
                  // natural size so switches/toggles are always fully visible
                  // (a fixed MediaQuery width used to squeeze them to nothing
                  // inside the constrained desktop settings column).
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: type == SettingsTileType.switchType
                            ? Switch(
                                value: state.showAdultContent,
                                onChanged: onTapSwitch,
                                activeColor: Colors.white,
                                trackColor: WidgetStateProperty.all(
                                  state.showAdultContent ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.tertiary.withOpacity(0.25),
                                ),
                                inactiveThumbColor: Colors.white.withOpacity(0.75),
                                trackOutlineColor: WidgetStateProperty.all(
                                  state.showAdultContent ? Colors.white : Colors.white.withOpacity(0.75),
                                ),
                              )
                            : type == SettingsTileType.buttonType
                                ? ElevatedButton(
                                    onPressed: onTapButton,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: onTapButton == null ? Theme.of(context).colorScheme.tertiary.withOpacity(0.5) : Theme.of(context).colorScheme.tertiary,
                                    ),
                                    child: Text(
                                      buttonTitle,
                                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                                            color: Colors.white,
                                          ),
                                    ),
                                  )
                                : type == SettingsTileType.toggleButtonsType
                                    ? ToggleButtons(
                                        borderRadius: BorderRadius.circular(10),
                                        borderWidth: 2,
                                        selectedBorderColor: Colors.white,
                                        color: Colors.white,
                                        fillColor: Theme.of(context).colorScheme.tertiary,
                                        isSelected: [
                                          sl<UserSettings>().getThemeMode() == 'light',
                                          sl<UserSettings>().getThemeMode() == 'dark',
                                          sl<UserSettings>().getThemeMode() == 'auto',
                                        ],
                                        onPressed: onTapToggleButtons,
                                        children: const [
                                          Padding(padding: EdgeInsets.all(3), child: Text('Light')),
                                          Padding(padding: EdgeInsets.all(3), child: Text('Dark')),
                                          Padding(padding: EdgeInsets.all(3), child: Text('Auto')),
                                        ],
                                      )
                                    : null,
                  ),
                ],
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

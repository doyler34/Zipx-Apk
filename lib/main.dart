import 'dart:async';
import 'dart:io' show Platform;

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:movie_bloc_app/core/dependency_injection/di.dart';
import 'package:movie_bloc_app/core/router/router_config.dart';
import 'package:movie_bloc_app/core/utils/themes/custom_theme.dart';
import 'package:movie_bloc_app/features/personalization/presentation/blocs/bookmarks/bookmarks_bloc.dart';
import 'package:movie_bloc_app/features/personalization/presentation/blocs/settings/settings_bloc.dart';

// import 'package:device_preview/device_preview.dart';

import 'common/blocs/bloc/nav_bar_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'core/platform/tv.dart';
import 'core/playback/services/provider_preferences_service.dart';
import 'core/settings/user_settings.dart';
import 'features/personalization/data/models/bookmarked_movie_hive.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialise the media_kit (mpv) native player used for streaming.
  MediaKit.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(BookmarkedMovieAdapter());
  await Hive.openBox<BookmarkedMovie>('bookmarks');
  await Hive.openBox('settings');
  await Hive.openBox('theme_mode');

  // Streaming provider configuration is stored separately from TMDB
  // settings above, so it can never accidentally mix with it.
  await Hive.openBox('provider_preferences');
  await Hive.openBox('playback_history');
  await Hive.openBox('favourites');
  // Remembers which titles have no streams, so browsing can hide dead-ends.
  await Hive.openBox('stream_availability');
  // Server-side preparation jobs shown under Profile → Downloads.
  await Hive.openBox('downloads');

  await initDependencyInjection();
  await sl<ProviderPreferencesService>().initialize();

  // Desktop (PC): open the window centered on screen at a sensible size,
  // instead of the OS default top-left placement. No-op on mobile/web.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(900, 600),
      center: true,
      title: 'ZipX Movies',
      titleBarStyle: TitleBarStyle.normal,
    );
    unawaited(windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.center();
      await windowManager.show();
      await windowManager.focus();
    }));
  } else if (isAndroidTv = await _isAndroidTv()) {
    // Fire TV / Android TV: run landscape (a TV is never held in portrait).
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else {
    // Phone/tablet app: portrait-locked at launch (the player itself allows
    // landscape while a video is open).
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  // Used only for testing on different devices
  // FlutterNativeSplash.remove();
  // runApp(
  //   DevicePreview(
  //     enabled: true,
  //     builder: (context) => const MyApp(),
  //   ),
  // );

  FlutterNativeSplash.remove();
  runApp(const MyApp());
}

/// Whether we're running on Fire TV / Android TV (leanback). Used to pick a
/// landscape orientation instead of the phone's portrait lock.
Future<bool> _isAndroidTv() async {
  if (kIsWeb || !Platform.isAndroid) return false;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    final f = info.systemFeatures;
    return f.contains('android.software.leanback') ||
        f.contains('android.software.leanback_only') ||
        f.contains('android.hardware.type.television');
  } catch (_) {
    return false;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<NavBarBloc>()),
        BlocProvider(create: (_) => sl<BookmarksBloc>()),
        BlocProvider(create: (_) => sl<SettingsBloc>()..add(const ChangeSettings())),
      ],
      child: AdaptiveTheme(
        light: CustomTheme.lightTheme,
        dark: CustomTheme.darkTheme,
        initial: sl<UserSettings>().getThemeMode() == 'dark'
            ? AdaptiveThemeMode.dark
            : sl<UserSettings>().getThemeMode() == 'light'
                ? AdaptiveThemeMode.light
                : AdaptiveThemeMode.system,
        builder: (theme, darkTheme) => MaterialApp.router(
          routerConfig: CustomGoRouterConfig().config,
          debugShowCheckedModeBanner: false,
          title: 'Zipx Movies',
          theme: theme,
          // locale: DevicePreview.locale(context),
          // builder: DevicePreview.appBuilder,
          darkTheme: darkTheme,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

import 'ads/ads.dart';
import 'battle/battle_service.dart';
import 'premium/premium_service.dart';

import 'core/app_config.dart';
import 'core/app_state.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';
import 'core/sound.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  final state = AppState();
  await state.load();
  state.startTracking();
  // Store subscriptions (Premium). Safe if billing isn't available.
  PremiumService.instance.init(state);
  Ads.isPremium = () => state.isPremium;
  Ads.init();
  // Background music + sound effects (follows the Music / Sound Fx settings).
  Sound.instance.init(music: state.music, sfx: state.soundFx);

  runApp(AppScope(state: state, child: const DrawApp()));

  // Online multiplayer: uses Firebase if it is configured (see README),
  // otherwise Art Battle keeps working offline with computer players.
  _initOnline();
}

Future<void> _initOnline() async {
  try {
    await Firebase.initializeApp();
    BattleService.instance = await FirebaseBattleService.create()
        .timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('Art Battle running offline: $e');
  }
}

class DrawApp extends StatelessWidget {
  const DrawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const SplashScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'common_theme/theme/app_theme.dart';

import 'features/shared_collections/viewmodel/shared_collections_main_vm.dart';
import 'features/shared_collections/viewmodel/explore_vm.dart';
import 'features/notifications/viewmodel/notifications_history_vm.dart';
import 'features/notifications/viewmodel/semantic_notifications_vm.dart';
import 'features/login-signup/viewmodel/login_viewmodel.dart';
import 'features/login-signup/viewmodel/forgot_password_viewmodel.dart';
import 'features/login-signup/views/auth_gate.dart';
import 'features/profile/viewmodel/profile_viewmodel.dart';
import 'features/notifications/views/semantic_notifications_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await Firebase.initializeApp();

  await Hive.initFlutter();

  await Hive.openBox('news_cache');
  await Hive.openBox('collections_cache');
  await Hive.openBox('profile_cache');
  await Hive.openBox('semantic_notifications_cache');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SharedCollectionsViewModel()),
        ChangeNotifierProvider(create: (_) => ExploreViewModel()),
        ChangeNotifierProvider(create: (_) => NotificationHistoryVM()),
        ChangeNotifierProvider(create: (_) => SemanticNotificationsVM()),
        ChangeNotifierProvider(create: (_) => ForgotPasswordPhoneViewModel()),
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
      ],
      child: const MadarApp(),
    ),
  );
}

class MadarApp extends StatelessWidget {
  const MadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const AuthGate(),
      routes: {
        '/semantic': (_) => const SemanticNotificationsPage(),
      },
    );
  }
}
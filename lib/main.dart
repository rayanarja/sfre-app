import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/providers/app_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient().init();
  await NotificationService().init();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // تحميل تفضيلات المستخدم
    Future.microtask(() {
      ref.read(appProvider).loadPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final app = ref.watch(appProvider);

    return MaterialApp.router(
      title: app.l10n.t('app_name'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: app.themeMode,
      routerConfig: router,
      locale: Locale(app.locale),
    );
  }
}

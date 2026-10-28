import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/demo_banner.dart';
import 'data/providers.dart';

class SukkarApp extends ConsumerWidget {
  const SukkarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final demo = ref.watch(appControllerProvider.select((s) => s.demoMode));
    return MaterialApp.router(
      title: 'سكر بلس',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            if (demo) const DemoBanner(),
            Expanded(
              // The banner already consumed the status-bar inset.
              child: demo
                  ? MediaQuery.removePadding(context: context, removeTop: true, child: child ?? const SizedBox.shrink())
                  : child ?? const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

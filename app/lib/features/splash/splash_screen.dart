import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/demo_banner.dart';
import '../../data/providers.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(appControllerProvider.select((s) => s.errorAr));
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SukkarLogo(size: 64),
            const SizedBox(height: SpSpace.md),
            Text('سكر بلس', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: SpSpace.lg),
            if (error == null)
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
            else
              Text(error, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

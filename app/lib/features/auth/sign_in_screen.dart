import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/demo_banner.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/providers.dart';

/// Live mode only (Supabase Auth). Accounts and reviewer roles are created by
/// an administrator; see docs/SETUP_WINDOWS.md.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(appControllerProvider.notifier).signIn(_email.text, _password.text);
    } on UserFacingError catch (e) {
      if (mounted) showSnack(context, e.messageAr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SpSpace.xl),
          children: [
            const SizedBox(height: SpSpace.xxl),
            const Align(alignment: AlignmentDirectional.centerStart, child: SukkarLogo(size: 48, withWordmark: true)),
            const SizedBox(height: SpSpace.xl),
            Text('تسجيل الدخول', style: t.headlineSmall),
            const SizedBox(height: SpSpace.xs),
            Text('سكر بلس نموذج أولي مستقل وغير مرتبط بتطبيق صحتي أو أي جهة صحية.', style: t.bodySmall),
            const SizedBox(height: SpSpace.xl),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
            ),
            const SizedBox(height: SpSpace.md),
            TextField(
              controller: _password,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: SpSpace.xl),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('تسجيل الدخول'),
            ),
            const SizedBox(height: SpSpace.lg),
            const InfoNote(text: 'لتجربة التطبيق دون حساب، شغّله دون إعدادات Supabase ليعمل في وضع العرض ببيانات تجريبية.'),
          ],
        ),
      ),
    );
  }
}

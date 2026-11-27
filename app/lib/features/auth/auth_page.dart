import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../app/language.dart';
import '../../core/widgets/notice_box.dart';
import '../../core/widgets/section.dart';
import 'auth_view_model.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => ref.read(authViewModelProvider.notifier).submit(_email.text, _password.text);

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final st = ref.watch(authViewModelProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(Corners.sheet),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Icon(Icons.auto_stories_rounded, size: 40, color: scheme.onPrimaryContainer),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Anything ~ diaries', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                  Text(t.appTagline,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 32),
                  Labeled(
                    t.email,
                    child: TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(hintText: 'name@example.com'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Labeled(
                    t.password,
                    child: TextField(
                      controller: _password,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: [st.signUp ? AutofillHints.newPassword : AutofillHints.password],
                      decoration: InputDecoration(
                        hintText: t.passwordHint,
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? t.hidePassword : t.showPassword,
                          icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  if (st.error != null) Padding(padding: const EdgeInsets.only(top: 12), child: NoticeBox(st.error!)),
                  if (st.info != null)
                    Padding(padding: const EdgeInsets.only(top: 12), child: NoticeBox(st.info!, isError: false)),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: st.busy ? null : _submit,
                    child: st.busy
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(st.signUp ? t.createAccount : t.signIn),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: st.busy ? null : ref.read(authViewModelProvider.notifier).toggleMode,
                    child: Text(st.signUp ? t.switchToSignIn : t.switchToSignUp),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

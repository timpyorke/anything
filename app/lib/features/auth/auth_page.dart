import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_view_model.dart';


class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => ref.read(authViewModelProvider.notifier).submit(_email.text, _password.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                  Icon(Icons.auto_stories, size: 48, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text("anything - diary's", textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('บันทึกชีวิตด้วย AI', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'อีเมล', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: [st.signUp ? AutofillHints.newPassword : AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'รหัสผ่าน', border: OutlineInputBorder()),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (st.error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(st.error!, style: TextStyle(color: scheme.error))),
                  if (st.info != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(st.info!)),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: st.busy ? null : _submit,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: st.busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(st.signUp ? 'สร้างบัญชี' : 'เข้าสู่ระบบ'),
                  ),
                  TextButton(
                    onPressed: st.busy ? null : ref.read(authViewModelProvider.notifier).toggleMode,
                    child: Text(st.signUp ? 'มีบัญชีแล้ว? เข้าสู่ระบบ' : 'ยังไม่มีบัญชี? สร้างบัญชี'),
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

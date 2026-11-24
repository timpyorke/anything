import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false, _busy = false;
  String? _error, _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim(), password = _password.text;
    if (!email.contains('@') || password.length < 8) {
      setState(() => _error = 'ใส่อีเมล และรหัสผ่านอย่างน้อย 8 ตัวอักษร');
      return;
    }
    setState(() {
      _busy = true;
      _error = _info = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      if (_signUp) {
        final res = await auth.signUp(email: email, password: password);
        if (res.session == null) _info = 'ส่งอีเมลยืนยันไปที่ $email แล้ว — ยืนยันแล้วกลับมาเข้าสู่ระบบ';
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (e) {
      _error = switch (e.code) {
        'invalid_credentials' => 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
        'email_not_confirmed' => 'ยังไม่ได้ยืนยันอีเมล — ตรวจกล่องจดหมาย',
        'user_already_exists' => 'อีเมลนี้มีบัญชีแล้ว — เข้าสู่ระบบแทน',
        'weak_password' => 'รหัสผ่านง่ายเกินไป',
        _ => e.message,
      };
    } catch (e) {
      _error = 'เชื่อมต่อไม่ได้: $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                    autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'รหัสผ่าน', border: OutlineInputBorder()),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: scheme.error))),
                  if (_info != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_info!)),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_signUp ? 'สร้างบัญชี' : 'เข้าสู่ระบบ'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => setState(() {
                      _signUp = !_signUp;
                      _error = _info = null;
                    }),
                    child: Text(_signUp ? 'มีบัญชีแล้ว? เข้าสู่ระบบ' : 'ยังไม่มีบัญชี? สร้างบัญชี'),
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (!email.contains('@') || pass.length < 6) {
      setState(() {
        _message = 'Informe um e-mail válido e senha com 6+ caracteres.';
        _isError = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      if (_signUp) {
        final res = await auth.signUp(email: email, password: pass);
        if (res.session == null && mounted) {
          setState(() {
            _message = 'Conta criada. Confirme o e-mail para entrar.';
            _isError = false;
            _signUp = false;
          });
        }
      } else {
        await auth.signInWithPassword(email: email, password: pass);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() {
        _message = e.message;
        _isError = true;
      });
    } catch (_) {
      if (mounted) setState(() {
        _message = 'Erro de conexão. Tente de novo.';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Digimon Scanner',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                        labelText: 'E-mail', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                        labelText: 'Senha', border: OutlineInputBorder()),
                  ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_message!,
                          style: TextStyle(color: _isError ? scheme.error : scheme.primary)),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_signUp ? 'Criar conta' : 'Entrar'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => setState(() {
                      _signUp = !_signUp;
                      _message = null;
                    }),
                    child: Text(_signUp ? 'Já tenho conta' : 'Criar conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

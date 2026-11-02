import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/password_rules.dart';
import '../core/api_exceptions.dart';
import '../forms/validators.dart';

String _withFrom(String path, String? from) =>
    from == null ? path : '$path?from=${Uri.encodeComponent(from)}';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.from});

  final String? from;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthNotifier>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.login(_email.text, _password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = context.watch<AuthNotifier>().logoutMessage;
    return AuthPage(
      title: 'Вход в систему',
      subtitle: 'Автошкола',
      children: [
        if (notice != null)
          AuthNotice(text: notice, icon: Icons.timer_off_outlined),
        if (_error != null)
          AuthNotice(text: _error!, icon: Icons.error_outline, error: true),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Электронная почта',
                    prefixIcon: Icon(Icons.mail_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: Validators.all([
                    Validators.required('Введите почту'),
                    Validators.email(),
                  ]),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: _hidden,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _hidden ? 'Показать пароль' : 'Скрыть пароль',
                      icon: Icon(_hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    ),
                  ),
                  validator: Validators.required('Введите пароль'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy ? const _ButtonSpinner() : const Icon(Icons.login),
          label: const Text('Войти'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.go(_withFrom('/register', widget.from)),
          child: const Text('Нет учётной записи? Зарегистрироваться'),
        ),
      ],
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.from});
  final String? from;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  final Map<String, String> _serverErrors = {};

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Validator _field(String key, Validator local) =>
      (v) => _serverErrors[key] ?? local(v);

  void _edited(String key) {
    if (_serverErrors.remove(key) != null) setState(() {});
  }

  Future<void> _submit() async {
    if (_busy) return;
    _serverErrors.clear();
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthNotifier>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.register(
        email: _email.text,
        password: _password.text,
        name: _name.text,
      );
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrors.addAll(e.errors);
        if (e.errors.isEmpty) _error = e.message;
      });
      _formKey.currentState!.validate();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      title: 'Регистрация',
      subtitle: 'Новая учётная запись получает роль «Курсант»',
      children: [
        if (_error != null)
          AuthNotice(text: _error!, icon: Icons.error_outline, error: true),
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _input(
                  field: 'name',
                  controller: _name,
                  label: 'Имя и фамилия',
                  icon: Icons.badge_outlined,
                  hint: 'Иван Петров',
                  autofill: AutofillHints.name,
                  validator: _field(
                      'name',
                      Validators.all([
                        Validators.required('Укажите имя'),
                        Validators.length(min: 2, max: 100),
                      ])),
                ),
                _input(
                  field: 'email',
                  controller: _email,
                  label: 'Почта',
                  icon: Icons.mail_outline,
                  hint: 'name@example.ru',
                  autofill: AutofillHints.email,
                  keyboard: TextInputType.emailAddress,
                  validator: _field(
                      'email',
                      Validators.all([
                        Validators.required('Укажите почту'),
                        Validators.email(),
                      ])),
                ),
                _input(
                  field: 'password',
                  controller: _password,
                  label: 'Пароль',
                  icon: Icons.lock_outline,
                  autofill: AutofillHints.newPassword,
                  obscure: true,
                  validator: _field('password', passwordError),
                  onChanged: (_) => setState(() {}),
                ),
                PasswordChecklist(controller: _password),
                const SizedBox(height: 16),
                _input(
                  field: 'confirm',
                  controller: _confirm,
                  label: 'Пароль ещё раз',
                  icon: Icons.lock_reset,
                  autofill: AutofillHints.newPassword,
                  obscure: true,
                  validator: (v) => (v ?? '').isEmpty
                      ? 'Повторите пароль'
                      : v == _password.text
                          ? null
                          : 'Пароли не совпадают',
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy ? const _ButtonSpinner() : const Icon(Icons.how_to_reg),
          label: const Text('Зарегистрироваться'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.go(_withFrom('/login', widget.from)),
          child: const Text('Уже есть учётная запись? Войти'),
        ),
      ],
    );
  }

  Widget _input({
    required String field,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Validator validator,
    String? hint,
    String? autofill,
    TextInputType? keyboard,
    bool obscure = false,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscure && _hidden,
        keyboardType: keyboard,
        autofillHints: autofill == null ? null : [autofill],
        textInputAction:
            onSubmitted == null ? TextInputAction.next : TextInputAction.done,
        onChanged: (v) {
          _edited(field);
          onChanged?.call(v);
        },
        onFieldSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          errorMaxLines: 2,
          suffixIcon: obscure
              ? IconButton(
                  tooltip: _hidden ? 'Показать пароль' : 'Скрыть пароль',
                  icon: Icon(_hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hidden = !_hidden),
                )
              : null,
        ),
        validator: validator,
      ),
    );
  }
}

class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final passed = passwordRules.where((r) => r.test(value.text)).length;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: passed / passwordRules.length,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: passed == passwordRules.length
                      ? Colors.green.shade600
                      : passed == 0
                          ? scheme.error
                          : Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 6),
              for (final rule in passwordRules)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        rule.test(value.text)
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: rule.test(value.text)
                            ? Colors.green.shade600
                            : scheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(rule.label, style: style)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.directions_car,
                        size: 44, color: theme.colorScheme.primary),
                    const SizedBox(height: 8),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 24),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthNotice extends StatelessWidget {
  const AuthNotice({
    super.key,
    required this.text,
    required this.icon,
    this.error = false,
  });

  final String text;
  final IconData icon;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = error ? scheme.errorContainer : scheme.secondaryContainer;
    final fg = error ? scheme.onErrorContainer : scheme.onSecondaryContainer;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: fg))),
        ],
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
}

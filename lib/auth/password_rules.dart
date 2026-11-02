library;

class PasswordRule {
  const PasswordRule(this.label, this.test);
  final String label;
  final bool Function(String password) test;
}

final _digit = RegExp(r'\d');

final _special = RegExp(r'[^0-9A-Za-zА-Яа-яЁё\s]');

final passwordRules = <PasswordRule>[
  PasswordRule('не короче 8 символов', (p) => p.length >= 8),
  PasswordRule('есть цифра', (p) => _digit.hasMatch(p)),
  PasswordRule('есть специальный символ: ! ? @ # % _ - и т. п.',
      (p) => _special.hasMatch(p)),
];

String? passwordError(String? value) {
  final p = value ?? '';
  if (p.isEmpty) return 'Придумайте пароль';
  for (final rule in passwordRules) {
    if (!rule.test(p)) return 'Пароль: ${rule.label}';
  }
  return null;
}

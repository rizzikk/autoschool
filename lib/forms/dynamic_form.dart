import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../auth/app_user.dart';
import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../core/api_exceptions.dart';
import '../domain/entity_def.dart';
import '../domain/field_codec.dart';
import '../models/pb_record.dart';
import '../repositories/record_repository.dart';
import '../state/form_guard.dart';
import '../state/relation_options.dart';
import '../util/format.dart';
import '../widgets/dialogs.dart';
import '../widgets/state_views.dart';

Future<bool> confirmLeave(BuildContext context) => confirmAction(
      context,
      title: 'Уйти без сохранения?',
      message:
          'В форме есть несохранённые изменения. Если уйти, они будут потеряны.',
      confirmLabel: 'Уйти без сохранения',
    );

class DynamicForm extends StatefulWidget {
  const DynamicForm({
    super.key,
    required this.def,
    required this.onSaved,
    required this.onCancel,
    this.record,
    this.fields,
    this.fixedBody = const {},
    this.initialValues = const {},
    this.submitLabel,
  });

  final EntityDef def;

  final PbRecord? record;

  final List<FieldDef>? fields;

  final Map<String, dynamic> fixedBody;

  final Map<String, Object?> initialValues;
  final String? submitLabel;
  final void Function(PbRecord saved) onSaved;
  final VoidCallback onCancel;

  @override
  State<DynamicForm> createState() => _DynamicFormState();
}

class _DynamicFormState extends State<DynamicForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, Object?> _values = {};
  final Map<String, List<PbRecord>> _options = {};
  final Map<String, String> _serverErrors = {};
  late final List<FieldDef> _fields;
  late final UnsavedChangesGuard _guard;
  late final RecordRepository _repository;
  late final RelationOptions _lookup;
  late final AppUser? _user;
  Object? _loadError;
  bool _loadingOptions = true;
  bool _saving = false;
  bool _dirty = false;
  bool _submitted = false;

  bool get _isNew => widget.record == null;

  @override
  void initState() {
    super.initState();
    _guard = context.read<UnsavedChangesGuard>()..dirty = false;
    _repository = context.read<RecordRepository>();
    _lookup = context.read<RelationOptions>();
    final auth = context.read<AuthNotifier>();
    _user = auth.user;
    _fields =
        widget.fields ?? widget.def.formFields(isNew: _isNew, role: auth.role);
    for (final f in _fields) {
      _values[f.name] = _initialValue(f);
      if (_isTextual(f)) {
        _controllers[f.name] =
            TextEditingController(text: '${_values[f.name] ?? ''}')
              ..addListener(_markDirty);
      }
    }
    _loadOptions();
  }

  bool _isTextual(FieldDef f) => switch (f.type) {
        FieldType.text ||
        FieldType.multiline ||
        FieldType.email ||
        FieldType.phone ||
        FieldType.integer ||
        FieldType.money ||
        FieldType.password =>
          true,
        _ => false,
      };

  Object? _initialValue(FieldDef f) {
    final record = widget.record;
    if (record != null) return decodeField(f, record);
    if (widget.initialValues.containsKey(f.name)) {
      return widget.initialValues[f.name];
    }
    if (f.selfInstructor && _user?.role == Role.instructor) {
      return _user?.profileId;
    }
    if (f.multi) return <String>[];
    return f.initial;
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _loadError = null;
    });
    try {
      for (final f in _fields.where((f) => f.type == FieldType.relation)) {
        _options[f.name] = await _lookup.load(f.relation!);
      }
      if (!mounted) return;
      setState(() => _loadingOptions = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loadingOptions = false;
      });
    }
  }

  void _markDirty() {
    _guard.dirty = true;
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  void _setValue(FieldDef f, Object? value) {
    setState(() {
      _values[f.name] = value;
      _serverErrors.remove(f.name);
    });
    _markDirty();
  }

  @override
  void dispose() {
    _guard.dirty = false;
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Object? _current(FieldDef f) => _controllers[f.name]?.text ?? _values[f.name];

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _serverErrors.clear();
    });
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final body = <String, dynamic>{...widget.fixedBody};
    for (final f in _fields) {
      final value = encodeField(f, _current(f));
      if (value == null) continue;
      body[f.name] = value;
    }
    setState(() => _saving = true);
    _guard.dirty = false;
    try {
      await widget.def.beforeSave?.call(_repository, body, widget.record?.id);
      final saved = _isNew
          ? await _repository.create(widget.def.collection, body)
          : await _repository.update(
              widget.def.collection, widget.record!.id, body);
      _lookup.invalidate();
      if (!mounted) return;
      widget.onSaved(saved);
    } on ValidationException catch (e) {
      _showFieldErrors(e.errors, e.message, messenger);
    } on ConflictException catch (e) {
      _showFieldErrors(e.errors, e.message, messenger);
    } catch (e) {
      _guard.dirty = _dirty;
      if (mounted) {
        await showApiError(context, e,
            prefix: 'Не удалось сохранить', messenger: messenger);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showFieldErrors(Map<String, String> errors, String message,
      ScaffoldMessengerState messenger) {
    if (!mounted) return;
    _guard.dirty = _dirty;
    final names = {for (final f in _fields) f.name};
    setState(() {
      for (final e in errors.entries) {
        if (names.contains(e.key)) _serverErrors[e.key] = e.value;
      }
    });
    _formKey.currentState!.validate();
    final other = [
      for (final e in errors.entries)
        if (!names.contains(e.key)) e.value,
    ];
    if (errors.isEmpty || other.isNotEmpty) {
      messenger.showSnackBar(
          SnackBar(content: Text(other.isEmpty ? message : other.join('\n'))));
    }
  }

  Future<void> _onPopBlocked() async {
    final leave = await confirmLeave(context);
    if (!leave || !mounted) return;
    _guard.dirty = false;
    setState(() => _dirty = false);
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return ErrorView(
          message: 'Не удалось загрузить варианты выбора: $_loadError',
          onRetry: _loadOptions);
    }
    if (_loadingOptions) return const LoadingView();
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onPopBlocked();
      },
      child: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, c) => Wrap(
                      spacing: 16,
                      runSpacing: 20,
                      children: [
                        for (final f in _fields)
                          SizedBox(
                            width: _widthFor(f, c.maxWidth),
                            child: _buildField(f),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(widget.submitLabel ??
                            (_isNew ? 'Создать' : 'Сохранить изменения')),
                      ),
                      OutlinedButton(
                        onPressed: _saving ? null : widget.onCancel,
                        child: const Text('Отмена'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _widthFor(FieldDef f, double max) {
    final wide = switch (f.type) {
      FieldType.multiline => true,
      FieldType.relation => f.multi,
      FieldType.text => (f.max ?? 100) > 80,
      _ => false,
    };
    if (wide || max < 560) return max;
    return (max - 16) / 2;
  }

  InputDecoration _decoration(FieldDef f, {Widget? suffix}) => InputDecoration(
        labelText: f.required ? '${f.label} *' : f.label,
        hintText: f.hint,
        helperMaxLines: 2,
        errorMaxLines: 3,
        border: const OutlineInputBorder(),
        suffixIcon: suffix,
      );

  String? _check(FieldDef f, Object? value) {
    final server = _serverErrors[f.name];
    if (server != null) return server;
    Object? other;
    if (f.sameAs != null) {
      final src = _fields.where((x) => x.name == f.sameAs).firstOrNull;
      other = src == null ? null : _current(src);
    }
    return validateField(f, value, other: other);
  }

  Widget _buildField(FieldDef f) {
    switch (f.type) {
      case FieldType.boolean:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          value: _values[f.name] == true,
          onChanged: (v) => _setValue(f, v),
        );
      case FieldType.select:
        final current = _values[f.name];
        return DropdownButtonFormField<String>(
          initialValue:
              f.options.containsKey(current) ? current as String? : null,
          isExpanded: true,
          decoration: _decoration(f),
          items: [
            for (final e in f.options.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => _setValue(f, v),
          validator: (v) => _check(f, v),
        );
      case FieldType.relation:
        return f.multi ? _buildMulti(f) : _buildSingleRelation(f);
      case FieldType.date:
      case FieldType.dateTime:
        return _buildDate(f);
      default:
        return _buildText(f);
    }
  }

  Widget _buildText(FieldDef f) {
    final numeric = f.type == FieldType.integer || f.type == FieldType.money;
    return TextFormField(
      controller: _controllers[f.name],
      keyboardType: numeric
          ? TextInputType.number
          : f.type == FieldType.email
              ? TextInputType.emailAddress
              : f.type == FieldType.phone
                  ? TextInputType.phone
                  : TextInputType.text,
      inputFormatters: [if (numeric) FilteringTextInputFormatter.digitsOnly],
      obscureText: f.type == FieldType.password,
      maxLines: f.type == FieldType.multiline ? 3 : 1,
      decoration: _decoration(f),
      validator: (v) => _check(f, v),
      onChanged: (_) {
        if (_serverErrors.remove(f.name) != null) setState(() {});
      },
    );
  }

  Widget _buildSingleRelation(FieldDef f) {
    final options = _options[f.name] ?? const <PbRecord>[];
    final current = _values[f.name] as String?;
    final extra = current != null &&
            !options.any((o) => o.id == current) &&
            widget.record?.one(f.name) != null
        ? widget.record!.one(f.name)
        : null;
    final locked = f.selfInstructor && _user?.role == Role.instructor;
    return DropdownButtonFormField<String>(
      initialValue:
          options.any((o) => o.id == current) || extra != null ? current : null,
      isExpanded: true,
      decoration: _decoration(f),
      items: [
        for (final o in [...options, if (extra != null) extra])
          DropdownMenuItem(
            value: o.id,
            child: Text(_lookup.labelOf(f.relation!, o),
                overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: locked ? null : (v) => _setValue(f, v),
      validator: (v) => _check(f, v),
    );
  }

  Widget _buildMulti(FieldDef f) {
    final options = _options[f.name] ?? const <PbRecord>[];
    return FormField<List<String>>(
      key: ValueKey('multi-${f.name}-${_serverErrors[f.name]}'),
      initialValue: List<String>.from(_values[f.name] as List? ?? const []),
      validator: (v) => _check(f, v ?? const []),
      builder: (state) {
        final selected = Set<String>.from(_values[f.name] as List? ?? const []);
        return InputDecorator(
          decoration: _decoration(f).copyWith(errorText: state.errorText),
          child: options.isEmpty
              ? const Text('Нет доступных записей')
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final o in options)
                          FilterChip(
                            label: Text(_lookup.labelOf(f.relation!, o)),
                            selected: selected.contains(o.id),
                            onSelected: (on) {
                              final next = Set<String>.of(selected);
                              on ? next.add(o.id) : next.remove(o.id);
                              state.didChange(next.toList());
                              _setValue(f, next.toList());
                            },
                          ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildDate(FieldDef f) {
    final isTime = f.type == FieldType.dateTime;
    final value = _values[f.name] as DateTime?;
    return FormField<DateTime>(
      key: ValueKey(
          'date-${f.name}-${value?.millisecondsSinceEpoch}-${_serverErrors[f.name]}'),
      initialValue: value,
      validator: (v) => _check(f, v),
      builder: (state) => InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () async {
          final picked = await _pickDate(f, value);
          if (picked != null) {
            state.didChange(picked);
            _setValue(f, picked);
          }
        },
        child: InputDecorator(
          decoration: _decoration(
            f,
            suffix: Icon(isTime ? Icons.event : Icons.calendar_today),
          ).copyWith(errorText: state.errorText),
          child: Text(
            value == null
                ? 'Не выбрано'
                : (isTime ? fmtDateTime(value) : fmtDate(value)),
            style: value == null
                ? TextStyle(color: Theme.of(context).hintColor)
                : null,
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _pickDate(FieldDef f, DateTime? current) async {
    final now = DateTime.now();
    final first = DateTime(1930);
    final last =
        f.noFuture ? DateTime(now.year, now.month, now.day) : DateTime(2100);
    var initial = current ?? (f.noFuture ? last : now);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: f.label,
    );
    if (day == null || !mounted) return null;
    if (f.type == FieldType.date) return DateTime(day.year, day.month, day.day);
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          current ?? DateTime(now.year, now.month, now.day, 10)),
      helpText: f.label,
    );
    if (time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }
}

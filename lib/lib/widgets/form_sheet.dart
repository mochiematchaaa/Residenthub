import 'package:flutter/material.dart';

import '../core/core.dart';
import 'common.dart';

class FieldSpec {
  final String key, label;
  final String? hint;
  final int lines;
  final TextInputType? type;
  final bool obscure;
  final String? onlyWhenKey, onlyWhenValue;
  final String initial;
  const FieldSpec(this.key, this.label,
      {this.hint, this.lines = 1, this.type, this.obscure = false, this.onlyWhenKey, this.onlyWhenValue, this.initial = ''});
}

class ChoiceSpec {
  final String key, label;
  final List<String> options;
  final String initial;
  const ChoiceSpec(this.key, this.label, this.options, this.initial);
}

class ToggleSpec {
  final String key, label;
  final bool initial;
  const ToggleSpec(this.key, this.label, this.initial);
}

/// Generic bottom-sheet form. [onSubmit] returns an error string to keep the
/// sheet open, or null to close it.
Future<void> showFormSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<FieldSpec> fields = const [],
  List<ChoiceSpec> choices = const [],
  List<ToggleSpec> toggles = const [],
  required String submit,
  required String? Function(Map<String, dynamic> v) onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FormSheet(
      title: title, subtitle: subtitle, fields: fields, choices: choices,
      toggles: toggles, submit: submit, onSubmit: onSubmit,
    ),
  );
}

class _FormSheet extends StatefulWidget {
  final String title, submit;
  final String? subtitle;
  final List<FieldSpec> fields;
  final List<ChoiceSpec> choices;
  final List<ToggleSpec> toggles;
  final String? Function(Map<String, dynamic>) onSubmit;
  const _FormSheet({
    required this.title, this.subtitle, required this.fields, required this.choices,
    required this.toggles, required this.submit, required this.onSubmit,
  });

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  final Map<String, TextEditingController> ctrls = {};
  final Map<String, dynamic> vals = {};
  String? error;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      ctrls[f.key] = TextEditingController(text: f.initial);
    }
    for (final c in widget.choices) {
      vals[c.key] = c.initial;
    }
    for (final t in widget.toggles) {
      vals[t.key] = t.initial;
    }
  }

  @override
  void dispose() {
    for (final c in ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final out = <String, dynamic>{...vals};
    ctrls.forEach((k, c) => out[k] = c.text);
    final err = widget.onSubmit(out);
    if (err == null) {
      Navigator.of(context).pop();
    } else {
      setState(() => error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42, height: 4,
                decoration: BoxDecoration(color: muted(context).withAlpha(90), borderRadius: BorderRadius.circular(9)),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.title, style: hd(22)),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(widget.subtitle!, style: TextStyle(color: muted(context), height: 1.4)),
            ],
            const SizedBox(height: 16),
            for (final f in widget.fields)
              if (f.onlyWhenKey == null || vals[f.onlyWhenKey] == f.onlyWhenValue)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: ctrls[f.key],
                    minLines: f.lines,
                    maxLines: f.lines,
                    obscureText: f.obscure,
                    keyboardType: f.type,
                    decoration: InputDecoration(labelText: f.label, hintText: f.hint),
                  ),
                ),
            for (final c in widget.choices) ...[
              Text(c.label, style: TextStyle(fontWeight: FontWeight.w700, color: muted(context), fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final o in c.options)
                    ChoiceChip(
                      label: Text(o),
                      selected: vals[c.key] == o,
                      showCheckmark: false,
                      selectedColor: lav,
                      labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: vals[c.key] == o ? ink : Theme.of(context).colorScheme.onSurface),
                      onSelected: (_) => setState(() => vals[c.key] = o),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            for (final t in widget.toggles)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                value: vals[t.key] == true,
                activeThumbColor: lavDeep,
                onChanged: (v) => setState(() => vals[t.key] = v),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(error!, style: const TextStyle(color: danger, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _submit, child: Text(widget.submit)),
            ),
          ],
        ),
      ),
    );
  }
}

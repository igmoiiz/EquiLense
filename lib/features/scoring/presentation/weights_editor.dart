import 'package:flutter/material.dart';

import '../domain/scoring_engine.dart';

/// Editable criterion weights. Reports a valid [ScoringWeights] via [onChanged]
/// or null while the total is not 100%.
class WeightsEditor extends StatefulWidget {
  const WeightsEditor({super.key, required this.initial, required this.onChanged});

  final ScoringWeights initial;
  final ValueChanged<ScoringWeights?> onChanged;

  @override
  State<WeightsEditor> createState() => _WeightsEditorState();
}

class _WeightsEditorState extends State<WeightsEditor> {
  late Map<Criterion, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = _build(widget.initial);
  }

  @override
  void didUpdateWidget(WeightsEditor old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial) {
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers = _build(widget.initial);
    }
  }

  Map<Criterion, TextEditingController> _build(ScoringWeights w) => {
        for (final c in Criterion.values) c: TextEditingController(text: w.of(c).toStringAsFixed(0)),
      };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _total => _controllers.values.fold(0, (a, c) => a + (double.tryParse(c.text) ?? 0));

  void _emit() {
    setState(() {});
    try {
      widget.onChanged(ScoringWeights({
        for (final e in _controllers.entries) e.key: double.tryParse(e.value.text) ?? -1,
      }));
    } on ArgumentError {
      widget.onChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ok = (_total - 100).abs() <= 0.01;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final c in Criterion.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: Text(c.label)),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _controllers[c],
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(suffixText: '%'),
                onChanged: (_) => _emit(),
              ),
            ),
          ]),
        ),
      Text(
        'Total ${_total.toStringAsFixed(1)}%${ok ? '' : ' – must equal 100%'}',
        textAlign: TextAlign.right,
        style: t.textTheme.labelLarge?.copyWith(color: ok ? t.colorScheme.onSurfaceVariant : t.colorScheme.error),
      ),
    ]);
  }
}

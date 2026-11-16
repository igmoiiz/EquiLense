import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';

final _compact = NumberFormat.compact();

class Legend extends StatelessWidget {
  const Legend({super.key, required this.items});
  final List<(String, Color, bool dashed)> items;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 16, runSpacing: 4, children: [
        for (final (label, color, dashed) in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 14,
              height: dashed ? 2 : 10,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  style: Theme.of(context).textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
      ]);
}

FlTitlesData _titles(BuildContext context, {required String Function(double) bottom, required String Function(double) left}) {
  final style = Theme.of(context).textTheme.labelSmall;
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        interval: 1,
        getTitlesWidget: (v, meta) => SideTitleWidget(meta: meta, child: Text(bottom(v), style: style)),
      ),
    ),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 48,
        getTitlesWidget: (v, meta) => v == meta.max || v == meta.min && v != 0
            ? const SizedBox.shrink()
            : SideTitleWidget(meta: meta, child: Text(left(v), style: style)),
      ),
    ),
  );
}

FlGridData _grid(BuildContext context) => FlGridData(
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
    );

/// Grouped bars: one group per year, one bar per company. Null values are
/// omitted (never drawn as zero).
class GroupedBarChart extends StatelessWidget {
  const GroupedBarChart({
    super.key,
    required this.years,
    required this.a,
    required this.b,
    this.percent = false,
    this.height = 220,
  });

  final List<int> years;
  final List<double?> a;
  final List<double?> b;
  final bool percent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values = [...a, ...b].whereType<double>();
    if (values.isEmpty) return SizedBox(height: height, child: const Center(child: Text('No data')));
    final maxY = values.reduce(math.max);
    final minY = values.reduce(math.min);
    String fmt(double v) => percent ? '${v.toStringAsFixed(0)}%' : _compact.format(v);
    return SizedBox(
      height: height,
      child: BarChart(BarChartData(
        maxY: maxY <= 0 ? 0 : maxY * 1.15,
        minY: minY >= 0 ? 0 : minY * 1.15,
        gridData: _grid(context),
        borderData: FlBorderData(show: false),
        titlesData: _titles(context, bottom: (v) => 'FY${years[v.toInt()]}', left: fmt),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
              '${rodIndex == 0 ? 'A' : 'B'}: ${fmt(rod.toY)}',
              TextStyle(color: scheme.onInverseSurface, fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < years.length; i++)
            BarChartGroupData(x: i, barsSpace: 4, barRods: [
              if (a[i] != null)
                BarChartRodData(toY: a[i]!, color: scheme.companyA, width: 14, borderRadius: BorderRadius.circular(3)),
              if (b[i] != null)
                BarChartRodData(toY: b[i]!, color: scheme.companyB, width: 14, borderRadius: BorderRadius.circular(3)),
            ]),
        ],
      )),
    );
  }
}

/// Historical (solid) and projected (dashed) series per company.
class ForecastLineChart extends StatelessWidget {
  const ForecastLineChart({
    super.key,
    required this.years,
    required this.historyA,
    required this.historyB,
    required this.forecastA,
    required this.forecastB,
    this.height = 240,
  });

  final List<int> years; // historical + forecast year
  final List<double?> historyA;
  final List<double?> historyB;
  final double? forecastA;
  final double? forecastB;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    List<FlSpot> spots(List<double?> h) => [
          for (var i = 0; i < h.length; i++)
            if (h[i] != null) FlSpot(i.toDouble(), h[i]!),
        ];
    LineChartBarData line(List<FlSpot> s, Color c, {bool dashed = false}) => LineChartBarData(
          spots: s,
          color: c,
          barWidth: 2.5,
          dashArray: dashed ? [6, 4] : null,
          dotData: FlDotData(show: true, getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 3, color: c)),
        );
    final ha = spots(historyA), hb = spots(historyB);
    final last = historyA.length - 1;
    final bars = <LineChartBarData>[
      line(ha, scheme.companyA),
      line(hb, scheme.companyB),
      if (forecastA != null && historyA.last != null)
        line([FlSpot(last.toDouble(), historyA.last!), FlSpot(last + 1.0, forecastA!)], scheme.companyA, dashed: true),
      if (forecastB != null && historyB.last != null)
        line([FlSpot(last.toDouble(), historyB.last!), FlSpot(last + 1.0, forecastB!)], scheme.companyB, dashed: true),
    ];
    if (bars.every((b) => b.spots.isEmpty)) return SizedBox(height: height, child: const Center(child: Text('No data')));
    return SizedBox(
      height: height,
      child: LineChart(LineChartData(
        minX: 0,
        maxX: years.length - 1.0,
        gridData: _grid(context),
        borderData: FlBorderData(show: false),
        titlesData: _titles(context,
            bottom: (v) => v % 1 == 0 && v >= 0 && v < years.length ? 'FY${years[v.toInt()]}${v == years.length - 1 ? 'F' : ''}' : '',
            left: (v) => _compact.format(v)),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(_compact.format(s.y), TextStyle(color: scheme.onInverseSurface, fontSize: 12)),
            ],
          ),
        ),
        lineBarsData: bars,
      )),
    );
  }
}

/// Horizontal bar per criterion showing points awarded out of the maximum.
class ScoreBars extends StatelessWidget {
  const ScoreBars({super.key, required this.rows});

  /// (label, pointsA, pointsB, max)
  final List<(String, double?, double?, double)> rows;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget bar(double? v, double max, Color c) => Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: v == null || max == 0 ? 0 : v / max,
                minHeight: 10,
                color: c,
                backgroundColor: t.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(v == null ? 'n/a' : '${v.toStringAsFixed(1)} / ${max.toStringAsFixed(0)}',
                textAlign: TextAlign.right, style: t.textTheme.labelSmall),
          ),
        ]);
    return Column(children: [
      for (final (label, a, b, max) in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            bar(a, max, t.colorScheme.companyA),
            const SizedBox(height: 3),
            bar(b, max, t.colorScheme.companyB),
          ]),
        ),
    ]);
  }
}

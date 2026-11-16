import '../../../shared/models/metric_code.dart';

/// Keyword taxonomy mapping financial-statement labels to standardized metrics.
///
/// Matching is phrase based, not substring based: a label maps only when its
/// normalized text equals a synonym (high confidence) or starts with one and
/// has at most [maxExtraWords] trailing words (lower confidence). Exclusion
/// phrases veto a match so that e.g. "deferred tax liabilities" never maps to
/// Tax Expense and "other income" never maps to Revenue.
class MetricSynonyms {
  const MetricSynonyms(this.metric, this.phrases, {this.exclude = const []});

  final MetricCode metric;
  final List<String> phrases;
  final List<String> exclude;
}

const maxExtraWords = 3;

const taxonomy = <MetricSynonyms>[
  MetricSynonyms(MetricCode.totalRevenue, [
    'revenue', 'revenues', 'total revenue', 'net revenue', 'sales', 'net sales', 'turnover', 'net turnover',
    'revenue from contracts with customers', 'revenue from contract with customers', 'sales net',
    'gross sales less sales tax', 'net sales revenue', 'revenue net',
  ], exclude: ['other', 'deferred', 'unearned', 'cost of', 'tax on', 'per share']),
  MetricSynonyms(MetricCode.costOfSales, [
    'cost of sales', 'cost of revenue', 'cost of goods sold', 'cost of revenues', 'cost of sales and services',
    'direct costs', 'cost of services',
  ]),
  MetricSynonyms(MetricCode.grossProfit, ['gross profit', 'gross profit loss', 'gross loss', 'gross margin'],
      exclude: ['ratio', 'percentage']),
  MetricSynonyms(MetricCode.adminExpenses, [
    'administrative expenses', 'administrative and general expenses', 'general and administrative expenses',
    'administration expenses', 'admin expenses', 'administrative expense',
  ]),
  MetricSynonyms(MetricCode.sellingExpenses, [
    'selling and distribution expenses', 'distribution and selling expenses', 'selling expenses',
    'distribution costs', 'distribution expenses', 'selling and marketing expenses', 'marketing and distribution expenses',
    'selling distribution and marketing expenses',
  ]),
  MetricSynonyms(MetricCode.operatingExpenses, ['operating expenses', 'total operating expenses', 'other operating expenses'],
      exclude: ['income']),
  MetricSynonyms(MetricCode.operatingProfit, [
    'operating profit', 'profit from operations', 'operating income', 'profit from operating activities',
    'operating profit loss', 'results from operating activities', 'profit loss from operations',
  ], exclude: ['before tax', 'margin']),
  MetricSynonyms(MetricCode.financeCost, ['finance cost', 'finance costs', 'financial charges', 'finance charges',
      'interest expense', 'markup on borrowings', 'mark up on borrowings', 'financial cost'],
      exclude: ['income', 'accrued', 'payable']),
  MetricSynonyms(MetricCode.profitBeforeTax, [
    'profit before tax', 'profit before taxation', 'profit loss before taxation', 'profit loss before tax',
    'loss before taxation', 'income before tax', 'earnings before tax',
  ]),
  MetricSynonyms(MetricCode.taxExpense, ['taxation', 'tax expense', 'income tax expense', 'income tax',
      'provision for taxation', 'tax charge'],
      exclude: ['deferred tax asset', 'deferred tax liabilit', 'before', 'after', 'payable', 'refundable', 'recoverable',
        'sales tax', 'net of tax']),
  MetricSynonyms(MetricCode.netProfit, [
    'profit after tax', 'profit after taxation', 'net profit', 'net profit for the year', 'profit for the year',
    'net income', 'net earnings', 'profit loss for the year', 'profit loss after taxation', 'loss for the year',
    'net profit after tax', 'profit for the period',
  ], exclude: ['non controlling', 'per share', 'attributable to non', 'other comprehensive', 'before']),
  MetricSynonyms(MetricCode.currentAssets, ['total current assets', 'current assets']),
  MetricSynonyms(MetricCode.cashAndEquivalents, [
    'cash and cash equivalents', 'cash and bank balances', 'cash and bank', 'cash and cash equivalents at end of the year',
    'cash and cash equivalents at the end of the year',
  ], exclude: ['beginning', 'increase', 'decrease']),
  MetricSynonyms(MetricCode.inventory, ['inventories', 'inventory', 'stock in trade', 'stock-in-trade',
      'stores spares and loose tools', 'stocks'], exclude: ['increase', 'decrease']),
  MetricSynonyms(MetricCode.tradeReceivables, ['trade debts', 'trade receivables', 'receivables', 'accounts receivable',
      'trade and other receivables', 'debtors'], exclude: ['increase', 'decrease', 'long term']),
  MetricSynonyms(MetricCode.totalAssets, ['total assets', 'total asset']),
  MetricSynonyms(MetricCode.currentLiabilities, ['total current liabilities', 'current liabilities']),
  MetricSynonyms(MetricCode.totalLiabilities, ['total liabilities', 'total liability']),
  MetricSynonyms(MetricCode.totalDebt, ['total debt', 'total borrowings', 'borrowings', 'long term financing',
      'long term financing and short term borrowings', 'total loans']),
  MetricSynonyms(MetricCode.shareholdersEquity, [
    'total equity', 'shareholders equity', 'total shareholders equity', 'equity', 'net assets',
    'equity attributable to owners of the company', 'equity attributable to equity holders',
    'total equity attributable to shareholders',
  ], exclude: ['and liabilities', 'per share', 'non controlling', 'investment']),
  MetricSynonyms(MetricCode.operatingCashFlow, [
    'net cash generated from operating activities', 'net cash from operating activities',
    'cash generated from operating activities', 'net cash flows from operating activities',
    'net cash used in operating activities', 'net cash generated from used in operating activities',
    'net cash inflow from operating activities', 'net cash flow from operating activities',
  ]),
  MetricSynonyms(MetricCode.investingCashFlow, [
    'net cash used in investing activities', 'net cash from investing activities',
    'net cash generated from investing activities', 'net cash flows from investing activities',
    'net cash used in from investing activities', 'net cash generated from used in investing activities',
  ]),
  MetricSynonyms(MetricCode.financingCashFlow, [
    'net cash used in financing activities', 'net cash from financing activities',
    'net cash generated from financing activities', 'net cash flows from financing activities',
    'net cash generated from used in financing activities',
  ]),
  MetricSynonyms(MetricCode.capitalExpenditure, [
    'capital expenditure', 'capital expenditure incurred', 'purchase of property plant and equipment',
    'additions to property plant and equipment', 'fixed capital expenditure',
  ]),
];

/// Lowercase, strip punctuation/apostrophes/brackets, collapse whitespace.
String normalizeLabel(String label) => label
    .toLowerCase()
    .replaceAll(RegExp(r"[’'`]"), '')
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\b(note|notes)\b'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class LabelMatch {
  const LabelMatch(this.metric, this.confidence);
  final MetricCode metric;
  final double confidence;
}

/// Maps a raw label to a metric using user mappings first, then the taxonomy.
LabelMatch? matchLabel(String rawLabel, {Map<String, MetricCode> userMappings = const {}}) {
  final label = normalizeLabel(rawLabel);
  if (label.isEmpty) return null;
  final user = userMappings[label];
  if (user != null) return LabelMatch(user, 1.0);

  LabelMatch? best;
  var bestLen = 0;
  for (final s in taxonomy) {
    if (s.exclude.any((e) => label.contains(e))) continue;
    for (final phrase in s.phrases) {
      final p = normalizeLabel(phrase);
      double? conf;
      if (label == p) {
        conf = 0.95;
      } else if (label.startsWith('$p ')) {
        final extra = label.substring(p.length).trim().split(' ').length;
        if (extra <= maxExtraWords) conf = 0.7;
      }
      if (conf == null) continue;
      // Prefer higher confidence, then the longest (most specific) phrase.
      if (best == null || conf > best.confidence || (conf == best.confidence && p.length > bestLen)) {
        best = LabelMatch(s.metric, conf);
        bestLen = p.length;
      }
    }
  }
  return best;
}

/// Standardized financial taxonomy. Codes match `public.metric_definitions`.
enum FinancialStatement { incomeStatement, balanceSheet, cashFlow }

enum MetricCode {
  totalRevenue('TOTAL_REVENUE', 'Revenue', FinancialStatement.incomeStatement),
  costOfSales('COST_OF_SALES', 'Cost of Sales', FinancialStatement.incomeStatement, isExpense: true),
  grossProfit('GROSS_PROFIT', 'Gross Profit', FinancialStatement.incomeStatement),
  adminExpenses('ADMIN_EXPENSES', 'Administrative Expenses', FinancialStatement.incomeStatement, isExpense: true),
  sellingExpenses('SELLING_EXPENSES', 'Selling & Distribution Expenses', FinancialStatement.incomeStatement,
      isExpense: true),
  operatingExpenses('OPERATING_EXPENSES', 'Operating Expenses', FinancialStatement.incomeStatement,
      isExpense: true),
  operatingProfit('OPERATING_PROFIT', 'Operating Profit', FinancialStatement.incomeStatement),
  financeCost('FINANCE_COST', 'Finance Cost', FinancialStatement.incomeStatement, isExpense: true),
  profitBeforeTax('PROFIT_BEFORE_TAX', 'Profit Before Tax', FinancialStatement.incomeStatement),
  taxExpense('TAX_EXPENSE', 'Tax Expense', FinancialStatement.incomeStatement, isExpense: true),
  netProfit('NET_PROFIT', 'Net Profit After Tax', FinancialStatement.incomeStatement),
  currentAssets('CURRENT_ASSETS', 'Current Assets', FinancialStatement.balanceSheet),
  cashAndEquivalents('CASH_AND_EQUIVALENTS', 'Cash and Cash Equivalents', FinancialStatement.balanceSheet),
  inventory('INVENTORY', 'Inventory', FinancialStatement.balanceSheet),
  tradeReceivables('TRADE_RECEIVABLES', 'Receivables', FinancialStatement.balanceSheet),
  totalAssets('TOTAL_ASSETS', 'Total Assets', FinancialStatement.balanceSheet),
  currentLiabilities('CURRENT_LIABILITIES', 'Current Liabilities', FinancialStatement.balanceSheet),
  totalLiabilities('TOTAL_LIABILITIES', 'Total Liabilities', FinancialStatement.balanceSheet),
  totalDebt('TOTAL_DEBT', 'Total Debt', FinancialStatement.balanceSheet),
  shareholdersEquity('SHAREHOLDERS_EQUITY', "Shareholders' Equity", FinancialStatement.balanceSheet),
  operatingCashFlow('OPERATING_CASH_FLOW', 'Operating Cash Flow', FinancialStatement.cashFlow),
  investingCashFlow('INVESTING_CASH_FLOW', 'Investing Cash Flow', FinancialStatement.cashFlow),
  financingCashFlow('FINANCING_CASH_FLOW', 'Financing Cash Flow', FinancialStatement.cashFlow),
  capitalExpenditure('CAPITAL_EXPENDITURE', 'Capital Expenditure', FinancialStatement.cashFlow, isExpense: true);

  const MetricCode(this.code, this.label, this.statement, {this.isExpense = false});

  final String code;
  final String label;
  final FinancialStatement statement;

  /// Expense items are stored as positive magnitudes, whatever sign the
  /// source statement used (PSX reports usually bracket expenses).
  final bool isExpense;

  static MetricCode? fromCode(String code) {
    for (final m in values) {
      if (m.code == code) return m;
    }
    return null;
  }

  /// Fields the analysis engine needs; missing ones produce warnings.
  static const required = <MetricCode>{
    totalRevenue,
    grossProfit,
    adminExpenses,
    operatingProfit,
    financeCost,
    netProfit,
    currentAssets,
    inventory,
    totalAssets,
    currentLiabilities,
    totalDebt,
    shareholdersEquity,
    operatingCashFlow,
  };
}

import 'package:equilense/features/financial_analysis/domain/company_financials.dart';
import 'package:equilense/shared/models/metric_code.dart';

/// SAMPLE DATA FOR TESTS ONLY. Figures are synthetic, not real company data.
Map<MetricCode, double> row({
  required double revenue,
  required double cogs,
  required double admin,
  required double selling,
  required double op,
  required double finance,
  required double np,
  required double ca,
  required double inventory,
  required double ta,
  required double cl,
  required double tl,
  required double debt,
  required double equity,
  required double ocf,
}) =>
    {
      MetricCode.totalRevenue: revenue,
      MetricCode.costOfSales: cogs,
      MetricCode.grossProfit: revenue - cogs,
      MetricCode.adminExpenses: admin,
      MetricCode.sellingExpenses: selling,
      MetricCode.operatingProfit: op,
      MetricCode.financeCost: finance,
      MetricCode.netProfit: np,
      MetricCode.currentAssets: ca,
      MetricCode.inventory: inventory,
      MetricCode.totalAssets: ta,
      MetricCode.currentLiabilities: cl,
      MetricCode.totalLiabilities: tl,
      MetricCode.totalDebt: debt,
      MetricCode.shareholdersEquity: equity,
      MetricCode.operatingCashFlow: ocf,
    };

CompanyFinancials sampleStrong() => CompanyFinancials(
      companyId: 'a',
      companyName: 'Sample Alpha',
      currency: 'PKR',
      values: {
        2021: row(revenue: 1000, cogs: 600, admin: 40, selling: 60, op: 300, finance: 20, np: 200, ca: 800,
            inventory: 200, ta: 2000, cl: 400, tl: 600, debt: 300, equity: 1400, ocf: 260),
        2022: row(revenue: 1200, cogs: 700, admin: 45, selling: 70, op: 385, finance: 22, np: 260, ca: 900,
            inventory: 220, ta: 2300, cl: 420, tl: 640, debt: 300, equity: 1660, ocf: 320),
        2023: row(revenue: 1440, cogs: 830, admin: 50, selling: 80, op: 480, finance: 25, np: 330, ca: 1050,
            inventory: 240, ta: 2700, cl: 450, tl: 700, debt: 320, equity: 2000, ocf: 400),
      },
    );

CompanyFinancials sampleWeak() => CompanyFinancials(
      companyId: 'b',
      companyName: 'Sample Beta',
      currency: 'PKR',
      values: {
        2021: row(revenue: 1000, cogs: 800, admin: 120, selling: 40, op: 40, finance: 50, np: 10, ca: 500,
            inventory: 300, ta: 2000, cl: 600, tl: 1400, debt: 1000, equity: 600, ocf: 5),
        2022: row(revenue: 980, cogs: 790, admin: 125, selling: 40, op: 25, finance: 55, np: -20, ca: 480,
            inventory: 310, ta: 1950, cl: 620, tl: 1370, debt: 1050, equity: 580, ocf: -10),
        2023: row(revenue: 1000, cogs: 810, admin: 130, selling: 45, op: 15, finance: 60, np: -30, ca: 470,
            inventory: 320, ta: 1900, cl: 640, tl: 1350, debt: 1100, equity: 550, ocf: 0),
      },
    );

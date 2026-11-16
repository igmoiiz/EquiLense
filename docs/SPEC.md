# MASTER DEVELOPMENT PROMPT
# PSX Financial Intelligence & Company Comparison System

## 1. YOUR ROLE

Act as a senior Flutter architect, financial software engineer, database designer, and UI/UX engineer.

Your task is to design and build a complete, production-quality Flutter application from scratch.

Do not build just a prototype, static dashboard, or collection of UI screens. Build a functional financial analysis platform with working document processing, financial calculations, forecasting, company comparison, investment scoring, database persistence, and reporting.

You are responsible for the complete development lifecycle:

- Project initialization and architecture.
- UI/UX design.
- Supabase integration.
- Database schema and migrations.
- Authentication.
- PDF and Excel processing.
- Financial calculations.
- Forecasting algorithms.
- Investment scoring.
- Data visualization.
- Error handling.
- Testing.
- Documentation.

Make reasonable engineering decisions independently. Do not repeatedly ask for permission for ordinary implementation decisions.

---

# 2. PROJECT OVERVIEW

Project Name: PSX Financial Intelligence & Comparison System

Project Type: Financial Analysis and Investment Decision Support Application.

Target Platform:
- Android
- iOS
- Web (where package compatibility permits)

### Main Objective

Build an application that allows users to upload financial statements of two Pakistan Stock Exchange (PSX)-listed companies and automatically analyze, compare, forecast, and evaluate their financial performance.

The application should eliminate the need for manually reading annual reports, calculating financial ratios, comparing historical performance, forecasting future results, and making subjective company comparisons.

Users should receive an organized financial report containing:

1. Historical financial performance.
2. Revenue and profit growth.
3. Horizontal analysis.
4. Vertical analysis.
5. Financial ratio analysis.
6. Fourth-year financial forecasting.
7. Weighted multi-factor scoring.
8. Industry-adjusted evaluation.
9. Side-by-side company comparison.
10. Final financial performance verdict.

The system evaluates financial fundamentals. It must not claim to provide guaranteed investment returns or a complete stock valuation.

---

# 3. STRICT TECHNOLOGY CONSTRAINTS

Use ONLY the following primary technologies.

### Frontend
- Flutter
- Dart
- Material 3
- fl_chart for charts

### Backend Infrastructure
- Supabase

### Database
- Supabase PostgreSQL

### Authentication
- Supabase Auth

### File Storage
- Supabase Storage

### Database Security
- PostgreSQL Row Level Security (RLS)

### Financial Processing
- Dart-based mathematical calculations.
- Dart-compatible PDF processing packages.
- Dart-compatible Excel processing packages.

### API Communication
- Supabase Flutter SDK.

## STRICT PROHIBITIONS

DO NOT introduce:

- FastAPI.
- Flask.
- Django.
- Node.js backend.
- Express.js.
- Python backend.
- Separate REST API server.
- Firebase.
- MongoDB.
- Another database service.

All application-side processing must happen in Flutter/Dart.

Supabase is the only backend infrastructure.

Supabase Edge Functions are not required for the initial implementation. Do not introduce them unless a genuine security or platform limitation makes server-side execution necessary.

Do not expose Supabase service-role keys or other privileged credentials in Flutter.

---

# 4. SYSTEM ARCHITECTURE

Implement the following architecture:

FLUTTER APPLICATION
    |
    |-- Authentication
    |-- Document Upload
    |-- PDF/Excel Extraction
    |-- Financial Data Standardization
    |-- Financial Calculation Engine
    |-- Financial Ratio Engine
    |-- Forecasting Engine
    |-- Investment Scoring Engine
    |-- Comparison Dashboard
    |-- Reporting and Export
    |
    v
SUPABASE
    |
    |-- Supabase Auth
    |-- PostgreSQL Database
    |-- Supabase Storage
    |-- Row Level Security
    |-- Realtime (optional, where useful)

### Processing Flow

1. User authenticates.
2. User creates a financial comparison project.
3. User selects two companies.
4. User uploads three years of financial statements for each company.
5. Flutter extracts financial information.
6. Extracted information is mapped into standardized financial fields.
7. User reviews and validates extracted values.
8. Flutter performs financial calculations.
9. Flutter forecasts the fourth financial year.
10. Flutter calculates weighted company scores.
11. Flutter generates the comparative analysis.
12. Results are persisted in Supabase.
13. Dashboard displays all results.

The application must remain modular so that individual engines can be maintained and tested independently.

---

# 5. CORE APPLICATION MODULES

## MODULE 1: Authentication and User Management

Implement:

- User registration.
- Login.
- Logout.
- Password reset.
- Session persistence.
- User profile.
- Account settings.

Use Supabase Auth.

Each user must only access their own private analyses, documents, and financial records.

Implement RLS policies for all user-owned records.

## MODULE 2: Company Management

Create a company management section.

Each company should contain:

- Company name.
- PSX ticker symbol.
- Industry.
- Sector.
- Optional company description.
- Optional stock exchange information.

Allow users to:

- Add companies.
- Edit company details.
- Search companies.
- Select companies for comparison.
- Reuse previously added companies.

Do not assume every company has already been registered in the system.

## MODULE 3: Financial Document Management

Users must be able to upload financial documents for both companies.

Supported formats:

- PDF.
- XLSX.
- XLS, if supported reliably by the chosen Dart package.

Expected input:

Company A:
- Year 1 financial statement.
- Year 2 financial statement.
- Year 3 financial statement.

Company B:
- Year 1 financial statement.
- Year 2 financial statement.
- Year 3 financial statement.

Provide a clean document upload interface.

Requirements:

- File picker.
- File type validation.
- File size validation.
- Upload progress.
- Upload error handling.
- Document preview where possible.
- Document deletion.
- Document replacement.
- Financial year assignment.

Store original documents in private Supabase Storage buckets.

Store document metadata and storage paths in PostgreSQL.

Never store entire PDF or Excel documents as database binary fields.

## MODULE 4: Financial Data Extraction

This is one of the most important modules.

Extract financial statement line items from PDF and Excel documents.

Relevant financial information includes:

### Income Statement
- Revenue.
- Cost of Sales.
- Gross Profit.
- Administrative Expenses.
- Selling and Distribution Expenses.
- Operating Expenses.
- Operating Profit.
- Finance Cost.
- Profit Before Tax.
- Tax Expense.
- Net Profit After Tax.

### Balance Sheet
- Current Assets.
- Cash and Cash Equivalents.
- Inventory.
- Receivables.
- Total Assets.
- Current Liabilities.
- Total Liabilities.
- Total Debt.
- Shareholders' Equity.

### Cash Flow Statement
- Operating Cash Flow.
- Investing Cash Flow.
- Financing Cash Flow.
- Capital Expenditure, if available.

Additional fields should be supported where relevant.

### Extraction Strategy

Use appropriate Dart packages.

Investigate package compatibility before implementation.

Possible packages include:
- syncfusion_flutter_pdf (check licensing).
- pdfrx or another suitable PDF text extraction package.
- excel or another maintained XLSX package.
- file_picker.

Do not assume that every PDF contains machine-readable text.

Scanned PDFs may require OCR. If reliable on-device OCR is unavailable or too resource-intensive, clearly report that limitation and provide a manual entry/review workflow.

### Important

Different companies use different financial terminology.

For example:

- Sales.
- Turnover.
- Revenue from Contracts with Customers.
- Total Revenue.

These may map to a standardized field called TOTAL_REVENUE.

Similarly:

- Profit After Tax.
- Net Earnings.
- Net Profit for the Year.

These may map to NET_PROFIT.

Implement a standardized financial taxonomy and configurable keyword mapping system.

Do not blindly map every similar-looking label.

Preserve:
- Original extracted label.
- Original extracted value.
- Standardized field.
- Source document.
- Financial year.
- Extraction confidence, where available.

### Manual Validation Interface

After extraction, show a review screen containing:

- Extracted financial field.
- Original label.
- Extracted value.
- Assigned standardized field.
- Financial year.
- Validation status.

Users must be able to:

- Edit values.
- Correct mappings.
- Add missing values.
- Remove incorrect values.
- Confirm the dataset.

Never run final analysis on unvalidated or structurally invalid data without explicitly notifying the user.

---

# 6. MODULE 5: FINANCIAL ANALYSIS ENGINE

Implement all calculations in Dart.

Separate formulas into reusable, independently testable functions.

### A. Horizontal Analysis

Calculate Year-over-Year growth.

Formula:

YoY Growth (%) =
((Current Year - Previous Year) / Previous Year) × 100

Calculate this for:

- Revenue.
- Gross Profit.
- Operating Profit.
- Net Profit.
- Total Assets.
- Shareholders' Equity.

Calculate three-year CAGR where sufficient historical data exists.

CAGR Formula:

CAGR = ((Ending Value / Beginning Value) ^ (1 / Number of Years) - 1) × 100

Important:
Three annual observations spanning Year 1 to Year 3 represent two elapsed annual periods. Use the actual elapsed period count, not automatically three.

Handle zero and negative starting values separately. Do not produce mathematically misleading CAGR values.

### B. Vertical Analysis

Convert income statement line items into percentages of revenue.

Formula:

Vertical Percentage = (Financial Line Item / Total Revenue) × 100

Revenue = 100%.

Calculate:

- Cost of Sales %.
- Gross Profit %.
- Administrative Expenses %.
- Selling Expenses %.
- Operating Expenses %.
- Operating Profit %.
- Finance Cost %.
- Net Profit %.

### C. Financial Ratio Analysis

Implement three categories.

LIQUIDITY:

1. Current Ratio

Current Assets / Current Liabilities

2. Quick Ratio

(Current Assets - Inventory) / Current Liabilities

PROFITABILITY:

3. Gross Profit Margin

(Gross Profit / Revenue) × 100

4. Net Profit Margin

(Net Profit / Revenue) × 100

5. Return on Equity (ROE)

(Net Profit / Shareholders' Equity) × 100

Use average shareholders' equity when opening and closing balances are available, and document the chosen methodology.

SOLVENCY:

6. Debt-to-Equity Ratio

Total Debt / Total Equity

7. Interest Coverage Ratio

Operating Profit / Finance Cost

The system must support missing values and denominator validation.

Never silently substitute zero for missing financial information.

### Financial Data Integrity

Implement:

- Null handling.
- Division-by-zero handling.
- Negative-value handling.
- Currency consistency checks.
- Financial-year consistency checks.
- Missing-field warnings.
- Invalid-input detection.

Every result must be traceable to its underlying financial data.

---

# 7. MODULE 6: FORECASTING ENGINE

Forecast the fourth year using the three available historical financial years.

Implement two methods.

### A. Linear Regression / Trend Extrapolation

Fit a linear trend across three historical observations:

Y1, Y2, Y3

Predict Y4.

Apply to:
- Revenue.
- Net Profit.

Use a clearly documented least-squares implementation.

### B. Weighted Moving Growth

Give greater importance to the most recent growth rate.

Use configurable weights that sum to 1.

For example:

- Most recent growth: 50%.
- Previous growth: 30%.
- Oldest available growth observation: 20%, where applicable.

The exact weighting methodology must be configurable and clearly documented.

Forecast Formula:

Predicted Revenue Y4 = Revenue Y3 × (1 + Weighted Growth Rate)

Apply the same principle to net profit only when the underlying data supports a meaningful calculation.

### C. Margin Stability Projection

Project expenses using historical vertical analysis.

Calculate the three-year average overhead percentage.

Projected Expense Y4 = Forecast Revenue Y4 × Average Historical Overhead Percentage

Clearly distinguish actual historical figures from projected values.

### Forecasting Interface

Display:

- Historical revenue.
- Forecasted revenue.
- Historical net profit.
- Forecasted net profit.
- Growth trends.
- Forecast methodology.
- Assumptions.
- Limitations.

Show forecasts as estimates, not guaranteed financial outcomes.

---

# 8. MODULE 7: INVESTMENT SCORING ENGINE

Implement a Weighted Multi-Factor Scoring Model.

Maximum score: 100 points.

### Scoring Distribution

| Evaluation Metric | Weight |
|---|---:|
| Revenue Growth | 25% |
| Return on Equity | 25% |
| Overhead Efficiency | 20% |
| Balance Sheet Safety | 15% |
| Operating Cash Flow Quality | 15% |
| TOTAL | 100% |

### Scoring Criteria

1. REVENUE GROWTH

Higher three-year revenue CAGR receives a higher score.

2. RETURN ON EQUITY

Higher ROE receives a higher score.

3. OVERHEAD EFFICIENCY

Lower administrative overhead as a percentage of revenue receives a higher score.

4. BALANCE SHEET SAFETY

Evaluate:
- Current Ratio.
- Debt-to-Equity.

The initial reference thresholds are:

- Current Ratio: preferably above 1.5x–2.0x.
- Debt-to-Equity: preferably below 0.5x.

5. CASH FLOW QUALITY

Evaluate Operating Cash Flow relative to Net Profit.

Higher positive cash conversion receives a higher score.

### Scoring Implementation

Build a transparent scoring algorithm.

Requirements:

- Every metric must have a defined scoring function.
- Each criterion must contribute according to its weight.
- Scores must be normalized to their allocated points.
- Missing metrics must not automatically receive zero.
- If data is insufficient, mark the score as incomplete.
- Show individual metric scores.
- Show the total score.
- Explain why a company received its score.

Do not invent scoring formulas without documenting them.

Where the original specification provides only directional criteria and thresholds, implement sensible configurable normalization rules and document them.

### Final Decision Rules

Implement the supplied decision rules:

- If Company A exceeds Company B by more than 10 points, recommend Company A.
- If Company B exceeds Company A by more than 10 points, recommend Company B.
- If the scores are within 5 points, classify as TIE / HOLD BOTH.

The original specification does not define the 5–10 point interval. Do not silently invent a recommendation for that interval. Classify it as INCONCLUSIVE / REVIEW REQUIRED.

Also classify comparisons with insufficient data as INSUFFICIENT DATA.

Clearly state that this is a financial performance comparison, not personalized investment advice.

---

# 9. MODULE 8: DYNAMIC INDUSTRY ADJUSTMENTS

Allow users to choose an industry for the comparison.

Initial supported industry categories:

- Technology / SaaS.
- Manufacturing.
- Capital Intensive.
- Banking.
- Insurance.
- Other.

Allow industry-specific scoring weights.

Examples:

Technology / SaaS:
- Higher emphasis on Gross Margin.
- Higher emphasis on ROE.

Manufacturing / Capital Intensive:
- Higher emphasis on Debt-to-Equity.
- Higher emphasis on Asset Turnover.

Important:
The original specification only provides illustrative adjustments for Technology/SaaS and Capital Intensive/Manufacturing.

For banking and insurance, do not reuse ordinary industrial-company ratio assumptions without appropriate financial methodology. Provide an explicit unsupported or specialized-analysis status until suitable rules are implemented.

Industry weights must be configurable and sum to 100%.

Allow the user to see which scoring weights were applied.

---

# 10. MODULE 9: COMPANY COMPARISON DASHBOARD

Build a professional financial dashboard.

The dashboard must display the two selected companies side by side.

### Dashboard Sections

A. OVERVIEW

- Company A.
- Company B.
- Selected financial years.
- Overall scores.
- Comparison status.
- Financial performance verdict.

B. REVENUE AND GROWTH

- Revenue comparison.
- Revenue CAGR.
- YoY growth.
- Gross profit comparison.
- Net profit comparison.

C. PROFITABILITY

- Gross Margin.
- Net Margin.
- ROE.

D. LIQUIDITY AND SOLVENCY

- Current Ratio.
- Quick Ratio.
- Debt-to-Equity.
- Interest Coverage.

E. CASH FLOW

- Operating Cash Flow.
- Net Profit.
- Cash Conversion Ratio.

F. FORECASTING

- Fourth-year revenue forecast.
- Fourth-year net profit forecast.
- Historical versus projected charts.

G. SCORING

- Individual criterion scores.
- Weight distribution.
- Total score.
- Comparative score visualization.

H. FINAL VERDICT

Explain:
- Which company scored higher.
- Which company has stronger growth.
- Which company has stronger profitability.
- Which company has better liquidity.
- Which company has better cash flow quality.
- What weaknesses were identified.
- Why the final verdict was produced.

Do not make the verdict a simple unexplained winner label.

---

# 11. USER INTERFACE AND DESIGN REQUIREMENTS

Build a professional financial software interface.

### Design Direction

Use:
- Material 3.
- Clean typography.
- Professional financial dashboard layout.
- Consistent spacing.
- Clear visual hierarchy.
- Responsive layouts.
- Reusable components.

Avoid:
- Excessive gradients.
- Excessive animations.
- Unnecessary decorative elements.
- Overly colorful dashboards.
- Crowded tables.
- Generic AI-generated dashboard aesthetics.

### Main Application Screens

1. Splash Screen.
2. Onboarding.
3. Login.
4. Registration.
5. Forgot Password.
6. Main Dashboard.
7. Company Management.
8. Create New Analysis.
9. Company Selection.
10. Document Upload.
11. Extraction Progress.
12. Financial Data Validation.
13. Historical Analysis.
14. Financial Ratios.
15. Forecasting.
16. Investment Scoring.
17. Company Comparison.
18. Final Investment Verdict.
19. Saved Analyses.
20. Analysis Details.
21. Reports and Exports.
22. User Profile.
23. Application Settings.

### Navigation

Use a responsive navigation structure.

For mobile:
- Bottom navigation or a suitable drawer.

For web/tablet:
- Sidebar navigation.

### Dashboard Overview

The home screen should show:

- Total analyses.
- Saved companies.
- Recent comparisons.
- Latest analysis results.
- Create New Analysis action.

All displayed metrics must come from actual database records.

Never use fake financial figures in the production dashboard.

For development, use clearly labeled sample datasets.

---

# 12. REPORT GENERATION

Allow users to export analysis results.

Supported output:

- PDF report.
- Excel report, where feasible.

PDF report should contain:

1. Report title.
2. Company information.
3. Historical financial statements.
4. Horizontal analysis.
5. Vertical analysis.
6. Financial ratios.
7. Forecasting results.
8. Scoring breakdown.
9. Company comparison.
10. Final verdict.
11. Assumptions and limitations.

Excel output should contain separate worksheets for:

- Company A.
- Company B.
- Historical Analysis.
- Financial Ratios.
- Forecasting.
- Scoring.
- Final Comparison.

Exported figures must match the calculations displayed in the application.

---

# 13. SUPABASE DATABASE DESIGN

Design a normalized PostgreSQL database.

Create SQL migration files.

At minimum, implement the following tables.

### profiles
- id (references auth.users)
- full_name
- email
- created_at
- updated_at

### companies
- id
- user_id
- company_name
- ticker_symbol
- sector
- industry
- description
- created_at

### analyses
- id
- user_id
- company_a_id
- company_b_id
- analysis_name
- industry
- status
- created_at
- updated_at

### documents
- id
- analysis_id
- company_id
- user_id
- file_name
- storage_path
- file_type
- financial_year
- document_type
- upload_status
- created_at

### financial_periods
- id
- company_id
- analysis_id
- financial_year
- currency
- created_at

### financial_metrics
- id
- analysis_id
- company_id
- financial_period_id
- metric_code
- original_label
- standardized_value
- original_value
- source_document_id
- validation_status
- created_at

### metric_mappings
- id
- user_id
- original_label
- standardized_metric_code
- created_at

### financial_ratios
- id
- analysis_id
- company_id
- financial_year
- ratio_code
- ratio_value
- calculation_status

### forecasts
- id
- analysis_id
- company_id
- forecast_year
- metric_code
- forecast_value
- forecasting_method
- assumptions

### company_scores
- id
- analysis_id
- company_id
- criterion
- weight
- raw_metric_value
- awarded_points
- maximum_points

### industry_weights
- id
- industry
- criterion
- weight
- updated_at

### analysis_results
- id
- analysis_id
- company_a_score
- company_b_score
- verdict
- explanation
- created_at

Add:
- Primary keys.
- Foreign keys.
- Appropriate indexes.
- Unique constraints.
- Timestamps.
- Referential integrity.
- Appropriate numeric precision.

Adjust the schema where necessary to support multiple documents, financial periods, and repeated analyses without duplication.

### Supabase Security

Enable RLS on every user-owned table.

Implement policies that ensure:

- Users can only access their own analyses.
- Users can only access their own companies.
- Users can only access their own uploaded documents.
- Users cannot access another user's financial data.
- Storage access is restricted to authorized users.
- No privileged keys are embedded in the application.

Create a private storage bucket named:

financial-documents

Use user-scoped storage paths.

Provide all SQL migrations and RLS policies in the project repository.

---

# 14. FLUTTER PROJECT ARCHITECTURE

Use a feature-first architecture with clear separation of responsibilities.

Suggested structure:

lib/
|
|-- main.dart
|
|-- app/
|   |-- app.dart
|   |-- router.dart
|   |-- theme/
|   |-- constants/
|
|-- core/
|   |-- errors/
|   |-- utils/
|   |-- services/
|   |-- widgets/
|   |-- extensions/
|
|-- features/
|   |
|   |-- authentication/
|   |   |-- data/
|   |   |-- domain/
|   |   |-- presentation/
|   |
|   |-- dashboard/
|   |-- companies/
|   |-- analysis/
|   |-- documents/
|   |-- extraction/
|   |-- validation/
|   |-- financial_analysis/
|   |-- forecasting/
|   |-- scoring/
|   |-- comparison/
|   |-- reports/
|   |-- profile/
|
|-- shared/
    |-- models/
    |-- widgets/
    |-- enums/

Use a consistent state-management solution.

Prefer Riverpod unless there is a strong technical reason to choose another solution.

Use:
- Repository pattern.
- Service layer.
- Immutable models where practical.
- Dependency injection.
- Centralized error handling.
- Reusable UI components.

Do not create unnecessary abstractions.

Keep business logic separate from widgets.

The financial calculation engine must be independent of Flutter UI so that it can be tested without rendering screens.

---

# 15. PERFORMANCE AND RELIABILITY

The application must:

- Process documents without freezing the UI.
- Use asynchronous operations.
- Move expensive parsing work off the main UI isolate where appropriate.
- Show processing progress.
- Handle large files carefully.
- Avoid unnecessary database queries.
- Cache suitable data locally.
- Handle network interruptions.
- Support retry operations.
- Prevent duplicate analysis submissions.
- Handle partial uploads.
- Preserve validated financial data.
- Display meaningful error messages.

Use local persistence only where useful.

Do not store sensitive credentials in ordinary preferences.

---

# 16. TESTING REQUIREMENTS

Testing is mandatory.

### Unit Tests

Test:
- YoY growth.
- CAGR.
- Vertical analysis.
- Current Ratio.
- Quick Ratio.
- Gross Margin.
- Net Margin.
- ROE.
- Debt-to-Equity.
- Interest Coverage.
- Linear Regression.
- Weighted Growth.
- Forecasting.
- Scoring normalization.
- Verdict generation.

Include:
- Zero values.
- Negative values.
- Missing values.
- Invalid values.
- Different currencies.
- Insufficient historical data.

### Integration Tests

Test:
- Supabase authentication.
- Document uploads.
- Document retrieval.
- Financial data persistence.
- RLS access restrictions.
- Analysis creation.
- Result retrieval.

### UI Tests

Test:
- Login and registration.
- Company selection.
- Document upload.
- Financial data validation.
- Dashboard rendering.
- Company comparison.
- Report export.

---

# 17. DEVELOPMENT ROADMAP

Build the application in phases.

Do not attempt to generate the entire application in one uncontrolled code-generation pass.

### PHASE 1: FOUNDATION

- Inspect the existing development environment.
- Initialize Flutter project.
- Configure Material 3.
- Establish architecture.
- Configure Supabase.
- Implement navigation.
- Set up environment configuration.
- Create SQL migrations.
- Configure authentication.

Deliverable: Functional application foundation.

### PHASE 2: COMPANY AND DOCUMENT MANAGEMENT

- Company management.
- Analysis creation.
- Company selection.
- PDF/Excel uploads.
- Supabase Storage.
- Document metadata.
- Upload progress and error handling.

Deliverable: Users can create analyses and upload documents.

### PHASE 3: EXTRACTION AND VALIDATION

- PDF extraction.
- Excel extraction.
- Financial line-item identification.
- Standardized financial taxonomy.
- Keyword mapping.
- Manual financial data entry.
- Validation interface.

Deliverable: Users can extract, review, correct, and save financial data.

### PHASE 4: FINANCIAL CALCULATION ENGINE

- Horizontal analysis.
- Vertical analysis.
- Financial ratios.
- Data integrity checks.
- Unit tests.

Deliverable: Fully working historical financial analysis.

### PHASE 5: FORECASTING ENGINE

- Linear regression.
- Weighted moving growth.
- Margin stability projections.
- Forecast visualization.
- Forecast assumptions.

Deliverable: Functional fourth-year forecasting.

### PHASE 6: INVESTMENT SCORING ENGINE

- Weighted scoring.
- Metric normalization.
- Industry-specific weights.
- Comparison verdict.
- Explainability.

Deliverable: Functional comparative evaluation.

### PHASE 7: DASHBOARD

- Financial overview.
- Comparative charts.
- Ratio tables.
- Growth charts.
- Forecast charts.
- Scoring visualization.
- Final verdict.

Deliverable: Complete financial intelligence dashboard.

### PHASE 8: REPORTING AND EXPORT

- PDF export.
- Excel export.
- Saved analyses.
- Historical report retrieval.

Deliverable: Complete reporting system.

### PHASE 9: TESTING AND FINALIZATION

- Unit testing.
- Integration testing.
- UI testing.
- Performance optimization.
- Security review.
- Error handling.
- Documentation.
- Release configuration.

Deliverable: Complete working application.

---

# 18. DOCUMENTATION REQUIREMENTS

Maintain the following documentation in the repository:

README.md
- Project introduction.
- Features.
- Technologies.
- Installation.
- Execution instructions.

ARCHITECTURE.md
- System architecture.
- Flutter structure.
- Supabase integration.
- Data flow.

DATABASE.md
- Database schema.
- Relationships.
- RLS policies.
- Storage structure.

FINANCIAL_FORMULAS.md
- Every financial formula.
- Input requirements.
- Calculation methodology.
- Edge cases.
- Scoring methodology.
- Forecasting methodology.

IMPLEMENTATION_PLAN.md
- Development phases.
- Completed tasks.
- Pending tasks.
- Known limitations.

SECURITY.md
- Authentication.
- Database security.
- Storage security.
- Credential management.

TESTING.md
- Test cases.
- Test execution.
- Expected results.

Also maintain a CHANGELOG.md.

Update documentation whenever implementation decisions change.

---

# 19. IMPORTANT ENGINEERING RULES

Follow these rules throughout development.

1. Build functional features, not placeholder screens.
2. Never fabricate financial figures.
3. Never hardcode production dashboard data.
4. Never silently ignore missing financial values.
5. Never perform financial calculations using an LLM.
6. Never expose privileged Supabase credentials.
7. Never bypass RLS.
8. Never mix financial business logic with UI widgets.
9. Never introduce a separate backend server.
10. Never create unnecessary duplicate models or services.
11. Never leave dead code or unused dependencies.
12. Never claim a feature is complete without testing it.
13. Keep the application responsive.
14. Use proper loading, empty, success, and error states.
15. Make all financial outputs explainable.
16. Ensure all displayed calculations are traceable to source data.
17. Keep implementation simple, clean, maintainable, and extensible.

If a dependency is discontinued, incompatible, or requires a paid license, evaluate alternatives before adopting it.

Do not sacrifice security or financial correctness for implementation convenience.

---

# 20. INITIAL EXECUTION INSTRUCTIONS

Before writing application code:

1. Inspect the current working directory.
2. Check whether a Flutter project already exists.
3. Inspect installed Flutter and Dart versions.
4. Check the available Supabase configuration.
5. Identify package compatibility issues.
6. Create an implementation plan.
7. Define the database schema.
8. Establish the project architecture.
9. Identify technical risks, especially PDF extraction and scanned documents.
10. Begin Phase 1.

If no project exists, initialize a new Flutter project.

Do not overwrite existing work without inspecting it.

Use the terminal to create files and execute commands.

After every major phase:

- Run Flutter analysis.
- Run relevant tests.
- Resolve errors.
- Update documentation.
- Record completed and pending work.

Maintain a clear development checklist so progress can resume after interruptions.

Do not stop after generating a plan or UI mockup. Continue implementing the application phase by phase.

At the end of each phase, report:
- What was implemented.
- Files created or modified.
- Tests executed.
- Outstanding issues.
- Next implementation phase.

# FINAL EXPECTATION

Deliver a complete, working Flutter-based PSX Financial Intelligence and Company Comparison System backed exclusively by Supabase.

The finished application must allow a user to upload financial statements for two PSX-listed companies, extract and validate financial information, calculate historical financial performance, calculate financial ratios, forecast the fourth year, apply weighted investment scoring, compare companies, and generate a comprehensive financial report.

The application must be functional, secure, mathematically correct, maintainable, and ready for further development and deployment.

Start by inspecting the environment and executing Phase 1.
/// Immutable database row models.
library;

double? _d(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
DateTime? _dt(Object? v) => v == null ? null : DateTime.parse(v as String);

class Company {
  const Company({
    required this.id,
    required this.name,
    this.ticker,
    this.sector,
    this.industry = 'other',
    this.description,
    this.exchange = 'PSX',
  });

  factory Company.fromJson(Map<String, dynamic> j) => Company(
        id: j['id'] as String,
        name: j['company_name'] as String,
        ticker: j['ticker_symbol'] as String?,
        sector: j['sector'] as String?,
        industry: (j['industry'] as String?) ?? 'other',
        description: j['description'] as String?,
        exchange: (j['exchange'] as String?) ?? 'PSX',
      );

  final String id;
  final String name;
  final String? ticker;
  final String? sector;
  final String industry;
  final String? description;
  final String exchange;

  String get display => ticker == null ? name : '$name ($ticker)';

  Map<String, dynamic> toWrite() => {
        'company_name': name.trim(),
        'ticker_symbol': (ticker?.trim().isEmpty ?? true) ? null : ticker!.trim().toUpperCase(),
        'sector': (sector?.trim().isEmpty ?? true) ? null : sector!.trim(),
        'industry': industry,
        'description': (description?.trim().isEmpty ?? true) ? null : description!.trim(),
        'exchange': exchange.trim().isEmpty ? 'PSX' : exchange.trim(),
      };
}

class Industry {
  const Industry({required this.code, required this.label, required this.supported, this.notes});

  factory Industry.fromJson(Map<String, dynamic> j) => Industry(
        code: j['code'] as String,
        label: j['label'] as String,
        supported: j['support_status'] == 'supported',
        notes: j['notes'] as String?,
      );

  final String code;
  final String label;
  final bool supported;
  final String? notes;
}

enum AnalysisStatus {
  draft('draft', 'Draft'),
  dataValidated('data_validated', 'Data validated'),
  completed('completed', 'Completed'),
  archived('archived', 'Archived');

  const AnalysisStatus(this.db, this.label);
  final String db;
  final String label;

  static AnalysisStatus fromDb(String v) => values.firstWhere((e) => e.db == v, orElse: () => draft);
}

class AnalysisResultSummary {
  const AnalysisResultSummary({
    required this.verdict,
    required this.scoreA,
    required this.scoreB,
    required this.explanation,
    required this.updatedAt,
  });

  factory AnalysisResultSummary.fromJson(Map<String, dynamic> j) => AnalysisResultSummary(
        verdict: j['verdict'] as String,
        scoreA: _d(j['company_a_score']),
        scoreB: _d(j['company_b_score']),
        explanation: j['explanation'] as String,
        updatedAt: _dt(j['updated_at'])!,
      );

  final String verdict;
  final double? scoreA;
  final double? scoreB;
  final String explanation;
  final DateTime updatedAt;
}

class Analysis {
  const Analysis({
    required this.id,
    required this.name,
    required this.companyA,
    required this.companyB,
    required this.industry,
    required this.firstYear,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.scoringWeights,
    this.result,
  });

  /// Expects companies embedded as `company_a` / `company_b` and the optional
  /// `analysis_results` relation.
  factory Analysis.fromJson(Map<String, dynamic> j) {
    final results = j['analysis_results'];
    final r = results is List ? (results.isEmpty ? null : results.first) : results;
    return Analysis(
      id: j['id'] as String,
      name: j['analysis_name'] as String,
      companyA: Company.fromJson(j['company_a'] as Map<String, dynamic>),
      companyB: Company.fromJson(j['company_b'] as Map<String, dynamic>),
      industry: j['industry'] as String,
      firstYear: j['first_financial_year'] as int,
      currency: (j['currency'] as String).trim(),
      status: AnalysisStatus.fromDb(j['status'] as String),
      scoringWeights: (j['scoring_weights'] as Map?)?.cast<String, dynamic>(),
      createdAt: _dt(j['created_at'])!,
      updatedAt: _dt(j['updated_at'])!,
      result: r == null ? null : AnalysisResultSummary.fromJson(r as Map<String, dynamic>),
    );
  }

  static const select = '*, '
      'company_a:companies!analyses_company_a_id_user_id_fkey(*), '
      'company_b:companies!analyses_company_b_id_user_id_fkey(*), '
      'analysis_results(verdict, company_a_score, company_b_score, explanation, updated_at)';

  final String id;
  final String name;
  final Company companyA;
  final Company companyB;
  final String industry;
  final int firstYear;
  final String currency;
  final AnalysisStatus status;
  final Map<String, dynamic>? scoringWeights;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AnalysisResultSummary? result;

  static const yearsPerCompany = 3;
  List<int> get years => [for (var i = 0; i < yearsPerCompany; i++) firstYear + i];
  List<Company> get companies => [companyA, companyB];
}

class FinancialDocument {
  const FinancialDocument({
    required this.id,
    required this.companyId,
    required this.fileName,
    required this.storagePath,
    required this.fileType,
    required this.sizeBytes,
    required this.year,
    required this.documentType,
    required this.uploadStatus,
    required this.createdAt,
    this.extractionMessage,
  });

  factory FinancialDocument.fromJson(Map<String, dynamic> j) => FinancialDocument(
        id: j['id'] as String,
        companyId: j['company_id'] as String,
        fileName: j['file_name'] as String,
        storagePath: j['storage_path'] as String,
        fileType: j['file_type'] as String,
        sizeBytes: (j['file_size_bytes'] as num).toInt(),
        year: j['financial_year'] as int,
        documentType: j['document_type'] as String,
        uploadStatus: j['upload_status'] as String,
        extractionMessage: j['extraction_message'] as String?,
        createdAt: _dt(j['created_at'])!,
      );

  final String id;
  final String companyId;
  final String fileName;
  final String storagePath;
  final String fileType;
  final int sizeBytes;
  final int year;
  final String documentType;
  final String uploadStatus;
  final String? extractionMessage;
  final DateTime createdAt;
}

class FinancialPeriod {
  const FinancialPeriod({
    required this.id,
    required this.companyId,
    required this.year,
    required this.currency,
    required this.isValidated,
  });

  factory FinancialPeriod.fromJson(Map<String, dynamic> j) => FinancialPeriod(
        id: j['id'] as String,
        companyId: j['company_id'] as String,
        year: j['financial_year'] as int,
        currency: (j['currency'] as String).trim(),
        isValidated: j['is_validated'] as bool,
      );

  final String id;
  final String companyId;
  final int year;
  final String currency;
  final bool isValidated;
}

enum ValidationStatus {
  pending('pending'),
  validated('validated'),
  rejected('rejected');

  const ValidationStatus(this.db);
  final String db;
  static ValidationStatus fromDb(String v) => values.firstWhere((e) => e.db == v);
}

class MetricRecord {
  const MetricRecord({
    required this.id,
    required this.analysisId,
    required this.periodId,
    required this.companyId,
    required this.metricCode,
    required this.value,
    required this.entrySource,
    required this.status,
    this.originalLabel,
    this.originalValue,
    this.sourceDocumentId,
    this.confidence,
  });

  factory MetricRecord.fromJson(Map<String, dynamic> j) => MetricRecord(
        id: j['id'] as String,
        analysisId: j['analysis_id'] as String,
        periodId: j['financial_period_id'] as String,
        companyId: j['company_id'] as String,
        metricCode: j['metric_code'] as String,
        value: _d(j['standardized_value']),
        originalLabel: j['original_label'] as String?,
        originalValue: j['original_value'] as String?,
        sourceDocumentId: j['source_document_id'] as String?,
        confidence: _d(j['extraction_confidence']),
        entrySource: j['entry_source'] as String,
        status: ValidationStatus.fromDb(j['validation_status'] as String),
      );

  final String id;
  final String analysisId;
  final String periodId;
  final String companyId;
  final String metricCode;
  final double? value;
  final String? originalLabel;
  final String? originalValue;
  final String? sourceDocumentId;
  final double? confidence;
  final String entrySource;
  final ValidationStatus status;
}

class Profile {
  const Profile({required this.id, required this.email, this.fullName, required this.defaultCurrency});

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        email: j['email'] as String?,
        fullName: j['full_name'] as String?,
        defaultCurrency: (j['default_currency'] as String).trim(),
      );

  final String id;
  final String? email;
  final String? fullName;
  final String defaultCurrency;
}

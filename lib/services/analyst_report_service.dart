import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

import 'analyst_service.dart';

class AnalystReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final AnalystService _analystService = AnalystService();

  static const String destinationTrends = 'destinationTrends';

  static const String purposeDistribution = 'purposeDistribution';

  static const String checklistCompletion = 'checklistCompletion';

  static const String requirementPatterns = 'requirementPatterns';

  // ---------------------------------------------------------------------------
  // REPORT TYPES
  // ---------------------------------------------------------------------------

  String getReportTitle(String reportType) {
    switch (reportType) {
      case destinationTrends:
        return 'Destination Trends Report';

      case purposeDistribution:
        return 'Travel Purpose Distribution Report';

      case checklistCompletion:
        return 'Checklist Completion Report';

      case requirementPatterns:
        return 'Requirement Patterns Report';

      default:
        return 'Analytics Report';
    }
  }

  // ---------------------------------------------------------------------------
  // COUNTRY LOOKUP
  // ---------------------------------------------------------------------------

  Future<String> _getDestinationName(String? destinationId) async {
    if (destinationId == null) {
      return 'All Destinations';
    }

    final List<Map<String, String>> countries = await _analystService
        .getAnalyticsFilterCountries();

    for (final country in countries) {
      if (country['id'] == destinationId) {
        return country['name'] ?? destinationId;
      }
    }

    return destinationId;
  }

  String _purposeLabel(String? purpose) {
    switch (purpose) {
      case 'tourism':
        return 'Tourism';

      case 'business':
        return 'Business';

      case 'study':
        return 'Study';

      default:
        return 'All Purposes';
    }
  }

  // ---------------------------------------------------------------------------
  // GENERATE REPORT
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> generateReport({
    required String reportType,
    String? destinationId,
    String? purpose,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated analyst.');
    }

    final String destinationName = await _getDestinationName(destinationId);

    final Map<String, dynamic> reportData = await _buildReportData(
      reportType: reportType,
      destinationId: destinationId,
      purpose: purpose,
    );

    final DocumentReference<Map<String, dynamic>> reportReference = _firestore
        .collection('analystReports')
        .doc();

    final DateTime generatedAt = DateTime.now();

    final Map<String, dynamic> report = {
      'reportId': reportReference.id,
      'analystId': user.uid,
      'reportType': reportType,
      'reportTitle': getReportTitle(reportType),
      'destinationId': destinationId ?? 'all',
      'destinationName': destinationName,
      'purpose': purpose ?? 'all',
      'purposeLabel': _purposeLabel(purpose),
      'format': 'xlsx',
      'schemaVersion': 1,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'data': reportData,
    };

    await reportReference.set({
      ...report,
      'generatedAt': FieldValue.serverTimestamp(),
    });

    return report;
  }

  // ---------------------------------------------------------------------------
  // BUILD SNAPSHOT DATA
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _buildReportData({
    required String reportType,
    String? destinationId,
    String? purpose,
  }) async {
    switch (reportType) {
      case destinationTrends:
        final List<Map<String, dynamic>> destinations = await _analystService
            .getDestinationTrends(purpose: purpose);

        final List<Map<String, dynamic>> monthlyActivity = await _analystService
            .getMonthlyDepartureTrend(purpose: purpose);

        return {
          'destinations': destinations,
          'monthlyActivity': monthlyActivity,
        };

      case purposeDistribution:
        return await _analystService.getPurposeDistribution(
          destinationId: destinationId,
        );

      case checklistCompletion:
        return await _analystService.getChecklistCompletionAnalytics(
          destinationId: destinationId,
          purpose: purpose,
        );

      case requirementPatterns:
        return await _analystService.getPreparationRequirementAnalytics(
          destinationId: destinationId,
          purpose: purpose,
        );

      default:
        throw ArgumentError('Unsupported report type.');
    }
  }

  // ---------------------------------------------------------------------------
  // REPORT HISTORY
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getReportHistory() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return [];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('analystReports')
        .where('analystId', isEqualTo: user.uid)
        .get();

    final List<Map<String, dynamic>> reports = snapshot.docs.map((document) {
      return {...document.data(), 'reportId': document.id};
    }).toList();

    reports.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final Timestamp? aTime = a['generatedAt'] as Timestamp?;

      final Timestamp? bTime = b['generatedAt'] as Timestamp?;

      if (aTime == null && bTime == null) {
        return 0;
      }

      if (aTime == null) {
        return 1;
      }

      if (bTime == null) {
        return -1;
      }

      return bTime.compareTo(aTime);
    });

    return reports;
  }

  // ---------------------------------------------------------------------------
  // EXPORT
  // ---------------------------------------------------------------------------

  Future<void> exportReport(Map<String, dynamic> report) async {
    final Uint8List bytes = _createWorkbook(report);

    final String fileName = _createFileName(report);

    await SharePlus.instance.share(
      ShareParams(
        subject:
            report['reportTitle'] as String? ??
            'TravelGuard MY Analytics Report',
        text: 'TravelGuard MY aggregated analytics report.',
        files: [
          XFile.fromData(
            bytes,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        fileNameOverrides: [fileName],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EXCEL WORKBOOK
  // ---------------------------------------------------------------------------

  Uint8List _createWorkbook(Map<String, dynamic> report) {
    final Excel excel = Excel.createExcel();

    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';

    excel.rename(defaultSheet, 'Report');

    final Sheet sheet = excel['Report'];

    _appendTextRow(sheet, ['TravelGuard MY']);

    _appendTextRow(sheet, [
      report['reportTitle'] as String? ?? 'Analytics Report',
    ]);

    _appendTextRow(sheet, []);

    _appendTextRow(sheet, [
      'Destination',
      report['destinationName'] as String? ?? 'All Destinations',
    ]);

    _appendTextRow(sheet, [
      'Purpose',
      report['purposeLabel'] as String? ?? 'All Purposes',
    ]);

    _appendTextRow(sheet, [
      'Generated',
      _formatGeneratedAt(report['generatedAt']),
    ]);

    _appendTextRow(sheet, ['Format', 'Excel (.xlsx)']);

    _appendTextRow(sheet, []);

    final String reportType = report['reportType'] as String? ?? '';

    final Map<String, dynamic> data = Map<String, dynamic>.from(
      report['data'] as Map? ?? {},
    );

    switch (reportType) {
      case destinationTrends:
        _writeDestinationTrends(sheet, data);
        break;

      case purposeDistribution:
        _writePurposeDistribution(sheet, data);
        break;

      case checklistCompletion:
        _writeChecklistCompletion(sheet, data);
        break;

      case requirementPatterns:
        _writeRequirementPatterns(sheet, data);
        break;
    }

    sheet.setColumnWidth(0, 34);

    sheet.setColumnWidth(1, 24);

    sheet.setColumnWidth(2, 24);

    sheet.setColumnWidth(3, 24);

    final List<int>? encoded = excel.encode();

    if (encoded == null) {
      throw Exception('Unable to create Excel report.');
    }

    return Uint8List.fromList(encoded);
  }

  // ---------------------------------------------------------------------------
  // DESTINATION TRENDS
  // ---------------------------------------------------------------------------

  void _writeDestinationTrends(Sheet sheet, Map<String, dynamic> data) {
    _appendTextRow(sheet, ['Trips by Destination']);

    _appendTextRow(sheet, ['Destination', 'Trips', 'Percentage']);

    final List<dynamic> destinations = data['destinations'] as List? ?? [];

    for (final item in destinations) {
      final Map<String, dynamic> row = Map<String, dynamic>.from(item as Map);

      sheet.appendRow([
        TextCellValue(row['name'] as String? ?? ''),
        IntCellValue(row['count'] as int? ?? 0),
        DoubleCellValue(row['percentage'] as double? ?? 0),
      ]);
    }

    _appendTextRow(sheet, []);

    _appendTextRow(sheet, ['Travel Activity by Departure Month']);

    _appendTextRow(sheet, ['Month', 'Trips']);

    final List<dynamic> monthly = data['monthlyActivity'] as List? ?? [];

    for (final item in monthly) {
      final Map<String, dynamic> row = Map<String, dynamic>.from(item as Map);

      sheet.appendRow([
        TextCellValue(row['label'] as String? ?? ''),
        IntCellValue(row['count'] as int? ?? 0),
      ]);
    }
  }

  // ---------------------------------------------------------------------------
  // PURPOSE DISTRIBUTION
  // ---------------------------------------------------------------------------

  void _writePurposeDistribution(Sheet sheet, Map<String, dynamic> data) {
    _appendTextRow(sheet, ['Travel Purpose Distribution']);

    final Map<String, dynamic> counts = Map<String, dynamic>.from(
      data['counts'] as Map? ?? {},
    );

    final int total = data['total'] as int? ?? 0;

    _appendTextRow(sheet, ['Purpose', 'Trips', 'Percentage']);

    for (final String purpose in ['tourism', 'business', 'study']) {
      final int count = counts[purpose] as int? ?? 0;

      final double percentage = total == 0 ? 0 : (count / total) * 100;

      sheet.appendRow([
        TextCellValue(_purposeLabel(purpose)),
        IntCellValue(count),
        DoubleCellValue(percentage),
      ]);
    }

    _appendTextRow(sheet, []);

    sheet.appendRow([TextCellValue('Total Trips'), IntCellValue(total)]);
  }

  // ---------------------------------------------------------------------------
  // CHECKLIST COMPLETION
  // ---------------------------------------------------------------------------

  void _writeChecklistCompletion(Sheet sheet, Map<String, dynamic> data) {
    _appendTextRow(sheet, ['Checklist Completion Summary']);

    sheet.appendRow([
      TextCellValue('Average Completion Rate'),
      DoubleCellValue((data['overallCompletionRate'] as num? ?? 0).toDouble()),
    ]);

    sheet.appendRow([
      TextCellValue('Trips with Checklists'),
      IntCellValue(data['tripsWithChecklist'] as int? ?? 0),
    ]);

    sheet.appendRow([
      TextCellValue('Completed Checklist Items'),
      IntCellValue(data['completedChecklistItems'] as int? ?? 0),
    ]);

    sheet.appendRow([
      TextCellValue('Incomplete Checklist Items'),
      IntCellValue(data['incompleteChecklistItems'] as int? ?? 0),
    ]);

    _appendTextRow(sheet, []);

    _appendTextRow(sheet, ['Completion by Destination']);

    _appendTextRow(sheet, ['Destination', 'Trips', 'Average Completion Rate']);

    final List<dynamic> destinationComparison =
        data['destinationComparison'] as List? ?? [];

    for (final item in destinationComparison) {
      final Map<String, dynamic> row = Map<String, dynamic>.from(item as Map);

      sheet.appendRow([
        TextCellValue(row['name'] as String? ?? ''),
        IntCellValue(row['tripCount'] as int? ?? 0),
        DoubleCellValue((row['completionRate'] as num? ?? 0).toDouble()),
      ]);
    }

    _appendTextRow(sheet, []);

    _appendTextRow(sheet, ['Completion by Purpose']);

    _appendTextRow(sheet, ['Purpose', 'Trips', 'Average Completion Rate']);

    final List<dynamic> purposeComparison =
        data['purposeComparison'] as List? ?? [];

    for (final item in purposeComparison) {
      final Map<String, dynamic> row = Map<String, dynamic>.from(item as Map);

      sheet.appendRow([
        TextCellValue(_purposeLabel(row['purpose'] as String?)),
        IntCellValue(row['tripCount'] as int? ?? 0),
        DoubleCellValue((row['completionRate'] as num? ?? 0).toDouble()),
      ]);
    }

    _appendTextRow(sheet, []);

    _appendTextRow(sheet, ['Requirements for Further Investigation']);

    _appendTextRow(sheet, [
      'Requirement',
      'Generated',
      'Completed',
      'Incomplete',
      'Completion Rate',
    ]);

    final List<dynamic> requirements =
        data['requirementsNeedingAttention'] as List? ?? [];

    for (final item in requirements) {
      final Map<String, dynamic> row = Map<String, dynamic>.from(item as Map);

      sheet.appendRow([
        TextCellValue(row['title'] as String? ?? ''),
        IntCellValue(row['generated'] as int? ?? 0),
        IntCellValue(row['completed'] as int? ?? 0),
        IntCellValue(row['incomplete'] as int? ?? 0),
        DoubleCellValue((row['completionRate'] as num? ?? 0).toDouble()),
      ]);
    }
  }

  // ---------------------------------------------------------------------------
  // REQUIREMENT PATTERNS
  // ---------------------------------------------------------------------------

  void _writeRequirementPatterns(Sheet sheet, Map<String, dynamic> data) {
    final int analysedTrips = data['analysedTrips'] as int? ?? 0;

    sheet.appendRow([
      TextCellValue('Analysed Trips'),
      IntCellValue(analysedTrips),
    ]);

    _appendTextRow(sheet, []);

    _appendTextRow(sheet, ['Requirement Patterns']);

    _appendTextRow(sheet, [
      'Requirement',
      'Trips',
      'Percentage',
      'Destinations',
      'Purposes',
    ]);

    final List<dynamic> patterns = data['requirementPatterns'] as List? ?? [];

    for (final item in patterns) {
      final Map<String, dynamic> row = Map<String, dynamic>.from(item as Map);

      final List<dynamic> destinations =
          row['destinationBreakdown'] as List? ?? [];

      final List<dynamic> purposes = row['purposeBreakdown'] as List? ?? [];

      final String destinationText = destinations
          .map((item) {
            final Map<String, dynamic> destination = Map<String, dynamic>.from(
              item as Map,
            );

            return '${destination['name']} (${destination['tripCount']})';
          })
          .join(', ');

      final String purposeText = purposes
          .map((item) {
            final Map<String, dynamic> purpose = Map<String, dynamic>.from(
              item as Map,
            );

            return '${_purposeLabel(purpose['purpose'] as String?)} '
                '(${purpose['tripCount']})';
          })
          .join(', ');

      sheet.appendRow([
        TextCellValue(row['title'] as String? ?? ''),
        IntCellValue(row['tripCount'] as int? ?? 0),
        DoubleCellValue((row['percentage'] as num? ?? 0).toDouble()),
        TextCellValue(destinationText),
        TextCellValue(purposeText),
      ]);
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  void _appendTextRow(Sheet sheet, List<String> values) {
    sheet.appendRow(
      values.map<CellValue>((value) => TextCellValue(value)).toList(),
    );
  }

  String _formatGeneratedAt(dynamic raw) {
    DateTime date;

    if (raw is Timestamp) {
      date = raw.toDate();
    } else if (raw is DateTime) {
      date = raw;
    } else {
      date = DateTime.now();
    }

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/'
        '${date.year} '
        '${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)}';
  }

  String _createFileName(Map<String, dynamic> report) {
    final String type = report['reportType'] as String? ?? 'analytics';

    final String destination = (report['destinationName'] as String? ?? 'all')
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');

    final String purpose = report['purpose'] as String? ?? 'all';

    return 'TravelGuard_${type}_'
        '${destination}_'
        '$purpose.xlsx';
  }
}

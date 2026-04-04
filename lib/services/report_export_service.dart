import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/domain_models.dart';

class ReportExportService {
  Future<File> exportMonthlyReport({
    required MonthlyReportModel report,
    required String title,
  }) async {
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln('Month,${report.month}')
      ..writeln('From,${report.fromDate}')
      ..writeln('To,${report.toDate}')
      ..writeln('Revenue,${report.revenue}')
      ..writeln('Collected,${report.paymentTotal}')
      ..writeln('Profit,${report.profit}')
      ..writeln('Petrol Sold,${report.petrolSold}')
      ..writeln('Diesel Sold,${report.dieselSold}')
      ..writeln('2T Oil Sold,${report.twoTSold}')
      ..writeln('Entries Completed,${report.entriesCompleted}')
      ..writeln()
      ..writeln('Date,Revenue,Collected,Profit,Petrol Sold,Diesel Sold,2T Oil Sold,Entries');

    for (final point in report.trend) {
      buffer.writeln(
        '${point.date},${point.revenue},${point.paymentTotal},${point.profit},${point.petrolSold},${point.dieselSold},${point.twoTSold},${point.entries}',
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${directory.path}\\$safeTitle.csv');
    await file.writeAsString(buffer.toString(), flush: true);
    return file;
  }

  Future<void> shareFile(File file, {String? text}) async {
    await Share.shareXFiles([XFile(file.path)], text: text);
  }
}

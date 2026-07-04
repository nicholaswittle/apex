// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void downloadCsv(String filename, String content) {
  final blob = html.Blob([content], 'text/csv');
  final url = html.Url.createObjectUrl(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

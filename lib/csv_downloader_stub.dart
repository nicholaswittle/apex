import 'package:share_plus/share_plus.dart';

void downloadCsv(String filename, String content) {
  Share.share(content, subject: filename);
}

import 'package:share_plus/share_plus.dart';

void downloadCsv(String filename, String content) {
  SharePlus.instance.share(ShareParams(text: content, subject: filename));
}

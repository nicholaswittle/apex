import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:apex/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wisense_ui/wisense_ui.dart';
import '../csv_downloader_stub.dart'
    if (dart.library.html) '../csv_downloader_web.dart';

class CsvTimeCardExporter extends StatefulWidget {
  final Map<String, double> staffRates;
  final bool disabled;

  const CsvTimeCardExporter({
    super.key,
    required this.staffRates,
    required this.disabled,
  });

  @override
  State<CsvTimeCardExporter> createState() => _CsvTimeCardExporterState();
}

class _CsvTimeCardExporterState extends State<CsvTimeCardExporter> {
  bool _isExporting = false;
  final _supabase = Supabase.instance.client;

  Future<void> _exportTimeCards() async {
    setState(() => _isExporting = true);
    try {
      final data = await _supabase
          .from('time_entries')
          .select('user_name, clock_in, clock_out')
          .not('clock_out', 'is', null)
          .order('clock_in', ascending: false);
      if (!mounted) return;
      setState(() => _isExporting = false);

      final rows = ((data as List?)?.cast<Map<String, dynamic>>()) ?? [];

      String fmtDt(String iso) {
        final dt = DateTime.parse(iso).toLocal();
        return '"${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}"';
      }

      final buf = StringBuffer('User,Clock In,Clock Out,Hours,Hourly Rate,Total Pay\n');
      for (final r in rows) {
        final name = r['user_name'] as String? ?? '';
        final clockIn = DateTime.parse(r['clock_in'] as String);
        final clockOut = DateTime.parse(r['clock_out'] as String);
        final hours = clockOut.difference(clockIn).inMinutes / 60.0;
        final rate = widget.staffRates[name] ?? 0.0;
        buf.writeln(
          '"$name",'
          '${fmtDt(r["clock_in"] as String)},'
          '${fmtDt(r["clock_out"] as String)},'
          '${hours.toStringAsFixed(2)},'
          '${rate.toStringAsFixed(2)},'
          '${(hours * rate).toStringAsFixed(2)}',
        );
      }

      final csv = buf.toString();
      downloadCsv('time_cards_${DateTime.now().millisecondsSinceEpoch}.csv', csv);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: UniversalTheme.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: UniversalTheme.accent, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.table_chart, color: UniversalTheme.accent),
              SizedBox(width: WiSenseSpacing.sm),
              Text(
                'Time Card Export',
                style: TextStyle(color: UniversalTheme.darkSlate, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320, maxWidth: double.maxFinite),
            child: SingleChildScrollView(
              child: SelectableText(
                csv,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('Copy to Clipboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: UniversalTheme.darkSlate,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: csv));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('CSV copied to clipboard.'),
                    backgroundColor: UniversalTheme.darkSlate,
                  ),
                );
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: UniversalTheme.alertRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: UniversalTheme.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.brown.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(WiSenseSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.table_chart, color: UniversalTheme.accent),
                SizedBox(width: WiSenseSpacing.sm),
                Text(
                  'TIME CARD EXPORT',
                  style: TextStyle(fontWeight: FontWeight.bold, color: UniversalTheme.darkSlate),
                ),
              ],
            ),
            const Divider(height: WiSenseSpacing.lg),
            const Text(
              'Export all completed time entries with hours worked and pay.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: WiSenseSpacing.base),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (widget.disabled || _isExporting) ? null : _exportTimeCards,
                icon: const Icon(Icons.download, size: 16),
                label: const Text(
                  'Export Time Cards',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UniversalTheme.darkSlate,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

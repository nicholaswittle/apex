import 'package:apex/features/smart_suggestions/staff_ranker.dart';
import 'package:apex/features/smart_suggestions/suggestion_engine.dart';
import 'package:apex/theme.dart';
import 'package:flutter/material.dart';
import 'package:wisense_ui/wisense_ui.dart';

class SmartSuggestionsPanel extends StatelessWidget {
  const SmartSuggestionsPanel({
    super.key,
    required this.suggestions,
    required this.isLoading,
    required this.onRefresh,
    required this.onApply,
  });

  final List<ShiftSuggestion> suggestions;
  final bool isLoading;
  final VoidCallback onRefresh;

  /// [staffName] null applies the suggestion with its top-ranked candidate.
  final void Function(ShiftSuggestion suggestion, {String? staffName}) onApply;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: UniversalTheme.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.brown.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: UniversalTheme.accent, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'SMART SUGGESTIONS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: UniversalTheme.darkSlate,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: isLoading ? null : onRefresh,
                  icon: isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 16),
            if (isLoading && suggestions.isEmpty)
              const Text('Analyzing last 4 weeks…', style: TextStyle(color: Colors.grey, fontSize: 12))
            else if (suggestions.isEmpty)
              const Text(
                'No history yet for this day-of-week. Publish a few weeks first.',
                style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
              )
            else
              ...suggestions.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Seen ${s.occurrences}× on this weekday'
                                    '${s.zone != null ? ' · ${s.zone}' : ''}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => onApply(s),
                              child: const Text('Apply', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        if (s.candidates.isNotEmpty) ...[
                          const SizedBox(height: WiSenseSpacing.xs),
                          Wrap(
                            spacing: WiSenseSpacing.sm,
                            runSpacing: WiSenseSpacing.xs,
                            children: s.candidates
                                .take(3)
                                .map((c) => _CandidateChip(
                                      candidate: c,
                                      onTap: () => onApply(s, staffName: c.name),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _CandidateChip extends StatelessWidget {
  const _CandidateChip({required this.candidate, required this.onTap});

  final StaffCandidate candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final flagged = candidate.isBookedThatDay;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: flagged ? AvailabilityPalette.vacationBg : AvailabilityPalette.availableBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: flagged
                ? UniversalTheme.accent
                : AvailabilityPalette.availableAccent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              candidate.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: flagged
                    ? UniversalTheme.warningText
                    : AvailabilityPalette.availableText,
              ),
            ),
            Text(
              candidate.reasons.join(' · '),
              style: TextStyle(
                fontSize: 10,
                color: flagged
                    ? UniversalTheme.warningText
                    : AvailabilityPalette.availableText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

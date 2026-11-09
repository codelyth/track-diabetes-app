import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../glucose/presentation/glucose_records_page.dart';
import '../../hba1c/presentation/hba1c_records_page.dart';
import '../../insulin/presentation/insulin_records_page.dart';

enum RecordTab { glucose, insulin, hba1c }

class RecordsPage extends StatelessWidget {
  const RecordsPage({
    super.key,
    required this.userId,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final String userId;
  final RecordTab selectedTab;
  final ValueChanged<RecordTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<RecordTab>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.lavender,
              ),
              segments: const [
                ButtonSegment(value: RecordTab.glucose, label: Text('Şeker')),
                ButtonSegment(value: RecordTab.insulin, label: Text('İnsülin')),
                ButtonSegment(value: RecordTab.hba1c, label: Text('HbA1c')),
              ],
              selected: {selectedTab},
              onSelectionChanged: (selection) {
                onTabChanged(selection.first);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: IndexedStack(
            index: selectedTab.index,
            children: [
              GlucoseRecordsPage(
                key: ValueKey('glucose-$userId'),
                userId: userId,
              ),
              InsulinRecordsPage(
                key: ValueKey('insulin-$userId'),
                userId: userId,
              ),
              Hba1cRecordsPage(key: ValueKey('hba1c-$userId'), userId: userId),
            ],
          ),
        ),
      ],
    );
  }
}

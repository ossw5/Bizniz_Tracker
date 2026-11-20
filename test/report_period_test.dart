import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bizniz_tracker/features/reports/services/report_period.dart';

void main() {
  test(
    'daily and weekly filters use inclusive dates across week boundaries',
    () {
      final daily = ReportPeriodRange.resolve(
        period: ReportPeriod.daily,
        selectedDate: DateTime(2026, 1, 1, 18),
      );
      expect(
        ReportPeriodRange.contains(daily, DateTime(2026, 1, 1, 23, 59)),
        isTrue,
      );
      expect(ReportPeriodRange.contains(daily, DateTime(2026, 1, 2)), isFalse);
      expect(
        ReportPeriodRange.contains(daily, DateTime(2026, 1, 2, 0, 0, 1)),
        isFalse,
      );

      final weekly = ReportPeriodRange.resolve(
        period: ReportPeriod.weekly,
        selectedDate: DateTime(2026, 1, 1),
      );
      expect(weekly.start, DateTime(2025, 12, 29));
      expect(weekly.end, DateTime(2026, 1, 5));
      expect(
        ReportPeriodRange.contains(weekly, DateTime(2026, 1, 4, 23, 59)),
        isTrue,
      );
      expect(ReportPeriodRange.contains(weekly, DateTime(2026, 1, 5)), isFalse);
    },
  );

  test(
    'monthly, yearly, and custom filters include their final calendar day',
    () {
      final monthly = ReportPeriodRange.resolve(
        period: ReportPeriod.monthly,
        selectedDate: DateTime(2025, 12, 31),
      );
      expect(monthly.start, DateTime(2025, 12, 1));
      expect(monthly.end, DateTime(2026, 1, 1));
      expect(
        ReportPeriodRange.contains(monthly, DateTime(2025, 12, 31, 23, 59)),
        isTrue,
      );
      expect(
        ReportPeriodRange.contains(monthly, DateTime(2026, 1, 1)),
        isFalse,
      );

      final yearly = ReportPeriodRange.resolve(
        period: ReportPeriod.yearly,
        selectedDate: DateTime(2026, 6, 15),
      );
      expect(yearly.start, DateTime(2026, 1, 1));
      expect(yearly.end, DateTime(2027, 1, 1));
      expect(
        ReportPeriodRange.contains(yearly, DateTime(2026, 12, 31, 23, 59)),
        isTrue,
      );
      expect(ReportPeriodRange.contains(yearly, DateTime(2027, 1, 1)), isFalse);

      final custom = ReportPeriodRange.resolve(
        period: ReportPeriod.custom,
        selectedDate: DateTime(2026, 11, 1),
        customRange: DateTimeRange(
          start: DateTime(2026, 12, 30),
          end: DateTime(2027, 1, 2),
        ),
      );
      expect(
        ReportPeriodRange.contains(custom, DateTime(2027, 1, 2, 23, 59)),
        isTrue,
      );
      expect(ReportPeriodRange.contains(custom, DateTime(2027, 1, 3)), isFalse);
    },
  );
}

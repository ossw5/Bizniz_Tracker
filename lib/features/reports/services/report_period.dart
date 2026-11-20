import 'package:flutter/material.dart';

enum ReportPeriod { daily, weekly, monthly, yearly, custom }

String reportPeriodLabel(ReportPeriod period) => switch (period) {
  ReportPeriod.daily => 'Daily',
  ReportPeriod.weekly => 'Weekly',
  ReportPeriod.monthly => 'Monthly',
  ReportPeriod.yearly => 'Yearly',
  ReportPeriod.custom => 'Custom Date Range',
};

class ReportPeriodRange {
  static DateTimeRange resolve({
    required ReportPeriod period,
    required DateTime selectedDate,
    DateTimeRange? customRange,
  }) {
    final date = _calendarDate(selectedDate);
    switch (period) {
      case ReportPeriod.daily:
        return DateTimeRange(start: date, end: _nextCalendarDate(date));
      case ReportPeriod.weekly:
        final start = DateTime(
          date.year,
          date.month,
          date.day - date.weekday + 1,
        );
        return DateTimeRange(
          start: start,
          end: DateTime(start.year, start.month, start.day + 7),
        );
      case ReportPeriod.monthly:
        final start = DateTime(date.year, date.month);
        return DateTimeRange(
          start: start,
          end: DateTime(start.year, start.month + 1),
        );
      case ReportPeriod.yearly:
        final start = DateTime(date.year);
        return DateTimeRange(start: start, end: DateTime(start.year + 1));
      case ReportPeriod.custom:
        if (customRange == null) {
          return DateTimeRange(start: date, end: _nextCalendarDate(date));
        }
        final start = _calendarDate(customRange.start);
        final inclusiveEnd = _calendarDate(customRange.end);
        return DateTimeRange(
          start: start,
          end: _nextCalendarDate(inclusiveEnd),
        );
    }
  }

  static bool contains(DateTimeRange range, DateTime date) {
    final calendarDate = _calendarDate(date);
    return !calendarDate.isBefore(_calendarDate(range.start)) &&
        calendarDate.isBefore(_calendarDate(range.end));
  }

  static DateTime _calendarDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _nextCalendarDate(DateTime value) =>
      DateTime(value.year, value.month, value.day + 1);
}

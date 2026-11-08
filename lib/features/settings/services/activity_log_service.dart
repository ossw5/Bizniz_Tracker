import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/activity_record.dart';

class ActivityLogService {
  static const boxName = 'business_activity_log_box';
  static Future<void> _writeQueue = Future<void>.value();
  static int _idSequence = 0;

  const ActivityLogService();

  Future<Box<dynamic>> _openBox() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box<dynamic>(boxName);
    return Hive.openBox<dynamic>(boxName);
  }

  Future<List<ActivityRecord>> loadRecent({int? limit}) async {
    await _writeQueue;
    final box = await _openBox();
    final activities =
        box.values.map((value) => ActivityRecord.fromMap(value as Map)).toList()
          ..sort(
            (first, second) => second.occurredAt.compareTo(first.occurredAt),
          );
    if (limit != null && activities.length > limit) {
      return activities.take(limit).toList(growable: false);
    }
    return activities;
  }

  Future<void> record({
    required String description,
    required String category,
    DateTime? occurredAt,
  }) async {
    final normalizedDescription = description.trim();
    if (normalizedDescription.isEmpty) return;
    final completer = Completer<void>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        final box = await _openBox();
        final id =
            'activity-${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';
        final activity = ActivityRecord(
          id: id,
          description: normalizedDescription,
          category: category,
          occurredAt: occurredAt ?? DateTime.now(),
        );
        await box.put(id, activity.toMap());
        completer.complete();
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'activity history',
            context: ErrorDescription(
              'while recording "$normalizedDescription"',
            ),
          ),
        );
        completer.complete();
      }
    });
    await completer.future;
  }

  void recordInBackground({
    required String description,
    required String category,
    DateTime? occurredAt,
  }) {
    unawaited(
      record(
        description: description,
        category: category,
        occurredAt: occurredAt,
      ),
    );
  }
}

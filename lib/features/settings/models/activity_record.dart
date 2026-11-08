class ActivityRecord {
  final String id;
  final String description;
  final String category;
  final DateTime occurredAt;

  const ActivityRecord({
    required this.id,
    required this.description,
    required this.category,
    required this.occurredAt,
  });

  factory ActivityRecord.fromMap(Map<dynamic, dynamic> map) => ActivityRecord(
    id: map['id'] as String,
    description: map['description'] as String,
    category: map['category'] as String,
    occurredAt: DateTime.parse(map['occurredAt'] as String),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'description': description,
    'category': category,
    'occurredAt': occurredAt.toIso8601String(),
  };
}

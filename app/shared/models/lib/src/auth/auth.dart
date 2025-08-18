abstract interface class User {
  String? get displayName;

  String? get email;

  String? get avatar;

  String get id;

  DateTime? get createdAt;

  factory User({
    String? displayName,
    String? email,
    String? avatar,
    required String id,
    DateTime? createdAt,
    DateTime? scheduledForDeletionAt,
  }) {
    return _User(displayName: displayName, email: email, avatar: avatar, id: id, createdAt: createdAt);
  }
}

class _User implements User {
  @override
  final String? displayName;
  @override
  final String? email;
  @override
  final String? avatar;
  @override
  final String id;
  @override
  final DateTime? createdAt;

  const _User({
    required this.displayName,
    required this.email,
    required this.avatar,
    required this.id,
    required this.createdAt,
  });

  @override
  String toString() {
    return displayName ?? email ?? 'User #$id';
  }
}

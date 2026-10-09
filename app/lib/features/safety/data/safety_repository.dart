import '../../../core/api/api_client.dart';

class BlockedUser {
  const BlockedUser(this.uid, this.displayName);
  final String uid;
  final String displayName;
}

abstract class SafetyRepository {
  Future<void> report({
    required String targetType, // message | user | activity
    required String targetId,
    required String reason,
    String details = '',
    Map<String, dynamic>? context,
  });
  Future<void> block(String uid);
  Future<void> unblock(String uid);
  Future<List<BlockedUser>> blocks();
}

class ApiSafetyRepository implements SafetyRepository {
  ApiSafetyRepository(this._api);
  final ApiClient _api;

  @override
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
    Map<String, dynamic>? context,
  }) async {
    await _api.post(
      '/reports',
      body: {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        if (details.isNotEmpty) 'details': details,
        'context': ?context,
      },
    );
  }

  @override
  Future<void> block(String uid) async {
    await _api.post('/users/$uid/block');
  }

  @override
  Future<void> unblock(String uid) async {
    await _api.delete('/users/$uid/block');
  }

  @override
  Future<List<BlockedUser>> blocks() async =>
      (await _api.get('/users/me/blocks')).asList
          .map(
            (j) => BlockedUser(
              (j['uid'] ?? j['targetUid'] ?? j['id']) as String,
              j['displayName'] as String? ??
                  j['targetDisplayName'] as String? ??
                  'Member',
            ),
          )
          .toList();
}

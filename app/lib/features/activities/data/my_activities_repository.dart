import '../../../core/api/api_client.dart';
import '../models/activity.dart';

enum MyActivitiesRole { hosted, joined, past }

class ParticipantPreview {
  const ParticipantPreview({
    required this.uid,
    required this.displayName,
    this.photoUrl,
  });
  final String uid;
  final String displayName;
  final String? photoUrl;
}

class ActivityLastMessage {
  const ActivityLastMessage({
    required this.text,
    required this.senderName,
    required this.senderId,
    this.createdAt,
  });
  final String text;
  final String senderName;
  final String senderId;
  final DateTime? createdAt;
}

/// One row of `GET /users/me/activities`.
class MyActivity {
  const MyActivity({
    required this.activity,
    this.lastMessage,
    this.participants = const [],
  });
  final Activity activity;
  final ActivityLastMessage? lastMessage;

  /// Up to 3 approved members (avatar preview, not the full roster).
  final List<ParticipantPreview> participants;

  factory MyActivity.fromJson(Map<String, dynamic> j) {
    final lm = (j['lastMessage'] as Map?)?.cast<String, dynamic>();
    return MyActivity(
      activity: Activity.fromJson(j),
      lastMessage: lm == null
          ? null
          : ActivityLastMessage(
              text: lm['text'] as String? ?? '',
              senderName: lm['senderName'] as String? ?? '',
              senderId: lm['senderId'] as String? ?? '',
              createdAt: DateTime.tryParse(
                lm['createdAt'] as String? ?? '',
              )?.toLocal(),
            ),
      participants: [
        for (final p in (j['participants'] as List? ?? const []))
          ParticipantPreview(
            uid: (p as Map)['uid'] as String,
            displayName: p['displayName'] as String? ?? 'Member',
            photoUrl: p['photoUrl'] as String?,
          ),
      ],
    );
  }
}

class MyActivitiesPage {
  const MyActivitiesPage(this.items, this.nextCursor);
  final List<MyActivity> items;
  final String? nextCursor;
}

/// Activities the signed-in user hosts / joined / attended. Used by Chats and Profile.
abstract class MyActivitiesRepository {
  Future<MyActivitiesPage> list(
    MyActivitiesRole role, {
    String? cursor,
    int limit = 20,
  });
}

class ApiMyActivitiesRepository implements MyActivitiesRepository {
  ApiMyActivitiesRepository(this._api);
  final ApiClient _api;

  @override
  Future<MyActivitiesPage> list(
    MyActivitiesRole role, {
    String? cursor,
    int limit = 20,
  }) async {
    final res = await _api.get(
      '/users/me/activities',
      query: {'role': role.name, 'limit': limit, 'cursor': cursor},
    );
    return MyActivitiesPage(
      res.asList.map(MyActivity.fromJson).toList(),
      res.nextCursor,
    );
  }
}

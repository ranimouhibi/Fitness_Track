import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';

class CommunityPost {
  final int id;
  final int authorId;
  final String authorName;
  final String authorRole;
  final String body;
  final String createdAt;
  final int likes;
  final int comments;
  final bool likedByMe;

  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.body,
    required this.createdAt,
    required this.likes,
    required this.comments,
    required this.likedByMe,
  });
}

class CommunityComment {
  final int id;
  final String authorName;
  final String body;
  final String createdAt;

  const CommunityComment({
    required this.id,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });
}

class CommunityRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<CommunityPost>> postsFor(int userId) async {
    final rows = await (await _db).rawQuery('''
      SELECT p.id, p.author_id, p.body, p.created_at,
             u.first_name || ' ' || u.last_name AS author_name,
             u.role AS author_role,
             (SELECT COUNT(*) FROM post_likes l WHERE l.post_id = p.id) AS likes,
             (SELECT COUNT(*) FROM post_comments c WHERE c.post_id = p.id) AS comments,
             EXISTS(
               SELECT 1 FROM post_likes mine
               WHERE mine.post_id = p.id AND mine.user_id = ?
             ) AS liked_by_me
      FROM posts p
      INNER JOIN users u ON u.id = p.author_id
      ORDER BY p.created_at DESC, p.id DESC
    ''', [userId]);
    return [
      for (final row in rows)
        CommunityPost(
          id: row['id'] as int,
          authorId: row['author_id'] as int,
          authorName: row['author_name'] as String,
          authorRole: row['author_role'] as String,
          body: row['body'] as String,
          createdAt: row['created_at'] as String,
          likes: row['likes'] as int,
          comments: row['comments'] as int,
          likedByMe: (row['liked_by_me'] as int) == 1,
        ),
    ];
  }

  Future<List<CommunityComment>> commentsFor(int postId) async {
    final rows = await (await _db).rawQuery('''
      SELECT c.id, c.body, c.created_at,
             u.first_name || ' ' || u.last_name AS author_name
      FROM post_comments c
      INNER JOIN users u ON u.id = c.author_id
      WHERE c.post_id = ?
      ORDER BY c.created_at ASC, c.id ASC
    ''', [postId]);
    return [
      for (final row in rows)
        CommunityComment(
          id: row['id'] as int,
          authorName: row['author_name'] as String,
          body: row['body'] as String,
          createdAt: row['created_at'] as String,
        ),
    ];
  }

  Future<void> createPost({required int authorId, required String body}) async {
    final value = body.trim();
    if (value.isEmpty) return;
    await (await _db).insert('posts', {'author_id': authorId, 'body': value});
  }

  Future<bool> updatePost({
    required int postId,
    required int authorId,
    required String body,
  }) async {
    final value = body.trim();
    if (value.isEmpty) return false;
    final changed = await (await _db).update(
      'posts',
      {'body': value, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND author_id = ?',
      whereArgs: [postId, authorId],
    );
    return changed == 1;
  }

  Future<bool> deletePost({required int postId, required int authorId}) async {
    final deleted = await (await _db).delete(
      'posts',
      where: 'id = ? AND author_id = ?',
      whereArgs: [postId, authorId],
    );
    return deleted == 1;
  }

  Future<bool> toggleLike({required int postId, required int userId}) async {
    final db = await _db;
    final existing = await db.query(
      'post_likes',
      where: 'post_id = ? AND user_id = ?',
      whereArgs: [postId, userId],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('post_likes', {'post_id': postId, 'user_id': userId});
      return true;
    }
    await db.delete(
      'post_likes',
      where: 'post_id = ? AND user_id = ?',
      whereArgs: [postId, userId],
    );
    return false;
  }

  Future<void> addComment({
    required int postId,
    required int authorId,
    required String body,
  }) async {
    final value = body.trim();
    if (value.isEmpty) return;
    await (await _db).insert('post_comments', {
      'post_id': postId,
      'author_id': authorId,
      'body': value,
    });
  }
}
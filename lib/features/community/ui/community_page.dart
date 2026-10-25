import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/community_repository.dart';

class CommunityPage extends ConsumerStatefulWidget {
  const CommunityPage({super.key});

  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage> {
  final _repo = CommunityRepository();
  List<CommunityPost> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    setState(() => _loading = true);
    final posts = await _repo.postsFor(user.id);
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _loading = false;
    });
  }

  Future<void> _compose([CommunityPost? post]) async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    final body = await showDialog<String>(
      context: context,
      builder: (_) => _PostEditor(initialBody: post?.body),
    );
    if (body == null || body.trim().isEmpty) return;
    if (post == null) {
      await _repo.createPost(authorId: user.id, body: body);
    } else {
      await _repo.updatePost(postId: post.id, authorId: user.id, body: body);
    }
    await _load();
  }

  Future<void> _delete(CommunityPost post) async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo.deletePost(postId: post.id, authorId: user.id);
    await _load();
  }

  Future<void> _toggleLike(CommunityPost post) async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    await _repo.toggleLike(postId: post.id, userId: user.id);
    await _load();
  }

  Future<void> _showComments(CommunityPost post) async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(post: post, repo: _repo, userId: user.id),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Community', style: TextStyle(color: AppColors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Share progress, advice, and motivation', style: TextStyle(color: AppColors.white)),
                  ]),
                ),
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.white,
                  child: Text(
                    user == null ? '?' : '${user.firstName[0]}${user.lastName[0]}'.toUpperCase(),
                    style: const TextStyle(color: AppColors.deepBlue, fontWeight: FontWeight.bold),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              InkWell(
                onTap: () => _compose(),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.white.withValues(alpha: .28)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.edit_outlined, color: AppColors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(child: Text('What would you like to share?', style: TextStyle(color: AppColors.white))),
                    Icon(Icons.arrow_forward_ios, color: AppColors.white, size: 15),
                  ]),
                ),
              ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _posts.isEmpty
                        ? ListView(children: const [
                            SizedBox(height: 220),
                            Center(child: Text('No posts yet. Be the first to share.', style: TextStyle(color: AppColors.textSecondary))),
                          ])
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _posts.length,
                            itemBuilder: (_, index) {
                              final post = _posts[index];
                              return _PostCard(
                                post: post,
                                isOwner: ref.read(sessionProvider)?.id == post.authorId,
                                onLike: () => _toggleLike(post),
                                onComments: () => _showComments(post),
                                onEdit: () => _compose(post),
                                onDelete: () => _delete(post),
                              );
                            },
                          ),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  final bool isOwner;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PostCard({
    required this.post,
    required this.isOwner,
    required this.onLike,
    required this.onComments,
    required this.onEdit,
    required this.onDelete,
  });

  String get _role => post.authorRole[0].toUpperCase() + post.authorRole.substring(1);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: AppColors.softBlue,
              child: Text(post.authorName.isEmpty ? '?' : post.authorName[0].toUpperCase(), style: const TextStyle(color: AppColors.deepBlue, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 3),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.softBlue, borderRadius: BorderRadius.circular(20)),
                  child: Text(_role, style: const TextStyle(fontSize: 11, color: AppColors.deepBlue, fontWeight: FontWeight.w600)),
                ),
              ),
            ])),
            if (isOwner)
              PopupMenuButton<String>(
                onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ]),
          const SizedBox(height: 14),
          Text(post.body, style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          Row(children: [
            _PostAction(
              onPressed: onLike,
              icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
              label: '${post.likes}',
              active: post.likedByMe,
            ),
            const SizedBox(width: 8),
            _PostAction(
              onPressed: onComments,
              icon: Icons.chat_bubble_outline,
              label: '${post.comments}',
            ),
          ]),
        ]),
      ),
    );
  }
}

class _PostEditor extends StatefulWidget {
  final String? initialBody;
  const _PostEditor({this.initialBody});

  @override
  State<_PostEditor> createState() => _PostEditorState();
}

class _PostEditorState extends State<_PostEditor> {
  late final TextEditingController _body;

  @override
  void initState() {
    super.initState();
    _body = TextEditingController(text: widget.initialBody);
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initialBody == null ? 'Create post' : 'Edit post'),
        content: TextField(
          controller: _body,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          maxLength: 1000,
          decoration: const InputDecoration(hintText: 'Share something with the community...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, _body.text), child: const Text('Save')),
        ],
      );
}

class _CommentsSheet extends StatefulWidget {
  final CommunityPost post;
  final CommunityRepository repo;
  final int userId;

  const _CommentsSheet({required this.post, required this.repo, required this.userId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _comment = TextEditingController();
  List<CommunityComment> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final comments = await widget.repo.commentsFor(widget.post.id);
    if (!mounted) return;
    setState(() {
      _comments = comments;
      _loading = false;
    });
  }

  Future<void> _add() async {
    if (_comment.text.trim().isEmpty) return;
    await widget.repo.addComment(postId: widget.post.id, authorId: widget.userId, body: _comment.text);
    _comment.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Comments', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_comments.isEmpty)
            const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('No comments yet.', style: TextStyle(color: AppColors.textSecondary)))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _comments.length,
                itemBuilder: (_, index) {
                  final comment = _comments[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RichText(text: TextSpan(style: const TextStyle(color: AppColors.textPrimary), children: [
                      TextSpan(text: '${comment.authorName}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: comment.body),
                    ])),
                  );
                },
              ),
            ),
          Row(children: [
            Expanded(child: TextField(controller: _comment, maxLength: 300, decoration: const InputDecoration(hintText: 'Write a comment...', counterText: ''))),
            IconButton(onPressed: _add, icon: const Icon(Icons.send, color: AppColors.primary), tooltip: 'Send comment'),
          ]),
        ]),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool active;

  const _PostAction({required this.onPressed, required this.icon, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) => Material(
        color: active ? AppColors.softBlue : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: active ? Colors.red : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}
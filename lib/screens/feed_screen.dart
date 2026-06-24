// lib/screens/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _feedItems = [];
  bool _isLoadingFeed = true;

  @override
  void initState() {
    super.initState();
    _fetchSocialActivityFeed();
    syncFeedNotifier.addListener(_fetchSocialActivityFeed);
  }

  @override
  void dispose() {
    syncFeedNotifier.removeListener(_fetchSocialActivityFeed);
    super.dispose();
  }

  Future<void> _fetchSocialActivityFeed() async {
    if (!mounted) return;
    setState(() => _isLoadingFeed = true);
    
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final followingResponse = await _supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId);

      final List<String> followedIds = List<String>.from(
        followingResponse.map((f) => f['following_id'].toString()),
      );

      if (!followedIds.contains(currentUserId)) {
        followedIds.add(currentUserId);
      }

      final feedResponse = await _supabase
          .from('study_sessions')
          .select('*, profiles:user_id(username), session_likes(user_id), session_comments(*, profiles:user_id(username))')
          .or(followedIds.map((id) => 'user_id.eq.$id').join(','))
          .order('created_at', ascending: false)
          .limit(25);

      if (mounted) {
        setState(() {
          _feedItems = feedResponse;
          _isLoadingFeed = false;
        });
      }
    } catch (e) {
      print('Feed core engine error: $e');
      if (mounted) setState(() => _isLoadingFeed = false);
    }
  }

  Future<void> _toggleLike(String sessionId, bool alreadyLiked) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      if (alreadyLiked) {
        await _supabase.from('session_likes').delete().eq('session_id', sessionId).eq('user_id', currentUserId);
      } else {
        await _supabase.from('session_likes').insert({'session_id': sessionId, 'user_id': currentUserId});
      }
      _fetchSocialActivityFeed();
    } catch (e) {
      print('Like toggling error: $e');
    }
  }

  void _showCommentsModal(String sessionId, List<dynamic> comments) {
    final textController = TextEditingController();
    final currentUserId = _supabase.auth.currentUser?.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                child: comments.isEmpty
                    ? const Center(child: Text('No comments yet.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final c = comments[index] as Map<String, dynamic>;
                          final author = c['profiles']?['username'] ?? 'User';
                          return ListTile(
                            dense: true,
                            title: Text(author, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(c['comment_text'] ?? ''),
                          );
                        },
                      ),
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      decoration: InputDecoration(
                        hintText: "Add a comment...",
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: InputBorder.none, 
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xff5732a3)),
                    onPressed: () async {
                      if (textController.text.trim().isEmpty || currentUserId == null) return;
                      await _supabase.from('session_comments').insert({
                        'session_id': sessionId,
                        'user_id': currentUserId,
                        'comment_text': textController.text.trim(),
                      });
                      Navigator.pop(context);
                      _fetchSocialActivityFeed();
                    },
                  )
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showFindFriendsModal() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    String searchQuery = ""; 
    List<dynamic> searchedProfiles = [];
    Set<String> followingIds = {};
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> performSearch(String query) async {
              if (currentUserId == null || query.trim().isEmpty) return;
              setModalState(() => isSearching = true);
              try {
                final List<dynamic> results = await _supabase.rpc(
                  'search_users_v1',
                  params: {'search_text': query.trim(), 'current_user_id': currentUserId},
                );
                final followingList = await _supabase.from('follows').select('following_id').eq('follower_id', currentUserId);
                followingIds = followingList.map((f) => f['following_id'].toString()).toSet();
                setModalState(() => searchedProfiles = results);
              } catch (e) {
                print("Remote execution RPC error: $e");
              } finally {
                setModalState(() => isSearching = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Find Friends', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) { searchQuery = v; performSearch(searchQuery); },
                    decoration: InputDecoration(
                      hintText: "Search by username...",
                      prefixIcon: const Icon(Icons.search, color: Color(0xff5732a3)),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: InputBorder.none, 
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isSearching) const CircularProgressIndicator()
                  else ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchedProfiles.length,
                      itemBuilder: (context, index) {
                        final profile = searchedProfiles[index];
                        final pId = profile['id'];
                        final isFollowing = followingIds.contains(pId);
                        return ListTile(
                          title: Text(profile['username'] ?? 'User'),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              if (isFollowing) {
                                await _supabase.from('follows').delete().eq('follower_id', currentUserId!).eq('following_id', pId);
                                setModalState(() => followingIds.remove(pId));
                              } else {
                                await _supabase.from('follows').insert({'follower_id': currentUserId!, 'following_id': pId});
                                setModalState(() => followingIds.add(pId));
                              }
                              _fetchSocialActivityFeed();
                            },
                            child: Text(isFollowing ? 'Unfollow' : 'Follow'),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- TIME AND DATE FORMATTERS ---
  String _getExactDate(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}';
    } catch (e) {
      return '';
    }
  }

  String _getTimeAgo(String? timestamp) {
    if (timestamp == null) return 'Recently';
    try {
      final date = DateTime.parse(timestamp).toLocal();
      final diff = DateTime.now().difference(date);
      
      if (diff.inDays > 7) return '${date.year}';
      if (diff.inDays > 1) return '${diff.inDays} days ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inHours > 0) return '${diff.inHours} ${diff.inHours == 1 ? 'hr' : 'hrs'} ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'min' : 'mins'} ago';
      return 'Just now';
    } catch (e) {
      return 'Recently';
    }
  }

  // --- DYNAMIC COLOR GENERATOR FOR TAGS ---
  Color _getColorForModule(String moduleName) {
    final colors = [
      const Color(0xff5732a3), // Primary Purple
      Colors.blueAccent, 
      Colors.teal,
      Colors.orange, 
      Colors.pinkAccent, 
      Colors.redAccent,
      Colors.indigo, 
      const Color(0xff2d4059)
    ];
    // Uses the string's hashcode to always pick the same color for the same module code
    int hash = moduleName.hashCode;
    return colors[hash.abs() % colors.length];
  }

  // --- UI HELPERS FOR THE CARD ---
  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xfff8f9fa),
      appBar: AppBar(
        title: const Text('Activity Feed', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xff5732a3), 
        actions: [IconButton(icon: const Icon(Icons.person_add_alt_1, color: Colors.white), onPressed: _showFindFriendsModal)],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchSocialActivityFeed,
        child: _isLoadingFeed
            ? const Center(child: CircularProgressIndicator(color: Color(0xff5732a3)))
            : _feedItems.isEmpty
                ? const Center(child: Text('Feed is quiet. Follow friends to see their data!', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _feedItems.length,
                    itemBuilder: (context, index) {
                      
                      final item = _feedItems[index] as Map<String, dynamic>;
                      final username = item['profiles']?['username'] ?? 'Scholar';
                      final List<dynamic> likes = item['session_likes'] ?? [];
                      final List<dynamic> comments = item['session_comments'] ?? [];
                      final isLiked = likes.any((l) => l['user_id'] == currentUserId);

                      final subjectFull = item['subject']?.toString() ?? 'Unknown';
                      final durationMins = item['duration_minutes']?.toString() ?? '0';
                      final location = item['location']?.toString() ?? 'Campus';
                      final xp = item['xp_earned']?.toString() ?? '0';
                      
                      // STRING PARSING: Splits "Tutorial 1 (BT1101)" into task and tag
                      String taskName = subjectFull;
                      String moduleName = '';
                      if (subjectFull.contains('(') && subjectFull.endsWith(')')) {
                        int openParen = subjectFull.lastIndexOf('(');
                        taskName = subjectFull.substring(0, openParen).trim();
                        moduleName = subjectFull.substring(openParen + 1, subjectFull.length - 1).trim();
                      }
                      
                      // DATE FORMATTING
                      final exactDate = _getExactDate(item['created_at']?.toString());
                      final timeAgo = _getTimeAgo(item['created_at']?.toString());
                      final dateDisplay = exactDate.isNotEmpty ? '$exactDate • $timeAgo' : timeAgo;

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 16),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              
                              // 1. Header: Avatar, Username, and Explicit Date
                              Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Color(0xff3f6b8e),
                                    child: Icon(Icons.person, color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                                      Text(dateDisplay, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 2. Main Title & Dynamic Colored Tag
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$taskName Session',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                                    ),
                                  ),
                                  if (moduleName.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getColorForModule(moduleName).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: _getColorForModule(moduleName), width: 1),
                                      ),
                                      child: Text(
                                        moduleName,
                                        style: TextStyle(
                                          color: _getColorForModule(moduleName), 
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 12
                                        ),
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 3. Location Circle
                              Center(
                                child: Container(
                                  height: 80,
                                  width: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xff5732a3), width: 2),
                                  ),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        location,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Color(0xff5732a3), fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Divider(),

                              // 4. Stats Row (Now only shows the Task Name without the bracketed module)
                              Row(
                                children: [
                                  Expanded(child: _buildStatColumn('Duration', '${durationMins}min')),
                                  Container(height: 40, width: 1, color: Colors.grey[300]),
                                  Expanded(child: _buildStatColumn('Subject', taskName)),
                                ],
                              ),
                              const Divider(),

                              // 5. XP Row
                              Row(
                                children: [
                                  Expanded(child: _buildStatColumn('XP Earned', '+$xp XP')),
                                ],
                              ),
                              const Divider(),

                              // 6. Social Buttons
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey), 
                                    onPressed: () => _toggleLike(item['id'].toString(), isLiked),
                                  ),
                                  Text('${likes.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                                  const SizedBox(width: 24),
                                  IconButton(
                                    icon: const Icon(Icons.comment_outlined, color: Colors.grey), 
                                    onPressed: () => _showCommentsModal(item['id'].toString(), comments),
                                  ),
                                  Text('${comments.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
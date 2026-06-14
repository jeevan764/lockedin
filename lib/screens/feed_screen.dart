// lib/screens/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  }

  // Fetches recent sessions logged by users the current user follows
  Future<void> _fetchSocialActivityFeed() async {
    setState(() => _isLoadingFeed = true);
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // 1. Get the list of user IDs that the current user follows
      final followingResponse = await _supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId);

      final List<String> followedIds = List<String>.from(
        followingResponse.map((f) => f['following_id'].toString()),
      );

      // Include current user's own activity in the feed overview
      followedIds.add(currentUserId);

      if (followedIds.isEmpty) {
        setState(() {
          _feedItems = [];
          _isLoadingFeed = false;
        });
        return;
      }

      // 2. Fetch recent study sessions belonging to followed IDs
      // Relational join pulls the creator's username profile data directly
      final feedResponse = await _supabase
          .from('study_sessions')
          .select('*, profiles:user_id(username), session_likes(user_id), session_comments(*, profiles:user_id(username))')
          .inFilter('user_id', followedIds)
          .order('created_at', ascending: false)
          .limit(20);

      setState(() {
        _feedItems = feedResponse;
        _isLoadingFeed = false;
      });
    } catch (e) {
      print('Error parsing social feed items: $e');
      setState(() => _isLoadingFeed = false);
    }
  }

  // Toggles entry presence inside the session_likes interaction table
  Future<void> _toggleLike(String sessionId, bool alreadyLiked) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      if (alreadyLiked) {
        await _supabase
            .from('session_likes')
            .delete()
            .eq('session_id', sessionId)
            .eq('user_id', currentUserId);
      } else {
        await _supabase
            .from('session_likes')
            .insert({'session_id': sessionId, 'user_id': currentUserId});
      }
      // Re-fetch quietly to update counters visually
      _fetchSocialActivityFeed();
    } catch (e) {
      print('Like system error: $e');
    }
  }

  // Displays contextual comments drawer sheet overlay
  void _showCommentsModal(String sessionId, List<dynamic> comments) {
    final textController = TextEditingController();
    final currentUserId = _supabase.auth.currentUser?.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16, right: 16, top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                    child: comments.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No comments yet.', style: TextStyle(color: Colors.grey))))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final c = comments[index];
                              final author = c['profiles']?['username'] ?? 'User';
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Color(0xff5732a3)),
                        onPressed: () async {
                          if (textController.text.trim().isEmpty || currentUserId == null) return;
                          try {
                            final newCommentText = textController.text.trim();
                            await _supabase.from('session_comments').insert({
                              'session_id': sessionId,
                              'user_id': currentUserId,
                              'comment_text': newCommentText,
                            });
                            textController.clear();
                            Navigator.pop(context); // Dismiss sheet
                            _fetchSocialActivityFeed(); // Update primary stream view
                          } catch (e) {
                            print("Comment submittal failed: $e");
                          }
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
      },
    );
  }

  // Displays a list of profiles with an optimized real-time server search filter
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

            // Performs an efficient server-side query instead of reading the entire database local-side
            Future<void> performSearch(String query) async {
              if (currentUserId == null) return;
              
              setModalState(() => isSearching = true);
              try {
                // Fetch the list of users already followed if cache mapping is empty
                if (followingIds.isEmpty) {
                  final followingList = await _supabase
                      .from('follows')
                      .select('following_id')
                      .eq('follower_id', currentUserId);
                  followingIds = followingList.map((f) => f['following_id'].toString()).toSet();
                }

                if (query.isNotEmpty) {
                  // Request database-driven string filtration checks using ILIKE matching
                  final results = await _supabase
                      .from('profiles')
                      .select('id, username')
                      .neq('id', currentUserId) // Filter out current user on the database layer
                      .ilike('username', '%$query%') // SQL matching: LIKE %query%
                      .limit(15); // Hard bounds packet size cutoff to protect throughput speed
                  
                  setModalState(() {
                    searchedProfiles = results;
                  });
                } else {
                  setModalState(() {
                    searchedProfiles = [];
                  });
                }
              } catch (e) {
                print("Search system error: $e");
              } finally {
                setModalState(() => isSearching = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, 
                left: 16, right: 16, top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Find Friends', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  
                  // SEARCH INPUT FIELD
                  TextField(
                    onChanged: (value) {
                      searchQuery = value.trim();
                      performSearch(searchQuery);
                    },
                    decoration: InputDecoration(
                      hintText: "Search by username...",
                      prefixIcon: const Icon(Icons.search, color: Color(0xff5732a3)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // INTERACTION RESULT STATES
                  if (isSearching)
                    const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(color: Color(0xff5732a3))))
                  else if (searchedProfiles.isEmpty)
                    SizedBox(
                      height: 150,
                      child: Center(
                        child: Text(
                          searchQuery.isEmpty ? 'Type a username to search' : 'No users found', 
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchedProfiles.length,
                        itemBuilder: (context, index) {
                          final profile = searchedProfiles[index];
                          final pId = profile['id'];
                          final pName = profile['username'] ?? 'User';
                          final isFollowing = followingIds.contains(pId);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xff5732a3).withOpacity(0.1),
                              child: Text(pName.toString().substring(0,1).toUpperCase(), style: const TextStyle(color: Color(0xff5732a3), fontWeight: FontWeight.bold)),
                            ),
                            title: Text(pName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing ? Colors.grey[200] : const Color(0xff5732a3),
                                foregroundColor: isFollowing ? Colors.black87 : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () async {
                                try {
                                  if (isFollowing) {
                                    await _supabase.from('follows').delete().eq('follower_id', currentUserId!).eq('following_id', pId);
                                    setModalState(() => followingIds.remove(pId));
                                  } else {
                                    await _supabase.from('follows').insert({'follower_id': currentUserId!, 'following_id': pId});
                                    setModalState(() => followingIds.add(pId));
                                  }
                                  _fetchSocialActivityFeed(); 
                                } catch (e) {
                                  print("Follow exception: $e");
                                }
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = _supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xfff8f9fa),
      appBar: AppBar(
        title: const Text('Activity Feed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xff5732a3)),
            onPressed: _showFindFriendsModal,
          )
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xff5732a3),
        onRefresh: _fetchSocialActivityFeed,
        child: _isLoadingFeed
            ? const Center(child: CircularProgressIndicator(color: Color(0xff5732a3)))
            : _feedItems.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(40),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Your feed is quiet.\nFollow friends to view their activity metrics!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, height: 1.4),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _feedItems.length,
                    itemBuilder: (context, index) {
                      final item = _feedItems[index];
                      final username = item['profiles']?['username'] ?? 'A Scholar';
                      final subject = item['subject'] ?? 'Studying';
                      final mins = item['duration_minutes'] ?? 0;
                      
                      // Pull nested list items safely from metadata payloads
                      final List<dynamic> likesList = item['session_likes'] ?? [];
                      final List<dynamic> commentsList = item['session_comments'] ?? [];
                      final bool isLikedByMe = likesList.any((l) => l['user_id'] == currentUserId);

                      // Date styling computation
                      String timeLabel = "Recently";
                      if (item['created_at'] != null) {
                        final diff = DateTime.now().difference(DateTime.parse(item['created_at']));
                        if (diff.inDays > 0) timeLabel = "${diff.inDays}d ago";
                        else if (diff.inHours > 0) timeLabel = "${diff.inHours}h ago";
                        else if (diff.inMinutes > 0) timeLabel = "${diff.inMinutes}m ago";
                        else timeLabel = "Just now";
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.black12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xff5732a3).withOpacity(0.08),
                                    radius: 18,
                                    child: Text(username.toString().substring(0,1).toUpperCase(), style: const TextStyle(color: Color(0xff5732a3), fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  ),
                                  Text(timeLabel, style: const TextStyle(color: Colors.black38, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Focused on $subject for $mins minutes!",
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  // LIKE ACTION BUTTON
                                  InkWell(
                                    onTap: () => _toggleLike(item['id'].toString(), isLikedByMe),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isLikedByMe ? Icons.favorite : Icons.favorite_border,
                                          size: 20,
                                          color: isLikedByMe ? Colors.red : Colors.black54,
                                        ),
                                        const SizedBox(width: 4),
                                        Text('${likesList.length}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  // COMMENT ACTION BUTTON
                                  InkWell(
                                    onTap: () => _showCommentsModal(item['id'].toString(), commentsList),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.chat_bubble_outline, size: 19, color: Colors.black54),
                                        const SizedBox(width: 4),
                                        Text('${commentsList.length}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                      ],
                                    ),
                                  ),
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
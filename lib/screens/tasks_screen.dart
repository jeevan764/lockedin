// lib/screens/tasks_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart';

class DBTaskModule {
  final dynamic id; 
  final String name;
  final Color color;
  final List<DBTaskItem> tasks;

  DBTaskModule({required this.id, required this.name, required this.color, required this.tasks});

  factory DBTaskModule.fromSupabase(Map<String, dynamic> json) {
    final dynamic parsedId = json['id'];

    String hexColor = json['color_hex']?.toString() ?? '0xff5732a3';
    hexColor = hexColor.replaceAll('#', '').trim();
    
    if (hexColor.startsWith('0x')) {
      hexColor = hexColor.substring(2);
    }
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor'; 
    }

    int colorValue;
    try {
      colorValue = int.parse(hexColor, radix: 16);
    } catch (_) {
      colorValue = 0xff5732a3; 
    }

    List<dynamic> taskList = json['tasks'] ?? [];
    return DBTaskModule(
      id: parsedId,
      name: json['name'] ?? 'General',
      color: Color(colorValue),
      tasks: taskList.map((t) => DBTaskItem.fromSupabase(t)).toList(),
    );
  }
}

class DBTaskItem {
  final dynamic id; 
  final String title;
  final bool isCompleted;

  DBTaskItem({required this.id, required this.title, required this.isCompleted});

  factory DBTaskItem.fromSupabase(Map<String, dynamic> json) {
    return DBTaskItem(
      id: json['id'], 
      title: json['title'] ?? '',
      isCompleted: json['is_completed'] ?? false,
    );
  }
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _supabase = Supabase.instance.client;
  List<DBTaskModule> _modules = [];
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _loadUserWorkspace();
    syncTasksNotifier.addListener(_loadUserWorkspace); 
  }

  @override
  void dispose() {
    syncTasksNotifier.removeListener(_loadUserWorkspace);
    super.dispose();
  }

  Future<void> _loadUserWorkspace() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      final List<dynamic> response = await _supabase
          .from('task_modules')
          .select('*, tasks(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: true);
          
      if (mounted) {
        setState(() {
          _modules = response.map((data) {
            final baseModule = DBTaskModule.fromSupabase(data);
            final activeTasks = baseModule.tasks.where((t) => !t.isCompleted).toList();
            
            return DBTaskModule(
              id: baseModule.id,
              name: baseModule.name,
              color: baseModule.color,
              tasks: activeTasks,
            );
          }).toList();
          
          _isFetching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tasks: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleCreateModule(String name, Color color) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      final String hexString = '0x${color.value.toRadixString(16)}';
      await _supabase.from('task_modules').insert({
        'user_id': user.id,
        'name': name,
        'color_hex': hexString,
      });
      _loadUserWorkspace();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating tag: $e')));
    }
  }

  Future<void> _handleAddTask(DBTaskModule module, String title) async {
    try {
      await _supabase.from('tasks').insert({
        'module_id': module.id,
        'title': title,
        'is_completed': false,
      });
      _loadUserWorkspace();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding task: $e')));
    }
  }

  Future<void> _handleCompleteTask(DBTaskModule module, DBTaskItem task) async {
    try {
      await _supabase.from('tasks').update({'is_completed': true}).eq('id', task.id);
      _loadUserWorkspace();
      syncProfileNotifier.value++; 
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error closing task: $e')));
    }
  }

  Future<void> _handleDeleteModule(DBTaskModule module) async {
    try {
      await _supabase.from('task_modules').delete().eq('id', module.id);
      _loadUserWorkspace();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot delete tag: $e')));
    }
  }

  void _showAddModuleDialog() {
    final TextEditingController controller = TextEditingController();
    Color chosenColor = const Color(0xff5732a3);
    final List<Color> palette = [const Color(0xff5732a3), Colors.blueAccent, Colors.tealAccent, Colors.orangeAccent, Colors.pinkAccent, Colors.redAccent, Colors.indigoAccent, const Color(0xff2d4059)];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xff1e1e24), // FIX: Dark dialog background
          title: const Text('New Category Tag', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller, 
                style: const TextStyle(color: Colors.white), // FIX: White text input
                decoration: InputDecoration(
                  hintText: 'Subject Code (e.g., CS1101S)',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ), 
                autofocus: true
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: palette.map((color) {
                  final bool selected = chosenColor == color;
                  return GestureDetector(
                    onTap: () => setModalState(() => chosenColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: selected ? Border.all(color: Colors.white, width: 2.5) : null),
                    ),
                  );
                }).toList(),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  _handleCreateModule(controller.text.trim(), chosenColor);
                  Navigator.pop(context);
                }
              },
              child: const Text('Create', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog(DBTaskModule module) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1e1e24), // FIX: Dark dialog background
        title: Text('Add task to ${module.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        content: TextField(
          controller: controller, 
          style: const TextStyle(color: Colors.white), // FIX: White text input
          decoration: InputDecoration(
            hintText: 'Task objective...',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ), 
          autofocus: true
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _handleAddTask(module, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add Task', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteModule(DBTaskModule module) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1e1e24), // FIX: Dark dialog background
        title: const Text('Delete Subject?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text('Permanently wipe out "${module.name}" and all tasks inside?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              _handleDeleteModule(module);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // FIX: Transparent Scaffold
      extendBodyBehindAppBar: true,      // FIX: Extend body into AppBar
      appBar: AppBar(
        title: const Text('Workspace Objectives', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent, // FIX: Transparent AppBar
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.create_new_folder, color: Colors.blueAccent), onPressed: _showAddModuleDialog)],
      ),
      body: Container( // FIX: Universal Background Wrapper
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/background.jpeg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.2), 
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: _isFetching
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _modules.isEmpty
                  ? const Center(child: Text('No active subjects. Tap the folder icon to add one!', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _modules.length,
                      itemBuilder: (context, index) {
                        final module = _modules[index];
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          color: Colors.white.withOpacity(0.1), // FIX: Frosted Glass Dark Card
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                              unselectedWidgetColor: Colors.white54,
                            ),
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              iconColor: Colors.white,
                              collapsedIconColor: Colors.white54,
                              leading: CircleAvatar(radius: 6, backgroundColor: module.color),
                              title: Text(module.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white54, size: 20), onPressed: () => _showAddTaskDialog(module)),
                                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () => _confirmDeleteModule(module)),
                                ],
                              ),
                              children: module.tasks.isEmpty
                                  ? [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16.0),
                                        child: Text('No tasks under this tag yet.', style: TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic)),
                                      )
                                    ]
                                  : module.tasks.map((task) {
                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
                                        leading: Checkbox(
                                          activeColor: module.color, 
                                          checkColor: Colors.white,
                                          side: const BorderSide(color: Colors.white54, width: 1.5), // FIX: Visible border in dark mode
                                          value: task.isCompleted, 
                                          onChanged: (_) => _handleCompleteTask(module, task)
                                        ),
                                        title: Text(task.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                                      );
                                    }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
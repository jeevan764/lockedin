// lib/screens/tasks_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart';

class DBTaskModule {
  final dynamic id; // FIX: Changed from int to dynamic to support Supabase UUID strings
  final String name;
  final Color color;
  final List<DBTaskItem> tasks;

  DBTaskModule({required this.id, required this.name, required this.color, required this.tasks});

  factory DBTaskModule.fromSupabase(Map<String, dynamic> json) {
    // FIX: Directly assign the ID instead of trying to parse it as an integer
    final dynamic parsedId = json['id'];

    // Safely extract and normalize hex color format configurations
    String hexColor = json['color_hex']?.toString() ?? '0xff5732a3';
    hexColor = hexColor.replaceAll('#', '').trim();
    
    // Add missing alpha components if the string arrives as a short hex code
    if (hexColor.startsWith('0x')) {
      hexColor = hexColor.substring(2);
    }
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor'; // Prepend full opacity channel
    }

    int colorValue;
    try {
      colorValue = int.parse(hexColor, radix: 16);
    } catch (_) {
      colorValue = 0xff5732a3; // Reliable safety fallback value
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
  final dynamic id; // FIX: Changed from int to dynamic
  final String title;
  final bool isCompleted;

  DBTaskItem({required this.id, required this.title, required this.isCompleted});

  factory DBTaskItem.fromSupabase(Map<String, dynamic> json) {
    return DBTaskItem(
      id: json['id'], // FIX: Directly assign without integer parsing
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
    syncTasksNotifier.addListener(_loadUserWorkspace); // Listens for instant updates from RecordScreen
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
      
      // Removed the crashing .eq('tasks.is_completed', false) from PostgREST query.
      // We pull modules and their tasks normally, keeping empty modules safe from vanishing.
      final List<dynamic> response = await _supabase
          .from('task_modules')
          .select('*, tasks(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: true);
          
      if (mounted) {
        setState(() {
          _modules = response.map((data) {
            final baseModule = DBTaskModule.fromSupabase(data);
            
            // Filter out completed tasks locally in memory instead of crashing the database channel.
            // This allows empty categories to remain completely visible.
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
      
      // Use standard hex string serialization format
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
      syncProfileNotifier.value++; // Adds completion events to Profile metric counters
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
    final List<Color> palette = [const Color(0xff5732a3), Colors.blueAccent, Colors.teal, Colors.orange, Colors.pinkAccent, Colors.redAccent, Colors.indigo, const Color(0xff2d4059)];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('New Category Tag', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, decoration: const InputDecoration(hintText: 'Subject Code (e.g., CS1101S)'), autofocus: true),
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
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: selected ? Border.all(color: Colors.black, width: 2.5) : null),
                    ),
                  );
                }).toList(),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  _handleCreateModule(controller.text.trim(), chosenColor);
                  Navigator.pop(context);
                }
              },
              child: const Text('Create', style: TextStyle(color: Color(0xff5732a3), fontWeight: FontWeight.bold)),
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
        title: Text('Add task to ${module.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Task objective...'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _handleAddTask(module, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add Task', style: TextStyle(color: Color(0xff5732a3), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteModule(DBTaskModule module) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Permanently wipe out "${module.name}" and all tasks inside?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              _handleDeleteModule(module);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8f9fa),
      appBar: AppBar(
        title: const Text('Workspace Objectives', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xff5732a3),
        actions: [IconButton(icon: const Icon(Icons.create_new_folder, color: Colors.white), onPressed: _showAddModuleDialog)],
      ),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator(color: Color(0xff5732a3)))
          : _modules.isEmpty
              ? const Center(child: Text('No active subjects. Tap the folder icon to add one!'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _modules.length,
                  itemBuilder: (context, index) {
                    final module = _modules[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          leading: CircleAvatar(radius: 6, backgroundColor: module.color),
                          title: Text(module.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.black54, size: 20), onPressed: () => _showAddTaskDialog(module)),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () => _confirmDeleteModule(module)),
                            ],
                          ),
                          children: module.tasks.isEmpty
                              ? [
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16.0),
                                    child: Text('No tasks under this tag yet.', style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
                                  )
                                ]
                              : module.tasks.map((task) {
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
                                    leading: Checkbox(activeColor: module.color, value: task.isCompleted, onChanged: (_) => _handleCompleteTask(module, task)),
                                    title: Text(task.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  );
                                }).toList(),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
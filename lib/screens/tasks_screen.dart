// lib/screens/tasks_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Live Database Data Models
class DBTaskModule {
  final String id;
  final String name;
  final Color color;
  List<DBTaskItem> tasks;

  DBTaskModule({required this.id, required this.name, required this.color, required this.tasks});

  // Factory constructor converting database payloads into structured runtime objects
  factory DBTaskModule.fromSupabase(Map<String, dynamic> map) {
    final int colorVal = int.tryParse(map['color_hex'] ?? '0xff5732a3') ?? 0xff5732a3;
    final List<dynamic> rawTasks = map['tasks'] ?? [];
    
    return DBTaskModule(
      id: map['id'],
      name: map['name'],
      color: Color(colorVal),
      tasks: rawTasks.map((t) => DBTaskItem.fromSupabase(t)).toList(),
    );
  }
}

class DBTaskItem {
  final String id;
  final String title;
  bool isCompleted;

  DBTaskItem({required this.id, required this.title, this.isCompleted = false});

  factory DBTaskItem.fromSupabase(Map<String, dynamic> map) {
    return DBTaskItem(
      id: map['id'],
      title: map['title'],
      isCompleted: map['is_completed'] ?? false,
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

  final List<Color> _colorPalette = [
    const Color(0xff5732a3), Colors.blueAccent, Colors.teal, 
    Colors.orangeAccent, Colors.pinkAccent, Colors.redAccent
  ];

  @override
  void initState() {
    super.initState();
    _loadUserWorkspace();
  }

  // Read all modules and inner tasks belonging to the current user
  Future<void> _loadUserWorkspace() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Query fetches modules and filters out completed tasks in a single network pass
      final List<dynamic> response = await _supabase
          .from('task_modules')
          .select('*, tasks(*)')
          .eq('user_id', user.id)
          .eq('tasks.is_completed', false)
          .order('created_at', ascending: true);

      setState(() {
        _modules = response.map((data) => DBTaskModule.fromSupabase(data)).toList();
        _isFetching = false;
      });
    } catch (e) {
      setState(() => _isFetching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load tasks: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // Create a brand new folder tag in Supabase
  Future<void> _handleCreateModule(String name, Color color) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Convert Flutter Color instance back to a database string representation
      final String hexString = '0x${color.value.toRadixString(16)}';

      await _supabase.from('task_modules').insert({
        'user_id': user.id,
        'name': name,
        'color_hex': hexString,
      });

      // Refresh frontend state to display the new module immediately
      _loadUserWorkspace();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating tag: $e')));
    }
  }

  // Append an objective task nested inside a module entry
  Future<void> _handleAddTask(DBTaskModule module, String title) async {
    try {
      await _supabase.from('tasks').insert({
        'module_id': module.id,
        'title': title,
        'is_completed': false,
      });

      _loadUserWorkspace();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding task: $e')));
    }
  }

  // Update a task status to completed and make it disappear
  Future<void> _handleCompleteTask(DBTaskModule module, DBTaskItem task) async {
    setState(() {
      task.isCompleted = true;
    });

    try {
      // Small functional animation pause window for interaction polish
      await Future.delayed(const Duration(milliseconds: 250));

      await _supabase.from('tasks').update({'is_completed': true}).eq('id', task.id);

      setState(() {
        module.tasks.removeWhere((item) => item.id == task.id);
      });
    } catch (e) {
      setState(() {
        task.isCompleted = false; // Roll back on failure
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Database link failed: $e')));
    }
  }

  // Delete an entire subject tag container along with all its structural contents
  Future<void> _handleDeleteModule(String moduleId) async {
    try {
      await _supabase.from('task_modules').delete().eq('id', moduleId);
      setState(() {
        _modules.removeWhere((m) => m.id == moduleId);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deletion failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Workspace Tasks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xff5732a3),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_outlined, color: Colors.white),
            onPressed: _showCreateModuleDialog,
          ),
        ],
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.black),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          leading: CircleAvatar(radius: 6, backgroundColor: module.color),
                          title: Text(module.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.black54, size: 20),
                                onPressed: () => _showAddTaskDialog(module),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () => _confirmDeleteModule(module),
                              ),
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
                                    leading: Checkbox(
                                      activeColor: module.color,
                                      value: task.isCompleted,
                                      onChanged: (_) => _handleCompleteTask(module, task),
                                    ),
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
              _handleDeleteModule(module.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCreateModuleDialog() {
    final TextEditingController controller = TextEditingController();
    Color selectedColor = _colorPalette[0];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('New Subject / Tag', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'e.g., CS2040S, Side Project')),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _colorPalette.map((color) {
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedColor = color),
                    child: CircleAvatar(
                      radius: 14, backgroundColor: color,
                      child: selectedColor == color ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
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
                  _handleCreateModule(controller.text, selectedColor);
                  Navigator.pop(context);
                }
              },
              child: const ColorFiltered(colorFilter: ColorFilter.mode(Colors.transparent, BlendMode.multiply), child: Text('Create', style: TextStyle(color: Color(0xff5732a3), fontWeight: FontWeight.bold))),
            ),
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
                _handleAddTask(module, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add Task', style: TextStyle(color: Color(0xff5732a3), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
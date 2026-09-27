import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/task.dart';

class TaskProvider extends ChangeNotifier {
  TaskProvider({AppDatabase? database})
      : _database = database ?? AppDatabase.instance,
        _tasks = [];

  TaskProvider.inMemory(List<Task> tasks)
      : _database = AppDatabase.instance,
        _tasks = List<Task>.from(tasks),
        _isLoaded = true,
        _isInMemory = true;

  final AppDatabase _database;
  final List<Task> _tasks;
  bool _isLoaded = false;
  bool _isInMemory = false;
  int _nextInMemoryId = -1;

  List<Task> get tasks => List.unmodifiable(_tasks);
  bool get isLoading => !_isLoaded;
  int get completedCount => _tasks.where((task) => task.completed).length;

  Future<void> loadTasks() async {
    if (_isLoaded || _isInMemory) return;

    try {
      _tasks
        ..clear()
        ..addAll(await _database.loadTasks());
      _sortTasks();
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> addTask({required String title, String? note}) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return;

    final task = Task(
      title: trimmedTitle,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      completed: false,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    final savedTask = _isInMemory
        ? task.copyWith(id: _nextInMemoryId--)
        : await _database.insertTask(task);
    _tasks.add(savedTask);
    _sortTasks();
    notifyListeners();
  }

  Future<void> toggleTask(Task task) async {
    final updatedTask = task.copyWith(
      completed: !task.completed,
      completedAt:
          task.completed ? null : DateTime.now().millisecondsSinceEpoch,
      clearCompletedAt: task.completed,
    );
    if (!_isInMemory) await _database.updateTask(updatedTask);
    _replaceTask(updatedTask);
    notifyListeners();
  }

  Future<void> deleteTask(Task task) async {
    if (!_isInMemory) await _database.deleteTask(task);
    _tasks.removeWhere((item) => item.id == task.id);
    notifyListeners();
  }

  void _replaceTask(Task updatedTask) {
    final index = _tasks.indexWhere((task) => task.id == updatedTask.id);
    if (index == -1) return;
    _tasks[index] = updatedTask;
    _sortTasks();
  }

  void _sortTasks() {
    _tasks.sort((a, b) {
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      return b.createdAt.compareTo(a.createdAt);
    });
  }
}

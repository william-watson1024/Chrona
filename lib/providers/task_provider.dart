import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/task.dart';

class TaskProvider extends ChangeNotifier {
  TaskProvider({AppDatabase? database})
      : _database = database ?? AppDatabase.instance,
        _tasks = [];

  TaskProvider.inMemory(List<Task> tasks)
      : _database = AppDatabase.instance,
        _tasks = tasks
            .map((task) => task.planDate == null
                ? task.copyWith(planDate: startOfDay(DateTime.now()))
                : task)
            .toList(),
        _isLoaded = true,
        _isInMemory = true;

  final AppDatabase _database;
  final List<Task> _tasks;
  Future<void>? _loadingTasks;
  bool _isLoaded = false;
  bool _isInMemory = false;
  int _nextInMemoryId = -1;

  List<Task> get tasks => List.unmodifiable(_tasks);
  bool get isLoading => !_isLoaded;
  int get completedCount => _tasks.where((task) => task.completed).length;

  List<Task> tasksForDate(DateTime date) {
    final day = startOfDay(date);
    final result =
        _tasks.where((task) => task.effectivePlanDate == day).toList();
    result.sort(_compareTasks);
    return List.unmodifiable(result);
  }

  int completedCountForDate(DateTime date) {
    return tasksForDate(date).where((task) => task.completed).length;
  }

  Future<void> loadTasks() {
    if (_isLoaded || _isInMemory) return Future<void>.value();
    final loading = _loadingTasks;
    if (loading != null) return loading;

    final future = _loadTasks();
    _loadingTasks = future;
    return future.whenComplete(() {
      if (identical(_loadingTasks, future)) _loadingTasks = null;
    });
  }

  Future<void> _loadTasks() async {
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

  Future<void> addTask({
    required String title,
    String? note,
    int durationSeconds = 15 * 60,
    DateTime? planDate,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return;

    final normalizedPlanDate = startOfDay(planDate ?? DateTime.now());
    final existingTasks = tasksForDate(normalizedPlanDate).toList();
    final shiftedTasks = [
      for (var index = 0; index < existingTasks.length; index++)
        existingTasks[index].copyWith(sortOrder: index + 1),
    ];
    if (!_isInMemory) await _database.updateTaskOrders(shiftedTasks);
    for (final task in shiftedTasks) {
      final index = _tasks.indexWhere((item) => item.id == task.id);
      if (index >= 0) _tasks[index] = task;
    }

    final task = Task(
      title: trimmedTitle,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      completed: false,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      durationSeconds: durationSeconds,
      planDate: normalizedPlanDate,
      sortOrder: 0,
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

  Future<void> updateTask(Task updatedTask) async {
    if (!_isInMemory) await _database.updateTask(updatedTask);
    _replaceTask(updatedTask);
    notifyListeners();
  }

  Future<void> reorderTasksForDate(
    DateTime date,
    int oldIndex,
    int newIndex,
  ) async {
    final ordered = tasksForDate(date).toList();
    if (oldIndex < 0 || oldIndex >= ordered.length) return;
    if (newIndex < 0 || newIndex >= ordered.length) return;

    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    final updated = [
      for (var index = 0; index < ordered.length; index++)
        ordered[index].copyWith(sortOrder: index),
    ];

    final previousTasks = List<Task>.from(_tasks);
    for (final task in updated) {
      final index = _tasks.indexWhere((item) => item.id == task.id);
      if (index >= 0) _tasks[index] = task;
    }
    _sortTasks();
    notifyListeners();

    try {
      if (!_isInMemory) await _database.updateTaskOrders(updated);
    } catch (error) {
      _tasks
        ..clear()
        ..addAll(previousTasks);
      _sortTasks();
      notifyListeners();
      rethrow;
    }
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
    _tasks.sort(_compareTasks);
  }

  int _compareTasks(Task first, Task second) {
    final byDate = first.effectivePlanDate.compareTo(second.effectivePlanDate);
    if (byDate != 0) return byDate;
    final byOrder = first.sortOrder.compareTo(second.sortOrder);
    if (byOrder != 0) return byOrder;
    if (first.completed != second.completed) return first.completed ? 1 : -1;
    return second.createdAt.compareTo(first.createdAt);
  }
}

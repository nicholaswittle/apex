import 'package:supabase_flutter/supabase_flutter.dart';

class SideworkService {
  SideworkService(this._client);

  final SupabaseClient _client;

  Future<void> addTask({
    required String taskDate,
    required int dayNum,
    required String task,
    required String assignedTo,
    required String organizationId,
  }) async {
    await _client.from('sidework').insert({
      'task_date': taskDate,
      'day_num': dayNum,
      'task': task,
      'assigned_to': assignedTo,
      'organization_id': organizationId,
    });
  }

  Future<void> toggleCompletion({
    required String taskId,
    required bool completed,
    required String? userId,
  }) async {
    await _client.from('sidework').update({
      'completed': completed,
      'completed_at': completed ? DateTime.now().toIso8601String() : null,
      'completed_by': completed ? userId : null,
    }).eq('id', taskId);
  }
}

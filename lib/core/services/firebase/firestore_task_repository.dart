import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/task.dart';
import '../../repositories/task_repository.dart';
import '../../utils/date_helpers.dart';

/// Used only when USE_FIREBASE=true and anonymous authentication is configured.
class FirestoreTaskRepository implements TaskRepository {
  FirestoreTaskRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _collection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Firebase user is not signed in.');
    return _firestore.collection('users').doc(uid).collection('tasks');
  }

  @override
  Stream<List<Task>> watchTasks() => _collection.snapshots().map((snapshot) =>
      snapshot.docs.map((doc) => Task.fromJson(doc.id, doc.data())).toList()
        ..sort(compareTasks));

  @override
  Future<void> addTask(Task task) => _collection.doc(task.id).set(task.toJson());

  @override
  Future<void> updateTask(Task task) =>
      _collection.doc(task.id).update(task.toJson());

  @override
  Future<void> deleteTask(String taskId) => _collection.doc(taskId).delete();
}

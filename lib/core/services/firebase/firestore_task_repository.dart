import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/task.dart';
import '../../repositories/task_repository.dart';
import '../../utils/date_helpers.dart';

typedef TaskSyncStatus = ({bool fromCache, bool pending, bool rejected});

/// A repository instance belongs to exactly one Firebase user.
class FirestoreTaskRepository implements TaskRepository {
  FirestoreTaskRepository({
    required String uid,
    required FirebaseAuth auth,
    FirebaseFirestore? firestore,
  }) : _uid = uid,
       _auth = auth,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final String _uid;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final _status = ValueNotifier<TaskSyncStatus>((
    fromCache: true,
    pending: false,
    rejected: false,
  ));
  ValueListenable<TaskSyncStatus> get status => _status;

  bool _disposed = false;
  bool _fromCache = true;
  bool _pendingSnapshot = false;
  bool _rejected = false;
  int _writesInFlight = 0;

  CollectionReference<Map<String, dynamic>> get _collection {
    if (_disposed || _auth.currentUser?.uid != _uid) {
      throw StateError('Firebase session changed.');
    }
    return _firestore.collection('users').doc(_uid).collection('tasks');
  }

  @override
  Stream<List<Task>> watchTasks() =>
      _collection.snapshots(includeMetadataChanges: true).map((snapshot) {
        _fromCache = snapshot.metadata.isFromCache;
        _pendingSnapshot = snapshot.metadata.hasPendingWrites;
        _publishStatus();
        return snapshot.docs
            .map((doc) => Task.fromJson(doc.id, doc.data()))
            .toList()
          ..sort(compareTasks);
      });

  void _publishStatus() {
    if (_disposed) return;
    _status.value = (
      fromCache: _fromCache,
      pending: _pendingSnapshot || _writesInFlight > 0,
      rejected: _rejected,
    );
  }

  void dismissWriteError() {
    _rejected = false;
    _publishStatus();
  }

  Future<void> _enqueue(Future<void> Function() dispatch) async {
    // Firestore's write future waits for server acknowledgement, but snapshots
    // already include local changes. Leave it running across offline periods.
    final acknowledgement = dispatch();
    _writesInFlight++;
    _publishStatus();
    unawaited(
      acknowledgement.then<void>(
        (_) => _settleWrite(),
        onError:
            (Object error, StackTrace stack) => _settleWrite(rejected: true),
      ),
    );
  }

  void _settleWrite({bool rejected = false}) {
    _writesInFlight--;
    _rejected = _rejected || rejected;
    _publishStatus();
  }

  @override
  Future<void> addTask(Task task) =>
      _enqueue(() => _collection.doc(task.id).set(task.toJson()));

  // update requires an existing document. An offline edit cannot resurrect a
  // task already deleted by another device.
  @override
  Future<void> updateTask(Task task) =>
      _enqueue(() => _collection.doc(task.id).update(task.toJson()));

  @override
  Future<void> deleteTask(String taskId) =>
      _enqueue(() => _collection.doc(taskId).delete());

  void dispose() {
    _disposed = true;
    _status.dispose();
  }
}

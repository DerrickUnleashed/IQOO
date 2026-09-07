// Offline resilience: connectivity state and a durable event cache.
//
// When a user action fails because the network is unreachable, it is
// queued locally and replayed once connectivity returns. The queue is
// persisted so nothing is lost across app restarts.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/domain/onboarding_providers.dart';

/// Whether the app believes it currently has working network access.
sealed class ConnectivityState {
  const ConnectivityState();
}

class Online extends ConnectivityState {
  const Online();
}

class Offline extends ConnectivityState {
  const Offline();
}

/// Listens for success/failure signals and toggles connectivity state.
final connectivityProvider =
    NotifierProvider<ConnectivityController, ConnectivityState>(
      ConnectivityController.new,
    );

class ConnectivityController extends Notifier<ConnectivityState> {
  @override
  ConnectivityState build() => const Online();

  /// An API call succeeded — connectivity is back if it wasn't before.
  void noteSuccess() {
    if (state is Offline) state = const Online();
  }

  /// An API call failed at the network/transport layer.
  void noteFailure() => state = const Offline();

  void setOffline(bool offline) =>
      state = offline ? const Offline() : const Online();
}

/// A single user action that was queued because the network was down.
class CachedEvent {
  const CachedEvent({
    required this.id,
    required this.kind,
    required this.payload,
    this.createdAt,
  });

  final String id;

  /// Event kind, e.g. 'assistant' (a queued copilot command).
  final String kind;

  /// JSON-safe payload understood by the replay handler.
  final Map<String, dynamic> payload;

  final int? createdAt;

  String toLine() => jsonEncode({
    'id': id,
    'kind': kind,
    'payload': payload,
    'created_at': createdAt,
  });

  static CachedEvent fromLine(String line) {
    try {
      final map = jsonDecode(line) as Map<String, dynamic>;
      return CachedEvent(
        id: map['id'] as String? ?? '',
        kind: map['kind'] as String? ?? '',
        payload: Map<String, dynamic>.from(
          map['payload'] as Map? ?? const {},
        ),
        createdAt: (map['created_at'] as num?)?.toInt(),
      );
    } catch (_) {
      return CachedEvent(id: '', kind: 'corrupt', payload: const {});
    }
  }
}

/// Persistent queue of events waiting to be replayed.
final eventQueueProvider =
    NotifierProvider<EventQueue, List<CachedEvent>>(EventQueue.new);

class EventQueue extends Notifier<List<CachedEvent>> {
  int _fallbackId = 0;

  /// True once the user has queued/cleared anything; the async hydration
  /// never overwrites user mutations that raced ahead of the storage read.
  bool _usermodified = false;

  @override
  List<CachedEvent> build() {
    final storage = ref.read(localStorageProvider);
    Future.microtask(() async {
      final events = List<String>.from(await storage.loadEventQueue())
        ..removeWhere((e) => e.isEmpty);
      if (!ref.mounted || _usermodified) return;
      state = [
        for (final line in events)
          CachedEvent.fromLine(line),
      ].where((e) => e.kind != 'corrupt').toList();
    });
    return const [];
  }

  int get length => state.length;

  /// Adds an event and persists the whole queue.
  Future<void> enqueue(CachedEvent event) async {
    _usermodified = true;
    if (event.id.isEmpty) {
      event = CachedEvent(
        id: (DateTime.now().microsecondsSinceEpoch + _fallbackId++).toString(),
        kind: event.kind,
        payload: event.payload,
        createdAt: event.createdAt,
      );
    }
    state = [...state, event];
    await ref.read(localStorageProvider).saveEventQueue(
      state.map((e) => e.toLine()).toList(),
    );
  }

  /// Replays queued events through [send]; successful ones are dropped.
  ///
  /// Returns the number of events still pending after the attempt.
  Future<int> flush(
    Future<bool> Function(CachedEvent event) send,
  ) async {
    final pending = [...state];
    final remaining = <CachedEvent>[];
    for (final event in pending) {
      try {
        final ok = await send(event);
        if (!ok) remaining.add(event);
      } catch (_) {
        remaining.add(event);
      }
    }
    if (remaining.length != state.length) {
      state = remaining;
      await ref.read(localStorageProvider).saveEventQueue(
        state.map((e) => e.toLine()).toList(),
      );
    }
    return remaining.length;
  }

  /// Drops every queued event (used by tests and resets).
  Future<void> clear() async {
    _usermodified = true;
    state = const [];
    await ref.read(localStorageProvider).saveEventQueue(const []);
  }
}
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/home_event.dart';
import '../domain/home_thing.dart';
import '../domain/homi_household.dart';
import '../domain/household_data_mutation.dart';
import '../domain/routine_item.dart';
import '../domain/supply_item.dart';
import '../domain/utility_reading.dart';
import '../state/homi_app_controller.dart';
import 'household_service.dart';

/// Local-first synchronization for the canonical shared Household data plane.
///
/// Homi continues to persist every edit locally first. Firestore mirrors only
/// records that belong to the current canonical Household. Existing device
/// data is never silently uploaded when a user joins a different Household.
/// The first owner of a brand-new empty Household may import the device's
/// existing Home/Routine/Supply data once, because that is the safe migration
/// from the pre-0.12 single-device model.
class HouseholdDataSyncService {
  HouseholdDataSyncService({
    required this.firebaseReady,
    required this.controller,
  }) : _householdService = HouseholdService(firebaseReady: firebaseReady);

  static const _lastHouseholdKey = 'homi.householdSync.lastHouseholdId';
  static const _schemaVersion = 1;

  final bool firebaseReady;
  final HomiAppController controller;
  final HouseholdService _householdService;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  User? get _user => firebaseReady ? FirebaseAuth.instance.currentUser : null;

  StreamSubscription<HomiHousehold?>? _householdSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _dataSubscription;
  SharedPreferences? _prefs;
  HomiHousehold? _household;
  bool _classified = false;
  bool _disposed = false;

  final Map<HouseholdDataDomain, Set<String>> _sharedIds = {
    for (final domain in HouseholdDataDomain.values) domain: <String>{},
  };
  final Map<HouseholdDataDomain, Set<String>> _privateLegacyIds = {
    for (final domain in HouseholdDataDomain.values) domain: <String>{},
  };
  final Map<HouseholdDataDomain, Set<String>> _pendingUpserts = {
    for (final domain in HouseholdDataDomain.values) domain: <String>{},
  };
  final Map<HouseholdDataDomain, Set<String>> _pendingDeletes = {
    for (final domain in HouseholdDataDomain.values) domain: <String>{},
  };

  Future<void> start() async {
    if (!firebaseReady || _user == null || _disposed) return;
    _prefs = await SharedPreferences.getInstance();
    if (_disposed || controller.localOnly) return;
    _householdSubscription = _householdService.watchCurrentHousehold().listen(
      (household) => unawaited(_switchHousehold(household)),
      onError: (_) {
        // Cloud sync is additive. The local controller remains authoritative
        // for this device while Household identity is temporarily unavailable.
      },
    );
  }

  Future<void> disposeService() async {
    _disposed = true;
    controller.bindHouseholdDataSink(null);
    await _householdSubscription?.cancel();
    await _dataSubscription?.cancel();
  }

  Future<void> _switchHousehold(HomiHousehold? household) async {
    if (_disposed || controller.localOnly) return;
    if (_household?.id == household?.id) {
      _household = household;
      return;
    }

    controller.bindHouseholdDataSink(null);
    await _dataSubscription?.cancel();
    _dataSubscription = null;
    _household = household;
    _classified = false;
    for (final domain in HouseholdDataDomain.values) {
      _sharedIds[domain]!.clear();
      _privateLegacyIds[domain]!.clear();
      _pendingUpserts[domain]!.clear();
      _pendingDeletes[domain]!.clear();
    }

    if (household == null || _user == null) return;
    await _loadPersistedSharedIds(household.id);
    if (_disposed || controller.localOnly || _household?.id != household.id) {
      return;
    }

    _dataSubscription = _firestore
        .collection('households')
        .doc(household.id)
        .collection('data')
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snapshot) => unawaited(_handleSnapshot(snapshot)),
      onError: (_) {
        // Existing local state stays usable. Firestore will resume the stream
        // when connectivity or authorization recovers.
      },
    );
  }

  Future<void> _handleSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final household = _household;
    final user = _user;
    if (_disposed ||
        controller.localOnly ||
        household == null ||
        user == null) {
      return;
    }

    final parsed = _parseSnapshot(snapshot);

    if (!_classified) {
      // An empty cache is not proof that the server Household is empty. Wait
      // for an authoritative server snapshot before deciding whether the old
      // local-only data is safe to import.
      if (snapshot.metadata.isFromCache) return;

      final lastHouseholdId = _prefs?.getString(_lastHouseholdKey);
      for (final domain in HouseholdDataDomain.values) {
        _sharedIds[domain]!.addAll(parsed.idsFor(domain));
      }

      final canImportLegacy = lastHouseholdId == null &&
          household.ownerUid == user.uid &&
          snapshot.docs.isEmpty;

      if (canImportLegacy) {
        try {
          await _importCurrentLocalState(household.id, user.uid);
        } catch (_) {
          // Do not classify or bind writes after a failed migration. A later
          // authoritative snapshot can safely retry without deleting local data.
          return;
        }
      } else {
        _classifyPrivateLegacyIds(parsed);
      }

      _classified = true;
      await _prefs?.setString(_lastHouseholdKey, household.id);
      await _persistAllSharedIds(household.id);
      controller.bindHouseholdDataSink(_handleLocalMutation);

      if (canImportLegacy) {
        // The import commit is now queued/acknowledged. Wait for Firestore's
        // next snapshot instead of applying the pre-import empty snapshot and
        // temporarily clearing the owner's local lists.
        return;
      }
    }

    // Cloud documents always graduate a matching legacy ID into shared state.
    for (final domain in HouseholdDataDomain.values) {
      final cloudIds = parsed.idsFor(domain);
      _privateLegacyIds[domain]!.removeAll(cloudIds);
      _pendingUpserts[domain]!.removeAll(cloudIds);

      if (!snapshot.metadata.isFromCache) {
        final nextShared = <String>{...cloudIds, ..._pendingUpserts[domain]!};
        _sharedIds[domain]!
          ..clear()
          ..addAll(nextShared);
      } else {
        _sharedIds[domain]!.addAll(cloudIds);
      }

      final deleted = _pendingDeletes[domain]!;
      deleted.removeWhere((id) => !cloudIds.contains(id));
    }

    await _persistAllSharedIds(household.id);
    await _applyParsedSnapshot(parsed);
  }

  void _classifyPrivateLegacyIds(_ParsedHouseholdData parsed) {
    for (final domain in HouseholdDataDomain.values) {
      final localIds = _localIdsFor(domain);
      final knownShared = <String>{
        ..._sharedIds[domain]!,
        ...parsed.idsFor(domain),
      };
      _privateLegacyIds[domain]!
        ..clear()
        ..addAll(localIds.difference(knownShared));
    }
  }

  Future<void> _importCurrentLocalState(
    String householdId,
    String uid,
  ) async {
    final records = <_CloudRecord>[
      ...controller.routines.map(
        (item) => _CloudRecord(
          domain: HouseholdDataDomain.routine,
          itemId: item.id,
          payload: item.toJson(),
        ),
      ),
      ...controller.supplies.map(
        (item) => _CloudRecord(
          domain: HouseholdDataDomain.supply,
          itemId: item.id,
          payload: item.toJson(),
        ),
      ),
      ...controller.homeThings.map(
        (item) => _CloudRecord(
          domain: HouseholdDataDomain.homeThing,
          itemId: item.id,
          payload: item.toJson(),
        ),
      ),
      ...controller.homeEvents.map(
        (item) => _CloudRecord(
          domain: HouseholdDataDomain.homeEvent,
          itemId: item.id,
          payload: item.toJson(),
        ),
      ),
      ...controller.utilityReadings.map(
        (item) => _CloudRecord(
          domain: HouseholdDataDomain.utilityReading,
          itemId: item.id,
          payload: item.toJson(),
        ),
      ),
    ];

    for (var start = 0; start < records.length; start += 400) {
      final batch = _firestore.batch();
      for (final record in records.skip(start).take(400)) {
        batch.set(
          _recordRef(householdId, record.domain, record.itemId),
          _cloudDocument(record, uid),
        );
      }
      await batch.commit();
    }

    for (final record in records) {
      _sharedIds[record.domain]!.add(record.itemId);
    }
  }

  Future<void> _handleLocalMutation(HouseholdDataMutation mutation) async {
    final household = _household;
    final user = _user;
    if (_disposed ||
        controller.localOnly ||
        !_classified ||
        household == null ||
        user == null) {
      return;
    }

    // Records that pre-date joining this Household remain device-private until
    // a future explicit merge choice. Editing one must not silently upload it.
    if (_privateLegacyIds[mutation.domain]!.contains(mutation.itemId)) return;

    final ref = _recordRef(household.id, mutation.domain, mutation.itemId);
    if (mutation.delete) {
      _pendingUpserts[mutation.domain]!.remove(mutation.itemId);
      _pendingDeletes[mutation.domain]!.add(mutation.itemId);
      _sharedIds[mutation.domain]!.remove(mutation.itemId);
      await _persistSharedIds(household.id, mutation.domain);
      await ref.delete();
      return;
    }

    final payload = mutation.payload;
    if (payload == null) return;
    _pendingDeletes[mutation.domain]!.remove(mutation.itemId);
    _pendingUpserts[mutation.domain]!.add(mutation.itemId);
    _sharedIds[mutation.domain]!.add(mutation.itemId);
    await _persistSharedIds(household.id, mutation.domain);
    await ref.set(
      _cloudDocument(
        _CloudRecord(
          domain: mutation.domain,
          itemId: mutation.itemId,
          payload: payload,
        ),
        user.uid,
      ),
    );
  }

  DocumentReference<Map<String, dynamic>> _recordRef(
    String householdId,
    HouseholdDataDomain domain,
    String itemId,
  ) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('data')
        .doc('${domain.cloudValue}--$itemId');
  }

  Map<String, dynamic> _cloudDocument(_CloudRecord record, String uid) {
    return <String, dynamic>{
      'domain': record.domain.cloudValue,
      'itemId': record.itemId,
      'payload': record.payload,
      'schemaVersion': _schemaVersion,
      'updatedByUid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  _ParsedHouseholdData _parseSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final routines = <RoutineItem>[];
    final supplies = <SupplyItem>[];
    final homeThings = <HomeThing>[];
    final homeEvents = <HomeEvent>[];
    final utilityReadings = <UtilityReading>[];

    for (final document in snapshot.docs) {
      final data = document.data();
      final domainValue = data['domain'];
      final itemId = data['itemId'];
      final rawPayload = data['payload'];
      if (domainValue is! String || itemId is! String || rawPayload is! Map) {
        continue;
      }
      final domain = HouseholdDataDomainValue.fromCloudValue(domainValue);
      if (domain == null) continue;
      final payload = Map<String, dynamic>.from(rawPayload);
      payload['id'] = itemId;
      try {
        switch (domain) {
          case HouseholdDataDomain.routine:
            routines.add(RoutineItem.fromJson(payload));
          case HouseholdDataDomain.supply:
            supplies.add(SupplyItem.fromJson(payload));
          case HouseholdDataDomain.homeThing:
            homeThings.add(HomeThing.fromJson(payload));
          case HouseholdDataDomain.homeEvent:
            homeEvents.add(HomeEvent.fromJson(payload));
          case HouseholdDataDomain.utilityReading:
            utilityReadings.add(UtilityReading.fromJson(payload));
        }
      } catch (_) {
        // One malformed historical record must not block the rest of the
        // Household snapshot from loading on this device.
      }
    }

    return _ParsedHouseholdData(
      routines: routines,
      supplies: supplies,
      homeThings: homeThings,
      homeEvents: homeEvents,
      utilityReadings: utilityReadings,
    );
  }

  Future<void> _applyParsedSnapshot(_ParsedHouseholdData parsed) async {
    Set<String> preserved(HouseholdDataDomain domain) => <String>{
          ..._privateLegacyIds[domain]!,
          ..._pendingUpserts[domain]!,
        };

    List<T> withoutPendingDeletes<T>(
      List<T> values,
      HouseholdDataDomain domain,
      String Function(T item) idOf,
    ) {
      final deleted = _pendingDeletes[domain]!;
      return values
          .where((item) => !deleted.contains(idOf(item)))
          .toList(growable: false);
    }

    await controller.applyHouseholdRoutines(
      withoutPendingDeletes(
        parsed.routines,
        HouseholdDataDomain.routine,
        (item) => item.id,
      ),
      preserveLocalIds: preserved(HouseholdDataDomain.routine),
    );
    await controller.applyHouseholdSupplies(
      withoutPendingDeletes(
        parsed.supplies,
        HouseholdDataDomain.supply,
        (item) => item.id,
      ),
      preserveLocalIds: preserved(HouseholdDataDomain.supply),
    );
    await controller.applyHouseholdHomeThings(
      withoutPendingDeletes(
        parsed.homeThings,
        HouseholdDataDomain.homeThing,
        (item) => item.id,
      ),
      preserveLocalIds: preserved(HouseholdDataDomain.homeThing),
    );
    await controller.applyHouseholdHomeEvents(
      withoutPendingDeletes(
        parsed.homeEvents,
        HouseholdDataDomain.homeEvent,
        (item) => item.id,
      ),
      preserveLocalIds: preserved(HouseholdDataDomain.homeEvent),
    );
    await controller.applyHouseholdUtilityReadings(
      withoutPendingDeletes(
        parsed.utilityReadings,
        HouseholdDataDomain.utilityReading,
        (item) => item.id,
      ),
      preserveLocalIds: preserved(HouseholdDataDomain.utilityReading),
    );
  }

  Set<String> _localIdsFor(HouseholdDataDomain domain) => switch (domain) {
        HouseholdDataDomain.routine =>
          controller.routines.map((item) => item.id).toSet(),
        HouseholdDataDomain.supply =>
          controller.supplies.map((item) => item.id).toSet(),
        HouseholdDataDomain.homeThing =>
          controller.homeThings.map((item) => item.id).toSet(),
        HouseholdDataDomain.homeEvent =>
          controller.homeEvents.map((item) => item.id).toSet(),
        HouseholdDataDomain.utilityReading =>
          controller.utilityReadings.map((item) => item.id).toSet(),
      };

  String _sharedIdsKey(String householdId, HouseholdDataDomain domain) =>
      'homi.householdSync.$householdId.${domain.cloudValue}.sharedIds';

  Future<void> _loadPersistedSharedIds(String householdId) async {
    for (final domain in HouseholdDataDomain.values) {
      final stored = _prefs?.getStringList(_sharedIdsKey(householdId, domain)) ??
          const <String>[];
      _sharedIds[domain]!
        ..clear()
        ..addAll(stored.where((id) => id.trim().isNotEmpty));
    }
  }

  Future<void> _persistSharedIds(
    String householdId,
    HouseholdDataDomain domain,
  ) async {
    final values = _sharedIds[domain]!.toList(growable: false)..sort();
    await _prefs?.setStringList(_sharedIdsKey(householdId, domain), values);
  }

  Future<void> _persistAllSharedIds(String householdId) async {
    for (final domain in HouseholdDataDomain.values) {
      await _persistSharedIds(householdId, domain);
    }
  }
}

class _CloudRecord {
  const _CloudRecord({
    required this.domain,
    required this.itemId,
    required this.payload,
  });

  final HouseholdDataDomain domain;
  final String itemId;
  final Map<String, dynamic> payload;
}

class _ParsedHouseholdData {
  const _ParsedHouseholdData({
    required this.routines,
    required this.supplies,
    required this.homeThings,
    required this.homeEvents,
    required this.utilityReadings,
  });

  final List<RoutineItem> routines;
  final List<SupplyItem> supplies;
  final List<HomeThing> homeThings;
  final List<HomeEvent> homeEvents;
  final List<UtilityReading> utilityReadings;

  Set<String> idsFor(HouseholdDataDomain domain) => switch (domain) {
        HouseholdDataDomain.routine => routines.map((item) => item.id).toSet(),
        HouseholdDataDomain.supply => supplies.map((item) => item.id).toSet(),
        HouseholdDataDomain.homeThing =>
          homeThings.map((item) => item.id).toSet(),
        HouseholdDataDomain.homeEvent =>
          homeEvents.map((item) => item.id).toSet(),
        HouseholdDataDomain.utilityReading =>
          utilityReadings.map((item) => item.id).toSet(),
      };
}

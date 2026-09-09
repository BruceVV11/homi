import 'home_event.dart';
import 'utility_reading.dart';

class HomeThingInput {
  const HomeThingInput({
    required this.name,
    required this.category,
    required this.location,
    this.brandModel,
    this.nextServiceDate,
    this.warrantyUntil,
    this.notes,
  });

  final String name;
  final String category;
  final String location;
  final String? brandModel;
  final DateTime? nextServiceDate;
  final DateTime? warrantyUntil;
  final String? notes;
}

class HomeEventInput {
  const HomeEventInput({
    required this.type,
    required this.title,
    required this.date,
    required this.completedByName,
    this.thingId,
    this.notes,
  });

  final HomeEventType type;
  final String title;
  final DateTime date;
  final String completedByName;
  final String? thingId;
  final String? notes;
}

class UtilityReadingInput {
  const UtilityReadingInput({
    required this.type,
    required this.value,
    required this.recordedAt,
    required this.recordedByName,
    this.unit,
    this.notes,
  });

  final UtilityType type;
  final double value;
  final DateTime recordedAt;
  final String recordedByName;
  final String? unit;
  final String? notes;
}

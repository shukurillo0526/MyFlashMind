import 'package:hive/hive.dart';

part 'folder.g.dart';

/// A folder to organize flashcard sets
@HiveType(typeId: 2)
class Folder extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  @HiveField(5)
  List<String> setIds;

  Folder({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    List<String>? setIds,
  }) : setIds = setIds ?? [];

  /// Number of sets in the folder
  int get setCount => setIds.length;

  /// Create a copy with updated fields
  Folder copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? setIds,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      setIds: setIds ?? this.setIds,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'setIds': setIds,
    };
  }

  /// Create from JSON map
  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      setIds: (json['setIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }
}

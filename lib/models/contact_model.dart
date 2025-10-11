library contact_model_library;

import 'package:hive/hive.dart';

part 'contact_model.g.dart';

@HiveType(typeId: 0)
class ContactModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String email;

  @HiveField(3)
  final String? phoneNumber;

  @HiveField(4)
  final String userId; // The Firebase UID of the contact

  @HiveField(5)
  final DateTime addedAt;

  ContactModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    required this.userId,
    required this.addedAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'userId': userId,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  // Create from Firestore document
  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'],
      userId: map['userId'] ?? '',
      addedAt: DateTime.parse(
        map['addedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  // Copy with method
  ContactModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? userId,
    DateTime? addedAt,
  }) {
    return ContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      userId: userId ?? this.userId,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}

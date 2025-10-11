import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/contact_model.dart';
import '../utils/constants.dart';

class ContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // Get Hive box
  Box<ContactModel> get _contactsBox =>
      Hive.box<ContactModel>(AppConstants.contactsBox);

  // Add contact (save to both Firestore and local Hive)
  Future<ContactModel> addContact({
    required String currentUserId,
    required String name,
    required String email,
    String? phoneNumber,
    required String contactUserId,
  }) async {
    try {
      final contact = ContactModel(
        id: _uuid.v4(),
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        userId: contactUserId,
        addedAt: DateTime.now(),
      );

      // Save to Firestore (cloud)
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(currentUserId)
          .collection(AppConstants.contactsCollection)
          .doc(contact.id)
          .set(contact.toMap());

      // Save to local Hive (offline access)
      await _contactsBox.put(contact.id, contact);

      return contact;
    } catch (e) {
      throw 'Error adding contact: $e';
    }
  }

  // Get all contacts for current user
  Future<List<ContactModel>> getContacts(String userId) async {
    try {
      // First try to get from local storage
      if (_contactsBox.isNotEmpty) {
        return _contactsBox.values.toList();
      }

      // If local is empty, fetch from Firestore
      QuerySnapshot snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.contactsCollection)
          .orderBy('name')
          .get();

      List<ContactModel> contacts = snapshot.docs
          .map(
            (doc) => ContactModel.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();

      // Save to local storage
      for (var contact in contacts) {
        await _contactsBox.put(contact.id, contact);
      }

      return contacts;
    } catch (e) {
      throw 'Error fetching contacts: $e';
    }
  }

  // Get contact by ID
  ContactModel? getContactById(String contactId) {
    return _contactsBox.get(contactId);
  }

  // Update contact
  Future<void> updateContact({
    required String currentUserId,
    required String contactId,
    String? name,
    String? email,
    String? phoneNumber,
  }) async {
    try {
      ContactModel? contact = _contactsBox.get(contactId);
      if (contact == null) throw 'Contact not found';

      Map<String, dynamic> updates = {};

      if (name != null) updates['name'] = name;
      if (email != null) updates['email'] = email;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;

      if (updates.isNotEmpty) {
        // Update in Firestore
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(currentUserId)
            .collection(AppConstants.contactsCollection)
            .doc(contactId)
            .update(updates);

        // Update in local storage
        ContactModel updatedContact = contact.copyWith(
          name: name ?? contact.name,
          email: email ?? contact.email,
          phoneNumber: phoneNumber ?? contact.phoneNumber,
        );

        await _contactsBox.put(contactId, updatedContact);
      }
    } catch (e) {
      throw 'Error updating contact: $e';
    }
  }

  // Delete contact
  Future<void> deleteContact({
    required String currentUserId,
    required String contactId,
  }) async {
    try {
      // Delete from Firestore
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(currentUserId)
          .collection(AppConstants.contactsCollection)
          .doc(contactId)
          .delete();

      // Delete from local storage
      await _contactsBox.delete(contactId);
    } catch (e) {
      throw 'Error deleting contact: $e';
    }
  }

  // Search contacts locally
  List<ContactModel> searchContacts(String query) {
    if (query.isEmpty) return _contactsBox.values.toList();

    return _contactsBox.values.where((contact) {
      final searchLower = query.toLowerCase();
      final nameLower = contact.name.toLowerCase();
      final emailLower = contact.email.toLowerCase();
      final phoneLower = contact.phoneNumber?.toLowerCase() ?? '';

      return nameLower.contains(searchLower) ||
          emailLower.contains(searchLower) ||
          phoneLower.contains(searchLower);
    }).toList();
  }

  // Sync contacts from cloud to local
  Future<void> syncContacts(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.contactsCollection)
          .get();

      // Clear local storage
      await _contactsBox.clear();

      // Add all contacts from Firestore
      for (var doc in snapshot.docs) {
        ContactModel contact = ContactModel.fromMap(
          doc.data() as Map<String, dynamic>,
        );
        await _contactsBox.put(contact.id, contact);
      }
    } catch (e) {
      throw 'Error syncing contacts: $e';
    }
  }

  // Get contact count
  int getContactCount() {
    return _contactsBox.length;
  }
}

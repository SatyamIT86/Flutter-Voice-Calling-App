// lib/screens/contacts/contacts_screen.dart

import 'package:flutter/material.dart';
import '../../models/contact_model.dart';
import '../../services/contact_service.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import 'add_contact_screen.dart';
import '../call/call_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _contactService = ContactService();
  final _authService = AuthService();
  final _searchController = TextEditingController();

  List<ContactModel> _contacts = [];
  List<ContactModel> _filteredContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);

    try {
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        final contacts = await _contactService.getContacts(userId);
        setState(() {
          _contacts = contacts;
          _filteredContacts = contacts;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading contacts: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterContacts() {
    final query = _searchController.text;
    setState(() {
      _filteredContacts = _contactService.searchContacts(query);
    });
  }

  void _deleteContact(ContactModel contact) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete ${contact.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final userId = _authService.currentUser?.uid;
                if (userId != null) {
                  await _contactService.deleteContact(
                    currentUserId: userId,
                    contactId: contact.id,
                  );

                  _loadContacts();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Contact deleted')),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.dangerColor),
            ),
          ),
        ],
      ),
    );
  }

  void _initiateCall(ContactModel contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          contactName: contact.name,
          contactUserId: contact.userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.backgroundColor,
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.contacts_outlined,
                          size: 80,
                          color: AppColors.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'No contacts yet'
                              : 'No contacts found',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadContacts,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = _filteredContacts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryColor,
                              child: Text(
                                contact.name[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              contact.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(contact.email),
                                if (contact.phoneNumber != null)
                                  Text(contact.phoneNumber!),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.phone,
                                    color: AppColors.successColor,
                                  ),
                                  onPressed: () => _initiateCall(contact),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: AppColors.dangerColor,
                                  ),
                                  onPressed: () => _deleteContact(contact),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddContactScreen()),
          );

          if (result == true) {
            _loadContacts();
          }
        },
        backgroundColor: AppColors.primaryColor,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

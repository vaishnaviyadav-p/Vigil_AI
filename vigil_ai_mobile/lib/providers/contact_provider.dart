import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_ai_mobile/core/network/api_client.dart';
import 'package:vigil_ai_mobile/models/contact_model.dart';

class ContactState {
  final List<ContactModel> contacts;
  final bool isLoading;
  final String? errorMessage;

  ContactState({
    this.contacts = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ContactState copyWith({
    List<ContactModel>? contacts,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ContactState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ContactNotifier extends StateNotifier<ContactState> {
  final ApiClient _api = ApiClient();

  ContactNotifier() : super(ContactState()) {
    fetchContacts();
  }

  Future<void> fetchContacts() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.dio.get('/contacts');
      if (res.data['success'] == true) {
        final raw = res.data['data'] as List;
        final list = raw.map((c) => ContactModel.fromJson(c)).toList();
        state = state.copyWith(contacts: list, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load contacts from server.',
      );
    }
  }

  Future<bool> addContact({
    required String name,
    required String phone,
    String? email,
    String relationship = 'Friend',
    int priority = 1,
    String notificationPreference = 'ALL',
  }) async {
    try {
      final res = await _api.dio.post('/contacts', data: {
        'name': name,
        'phone': phone,
        'email': email,
        'relationship': relationship,
        'priority': priority,
        'notification_preference': notificationPreference,
      });

      if (res.data['success'] == true) {
        await fetchContacts();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> deleteContact(int id) async {
    try {
      final res = await _api.dio.delete('/contacts/$id');
      if (res.data['success'] == true) {
        await fetchContacts();
        return true;
      }
    } catch (_) {}
    return false;
  }
}

final contactProvider = StateNotifierProvider<ContactNotifier, ContactState>((ref) {
  return ContactNotifier();
});

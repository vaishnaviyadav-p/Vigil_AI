import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_ai_mobile/core/network/api_client.dart';
import 'package:vigil_ai_mobile/models/contact_model.dart';

class ContactState {
  final List<ContactModel> contacts;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  ContactState({
    this.contacts = const [],
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  ContactState copyWith({
    List<ContactModel>? contacts,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ContactState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class ContactNotifier extends StateNotifier<ContactState> {
  final ApiClient _api = ApiClient();

  ContactNotifier() : super(ContactState());

  void clear() {
    state = ContactState(contacts: const [], isLoading: false);
  }

  String _extractError(dynamic e, String fallback) {
    if (e is DioException) {
      if (e.response?.data is Map && (e.response!.data as Map)['message'] != null) {
        return (e.response!.data as Map)['message'].toString();
      }
      if (e.response?.statusCode == 404) {
        return 'Contact not found or does not belong to your account.';
      }
      if (e.response?.statusCode == 409) {
        return 'A contact with this phone number already exists.';
      }
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
        return 'Cannot connect to backend server. Check Wi-Fi / IP.';
      }
    }
    return fallback;
  }

  Future<bool> fetchContacts() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.dio.get('/contacts');
      if (res.data['success'] == true) {
        final raw = res.data['data'] as List;
        final list = raw.map((c) => ContactModel.fromJson(c)).toList();
        state = state.copyWith(contacts: list, isLoading: false, clearError: true);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: res.data['message'] ?? 'Unable to load contacts.',
        );
        return false;
      }
    } catch (e) {
      final msg = _extractError(e, 'Unable to load contacts from server.');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<({bool success, String message})> addContact({
    required String name,
    required String phone,
    String? email,
    String relationship = 'Friend',
    int priority = 1,
    String notificationPreference = 'ALL',
  }) async {
    final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (name.trim().isEmpty) {
      return (success: false, message: 'Contact name cannot be empty.');
    }
    if (cleanDigits.length < 10) {
      return (success: false, message: 'Please enter a valid phone number (at least 10 digits).');
    }

    try {
      final res = await _api.dio.post('/contacts', data: {
        'name': name.trim(),
        'phone': phone.trim(),
        'email': (email != null && email.trim().isNotEmpty) ? email.trim() : null,
        'relationship': relationship,
        'priority': priority,
        'notification_preference': notificationPreference,
      });

      if (res.data['success'] == true) {
        await fetchContacts();
        final msg = res.data['message']?.toString() ?? 'Contact added successfully.';
        state = state.copyWith(successMessage: msg);
        return (success: true, message: msg);
      } else {
        final err = res.data['message']?.toString() ?? 'Failed to add contact.';
        return (success: false, message: err);
      }
    } catch (e) {
      final err = _extractError(e, 'Failed to add contact.');
      return (success: false, message: err);
    }
  }

  Future<({bool success, String message})> updateContact({
    required int id,
    required String name,
    required String phone,
    String? email,
    String relationship = 'Friend',
    int priority = 1,
    bool isActive = true,
    String notificationPreference = 'ALL',
  }) async {
    final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (name.trim().isEmpty) {
      return (success: false, message: 'Contact name cannot be empty.');
    }
    if (cleanDigits.length < 10) {
      return (success: false, message: 'Please enter a valid phone number (at least 10 digits).');
    }

    try {
      final res = await _api.dio.put('/contacts/$id', data: {
        'name': name.trim(),
        'phone': phone.trim(),
        'email': (email != null && email.trim().isNotEmpty) ? email.trim() : null,
        'relationship': relationship,
        'priority': priority,
        'is_active': isActive,
        'notification_preference': notificationPreference,
      });

      if (res.data['success'] == true) {
        await fetchContacts();
        final msg = res.data['message']?.toString() ?? 'Contact updated successfully.';
        state = state.copyWith(successMessage: msg);
        return (success: true, message: msg);
      } else {
        final err = res.data['message']?.toString() ?? 'Failed to update contact.';
        return (success: false, message: err);
      }
    } catch (e) {
      final err = _extractError(e, 'Failed to update contact.');
      return (success: false, message: err);
    }
  }

  Future<({bool success, String message})> deleteContact(int id) async {
    try {
      final res = await _api.dio.delete('/contacts/$id');
      if (res.data['success'] == true) {
        await fetchContacts();
        final msg = res.data['message']?.toString() ?? 'Contact removed successfully.';
        state = state.copyWith(successMessage: msg);
        return (success: true, message: msg);
      } else {
        final err = res.data['message']?.toString() ?? 'Failed to delete contact.';
        return (success: false, message: err);
      }
    } catch (e) {
      final err = _extractError(e, 'Failed to delete contact.');
      return (success: false, message: err);
    }
  }

  Future<({bool success, String message})> cleanDemoContacts() async {
    try {
      final res = await _api.dio.delete('/contacts/clean-demo');
      if (res.data['success'] == true) {
        await fetchContacts();
        final msg = res.data['message']?.toString() ?? 'Demo contacts removed successfully.';
        state = state.copyWith(successMessage: msg);
        return (success: true, message: msg);
      } else {
        final err = res.data['message']?.toString() ?? 'Failed to remove demo contacts.';
        return (success: false, message: err);
      }
    } catch (e) {
      final err = _extractError(e, 'Failed to remove demo contacts.');
      return (success: false, message: err);
    }
  }
}

final contactProvider = StateNotifierProvider<ContactNotifier, ContactState>((ref) {
  return ContactNotifier();
});

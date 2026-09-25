import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/providers/incident_provider.dart';
import 'package:vigil_ai_mobile/services/location_service.dart';

class ReportIncidentView extends ConsumerStatefulWidget {
  const ReportIncidentView({super.key});

  @override
  ConsumerState<ReportIncidentView> createState() => _ReportIncidentViewState();
}

class _ReportIncidentViewState extends ConsumerState<ReportIncidentView> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _selectedCategory = 'Harassment';
  String _selectedSeverity = 'MEDIUM';
  bool _submitting = false;

  final List<String> _categories = [
    'Harassment',
    'Suspicious Activity',
    'Physical Threat',
    'Theft',
    'Accident',
    'Other',
  ];

  final List<String> _severities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

  @override
  void dispose() {
    _descCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final pos = await LocationService().getCurrentPosition();
    final lat = pos?.latitude ?? 12.9716;
    final lon = pos?.longitude ?? 77.5946;

    final success = await ref.read(incidentProvider.notifier).reportIncident(
          category: _selectedCategory,
          description: _descCtrl.text.trim(),
          latitude: lat,
          longitude: lon,
          address: _addressCtrl.text.trim().isEmpty ? 'Near user GPS' : _addressCtrl.text.trim(),
          severity: _selectedSeverity,
        );

    setState(() => _submitting = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incident submitted successfully for review.')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submission failed. Check network connection.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Report Safety Incident'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Help keep the community informed about unsafe locations and safety threats.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),

              // Category Picker
              const Text('Incident Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final isSelected = cat == _selectedCategory;
                  return ChoiceChip(
                    label: Text(cat, style: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontSize: 12)),
                    selected: isSelected,
                    selectedColor: AppColors.primaryIndigo,
                    backgroundColor: AppColors.card,
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Severity Level
              const Text('Assessed Severity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: _severities.map((sev) {
                  final isSelected = sev == _selectedSeverity;
                  final color = AppColors.getRiskColor(sev);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isSelected ? color.withOpacity(0.2) : AppColors.card,
                          side: BorderSide(color: isSelected ? color : AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => setState(() => _selectedSeverity = sev),
                        child: Text(
                          sev,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? color : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Description
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Describe what happened...',
                  alignLabelWithHint: true,
                ),
                validator: (v) => v == null || v.isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 16),

              // Address / Landmark
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Location Landmark (e.g. North Gate Bus Shelter)',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
              ),
              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _submitting ? null : _handleSubmit,
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Safety Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

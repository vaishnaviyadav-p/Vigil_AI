import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/providers/contact_provider.dart';
import 'package:vigil_ai_mobile/providers/emergency_provider.dart';

class ActiveEmergencyView extends ConsumerWidget {
  const ActiveEmergencyView({super.key});

  Future<void> _launchSms(BuildContext context, String phone, String message) async {
    final cleanPhone = phone.replaceAll(' ', '');
    final uri = Uri(
      scheme: 'sms',
      path: cleanPhone,
      queryParameters: {'body': message},
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch SMS app: $e')),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(BuildContext context, String phone, String message) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp: $e')),
        );
      }
    }
  }

  Future<void> _launchCall(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    try {
      await launchUrl(uri);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not place phone call: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emergencyState = ref.watch(emergencyProvider);
    final emergency = emergencyState.activeEmergency;
    final trackingUrl = emergencyState.trackingUrl ?? emergency?.trackingUrl;
    final smsDispatch = emergencyState.smsDispatch ?? emergency?.smsDispatch;

    final contactState = ref.watch(contactProvider);
    final contacts = contactState.contacts;

    final alertMessage = smsDispatch?['alert_text'] ??
        '🚨 Vigil AI SOS Alert!\n'
        'User has triggered an EMERGENCY SOS.\n'
        'Current Location: (${emergency?.latitude.toStringAsFixed(5) ?? "12.9716"}, ${emergency?.longitude.toStringAsFixed(5) ?? "77.5946"})\n'
        'Live Tracking Link: ${trackingUrl ?? "Active"}\n'
        'Please check on them immediately!';

    return PopScope(
      canPop: false, // Prevent accidental back button press during active emergency
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'EMERGENCY ACTIVE',
            style: TextStyle(color: AppColors.sosRed, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.surface,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Flashing emergency banner
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.sosRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.sosRed, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.warning_rounded, color: AppColors.sosRed, size: 48),
                      const SizedBox(height: 10),
                      const Text(
                        'DISPATCH SIGNAL ACTIVE',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.sosRed,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        emergencyState.statusMessage ??
                            'Live GPS coordinates are actively streaming to the monitoring server.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Live GPS Streaming status card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (emergencyState.isLiveLocationSharing
                                  ? AppColors.safeGreen
                                  : AppColors.textMuted)
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.share_location,
                          color: emergencyState.isLiveLocationSharing
                              ? AppColors.safeGreen
                              : AppColors.textMuted,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emergencyState.isLiveLocationSharing
                                  ? 'Live GPS Sharing: ACTIVE'
                                  : 'Live GPS Sharing: PAUSED',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Updates sent: ${emergencyState.updateCount} | Every 4s',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: emergencyState.isLiveLocationSharing,
                        activeThumbColor: AppColors.safeGreen,
                        onChanged: (val) {
                          ref.read(emergencyProvider.notifier).setLiveSharing(val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Direct Contact Dispatch Card (Instant Phone SMS / WhatsApp / Call)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.safeGreen.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.safeGreen.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.send_rounded, color: AppColors.safeGreen, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Send Live Location to Contacts',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Uses your phone\'s SIM card SMS or WhatsApp (100% Free)',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (smsDispatch != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: (smsDispatch['status'] == 'DELIVERED'
                                    ? AppColors.safeGreen
                                    : (smsDispatch['status'] == 'FAILED' ? AppColors.sosRed : AppColors.primaryLight))
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (smsDispatch['status'] == 'DELIVERED'
                                  ? AppColors.safeGreen
                                  : (smsDispatch['status'] == 'FAILED' ? AppColors.sosRed : AppColors.primaryLight)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                smsDispatch['status'] == 'DELIVERED'
                                    ? Icons.check_circle_outline
                                    : (smsDispatch['status'] == 'FAILED' ? Icons.error_outline : Icons.info_outline),
                                size: 16,
                                color: smsDispatch['status'] == 'DELIVERED'
                                    ? AppColors.safeGreen
                                    : (smsDispatch['status'] == 'FAILED' ? AppColors.sosRed : AppColors.primaryLight),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  smsDispatch['status'] == 'DELIVERED'
                                      ? 'Twilio SMS Gateway: DISPATCHED to cellular network'
                                      : (smsDispatch['status'] == 'FAILED'
                                          ? 'Twilio Gateway: ${smsDispatch['message'] ?? "Dispatch Failed"}'
                                          : 'Twilio Gateway not configured. Auto-dispatched via Device SIM SMS.'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: smsDispatch['status'] == 'DELIVERED'
                                        ? AppColors.safeGreen
                                        : (smsDispatch['status'] == 'FAILED' ? AppColors.sosRed : AppColors.primaryLight),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (contacts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'No contacts configured. Go to Contacts tab to add trusted phone numbers.',
                            style: TextStyle(color: AppColors.cautionYellow, fontSize: 12),
                          ),
                        )
                      else
                        ...contacts.map((c) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${c.name} (${c.relationship})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        c.phone,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primaryLight,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      // SMS via SIM
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2563EB),
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: const Icon(Icons.sms, size: 15),
                                          label: const Text('SMS (SIM)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          onPressed: () => _launchSms(context, c.phone, alertMessage),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // WhatsApp
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF16A34A),
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: const Icon(Icons.chat, size: 15),
                                          label: const Text('WhatsApp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          onPressed: () => _launchWhatsApp(context, c.phone, alertMessage),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Call
                                      IconButton.filled(
                                        style: IconButton.styleFrom(
                                          backgroundColor: AppColors.border,
                                          padding: const EdgeInsets.all(8),
                                        ),
                                        icon: const Icon(Icons.phone, size: 16, color: AppColors.textPrimary),
                                        tooltip: 'Call Contact',
                                        onPressed: () => _launchCall(context, c.phone),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Live Tracking Link Card
                if (trackingUrl != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.link, color: AppColors.primaryLight, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Live Tracking Link (Open in any Browser)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: SelectableText(
                            trackingUrl,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryLight,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Cloudflare Tunnel Reachability Diagnostic Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: ((smsDispatch?['public_tunnel_active'] != false && trackingUrl.startsWith('https://'))
                                    ? AppColors.safeGreen
                                    : AppColors.cautionYellow)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (smsDispatch?['public_tunnel_active'] != false && trackingUrl.startsWith('https://'))
                                  ? AppColors.safeGreen
                                  : AppColors.cautionYellow,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                (smsDispatch?['public_tunnel_active'] != false && trackingUrl.startsWith('https://'))
                                    ? Icons.public
                                    : Icons.wifi_outlined,
                                size: 14,
                                color: (smsDispatch?['public_tunnel_active'] != false && trackingUrl.startsWith('https://'))
                                    ? AppColors.safeGreen
                                    : AppColors.cautionYellow,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  (smsDispatch?['public_tunnel_active'] != false && trackingUrl.startsWith('https://'))
                                      ? 'Public Mobile Data: Live tracking link is active & reachable on 4G/5G.'
                                      : (smsDispatch?['tunnel_diagnostic'] ?? 'Local Wi-Fi link. Start Cloudflare tunnel for mobile data access.'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: (smsDispatch?['public_tunnel_active'] != false && trackingUrl.startsWith('https://'))
                                        ? AppColors.safeGreen
                                        : AppColors.cautionYellow,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryLight,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copy Link', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: trackingUrl));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Live tracking link copied to clipboard!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.border),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.message, size: 16, color: AppColors.textPrimary),
                                label: const Text('Copy Alert Text', style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: alertMessage));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Complete SOS alert message copied to clipboard!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Real GPS Telemetry Details Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Incident Telemetry',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const Divider(color: AppColors.border, height: 20),
                      _detailRow('Alert Type', emergency?.alertType ?? 'SOS_MANUAL'),
                      _detailRow('Severity', emergency?.severity ?? 'CRITICAL'),
                      _detailRow(
                        'Live GPS Position',
                        '${emergency?.latitude.toStringAsFixed(5) ?? "Acquiring..."}, ${emergency?.longitude.toStringAsFixed(5) ?? "..."}',
                      ),
                      _detailRow(
                        'GPS Accuracy',
                        '±${emergency?.accuracy.toStringAsFixed(1) ?? "10.0"} meters',
                      ),
                      _detailRow('AI Risk Score', '${emergency?.riskScore.toStringAsFixed(1) ?? "85.0"} / 100'),
                      _detailRow('Status', emergency?.status ?? 'ACTIVE'),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Action Buttons
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.safeGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    await ref.read(emergencyProvider.notifier).resolveEmergency();
                    if (context.mounted) {
                      context.go('/home');
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("I'M SAFE – RESOLVE EMERGENCY", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),

                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await ref.read(emergencyProvider.notifier).cancelEmergency();
                    if (context.mounted) {
                      context.go('/home');
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.textMuted),
                  label: const Text('CANCEL ALERT (False Alarm)', style: TextStyle(color: AppColors.textMuted)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }
}

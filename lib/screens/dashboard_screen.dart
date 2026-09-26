import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/system_status.dart';
import '../services/telecom_service.dart';

class DashboardScreen extends StatelessWidget {
  final SystemStatus? status;
  final VoidCallback onRefresh;
  final Function(int) onNavigateTab;

  const DashboardScreen({
    super.key,
    required this.status,
    required this.onRefresh,
    required this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final s = status;
    final theme = Theme.of(context);

    if (s == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isApi34 = s.isApi34Plus;
    final isRoleHeld = s.roleHeld;
    final hasAudioInterception = s.permissions['CALL_AUDIO_INTERCEPTION'] == true;
    final hasRecordAudio = s.permissions['RECORD_AUDIO'] == true;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner / Header
          Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer.withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cell_tower, color: theme.colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AOSP Call Streaming Lab PoC',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Text(
                              'Telecom SYSTEM_CALL_STREAMING & Audio Interception Stack',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: onRefresh,
                        tooltip: 'Refresh Status',
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Key Status Matrix
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System & Privileges Assessment',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildStatusRow(
                    context,
                    title: 'Android API Version',
                    subtitle: 'Requires API 34+ (Android 14) for CallStreamingService',
                    badgeText: 'API ${s.sdkInt} (Android ${s.release})',
                    isSuccess: isApi34,
                    icon: Icons.android,
                  ),
                  const Divider(height: 20),
                  _buildStatusRow(
                    context,
                    title: 'SYSTEM_CALL_STREAMING Role',
                    subtitle: isRoleHeld
                        ? 'Package holds the call streaming system role'
                        : 'Requires CTS role-qualification bypass via ADB',
                    badgeText: isRoleHeld ? 'HELD' : (s.roleAvailable ? 'AVAILABLE (NOT HELD)' : 'UNAVAILABLE'),
                    isSuccess: isRoleHeld,
                    icon: Icons.security,
                  ),
                  const Divider(height: 20),
                  _buildStatusRow(
                    context,
                    title: 'CALL_AUDIO_INTERCEPTION',
                    subtitle: hasAudioInterception
                        ? 'Protected permission granted'
                        : 'Requires role qualification or signature grant',
                    badgeText: hasAudioInterception ? 'GRANTED' : 'RESTRICTED',
                    isSuccess: hasAudioInterception,
                    icon: Icons.graphic_eq,
                  ),
                  const Divider(height: 20),
                  _buildStatusRow(
                    context,
                    title: 'RECORD_AUDIO Permission',
                    subtitle: hasRecordAudio ? 'Runtime mic permission active' : 'Dangerous permission not yet granted',
                    badgeText: hasRecordAudio ? 'GRANTED' : 'DENIED',
                    isSuccess: hasRecordAudio,
                    icon: Icons.mic,
                  ),
                  const Divider(height: 20),
                  _buildStatusRow(
                    context,
                    title: 'Telecom PhoneAccount',
                    subtitle: s.isPhoneAccountRegistered
                        ? 'CTS test account registered with TelecomManager'
                        : 'Phone account not yet registered',
                    badgeText: s.isPhoneAccountRegistered ? 'REGISTERED' : 'UNREGISTERED',
                    isSuccess: s.isPhoneAccountRegistered,
                    icon: Icons.contact_phone,
                  ),
                  const Divider(height: 20),
                  _buildStatusRow(
                    context,
                    title: 'CallStreamingService Binding',
                    subtitle: 'Current streaming state: ${s.streamingState}',
                    badgeText: s.isServiceBound ? 'BOUND' : 'IDLE',
                    isSuccess: s.isServiceBound,
                    icon: Icons.stream,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Target Architecture Diagram Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.architecture, color: Colors.indigo),
                      const SizedBox(width: 8),
                      Text(
                        'Target 2-Phone Calling Architecture',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '''PRIMARY PHONE
  SIM / PSTN Cellular Call
        |
        v
  Android Telecom Framework
        |  SYSTEM_CALL_STREAMING
        v
  CallStreamingService (This App)
        +-------------------------+
        |                         |
        v                         ^
  Audio Extraction       Remote Mic Injection
  (Rx Downlink)          (Tx Uplink)
        |                         ^
        +-----------> <-----------+
               Network Transport (WebRTC / UDP)
                     |
                     v
SECONDARY PHONE
  Speaker (Rx) + Microphone (Tx)''',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.greenAccent,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Purpose: Evaluate whether Android\'s native CallStreamingService and AudioManager can intercept cellular/GSM voice streams without OEM-specific proprietary hooks.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quick Action Triggers
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lab Quick Actions',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.security),
                        label: const Text('Request Permissions'),
                        onPressed: () async {
                          final res = await TelecomService().requestRuntimePermissions();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Permissions request completed: $res')),
                          );
                          onRefresh();
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.assignment_ind),
                        label: const Text('Request System Role'),
                        onPressed: () async {
                          final res = await TelecomService().requestRole();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(res['error'] ?? 'Role intent launched')),
                          );
                          onRefresh();
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.app_registration),
                        label: Text(s.isPhoneAccountRegistered ? 'Unregister PhoneAccount' : 'Register PhoneAccount'),
                        onPressed: () async {
                          if (s.isPhoneAccountRegistered) {
                            await TelecomService().unregisterPhoneAccount();
                          } else {
                            await TelecomService().registerPhoneAccount();
                          }
                          onRefresh();
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondaryContainer,
                        ),
                        icon: const Icon(Icons.checklist),
                        label: const Text('Run 6-Phase PoC'),
                        onPressed: () => onNavigateTab(1),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade50,
                          foregroundColor: Colors.teal.shade800,
                        ),
                        icon: const Icon(Icons.terminal),
                        label: const Text('View ADB Commands'),
                        onPressed: () => onNavigateTab(3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badgeText,
    required bool isSuccess,
    required IconData icon,
  }) {
    final color = isSuccess ? Colors.green : Colors.orange.shade800;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.BorderSide(color: color.withOpacity(0.4)),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

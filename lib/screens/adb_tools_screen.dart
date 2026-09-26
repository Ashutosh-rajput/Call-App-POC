import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/system_status.dart';

class AdbToolsScreen extends StatelessWidget {
  final SystemStatus? status;

  const AdbToolsScreen({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final pkg = 'com.example.call_test';
    final role = 'android.app.role.SYSTEM_CALL_STREAMING';
    final theme = Theme.of(context);

    final commands = [
      {
        'title': '1. Grant SYSTEM_CALL_STREAMING (Role Qualification Bypass)',
        'desc': 'CTS mechanism: Bypasses role qualification check to allow our test app to hold the call streaming role.',
        'cmd': 'adb shell cmd role add-role-holder --bypass-role-qualification $role $pkg',
      },
      {
        'title': '2. Grant CALL_AUDIO_INTERCEPTION & Telephony Permissions',
        'desc': 'Grants the protected call audio interception and mic recording permissions directly via package manager.',
        'cmd': 'adb shell pm grant $pkg android.permission.CALL_AUDIO_INTERCEPTION\n'
               'adb shell pm grant $pkg android.permission.RECORD_AUDIO\n'
               'adb shell pm grant $pkg android.permission.READ_PHONE_STATE\n'
               'adb shell pm grant $pkg android.permission.MANAGE_OWN_CALLS',
      },
      {
        'title': '3. Verify Active Role Holders',
        'desc': 'Confirms that com.example.call_test is listed as the active role holder for SYSTEM_CALL_STREAMING.',
        'cmd': 'adb shell cmd role get-role-holders $role',
      },
      {
        'title': '4. Inspect Telecom State (dumpsys telecom)',
        'desc': 'Dumps active calls, call streaming connections, and phone accounts in the Telecom subsystem.',
        'cmd': 'adb shell dumpsys telecom',
      },
      {
        'title': '5. Inspect Audio Routing & Modes (dumpsys audio)',
        'desc': 'Verifies audio devices, active recording configs, and audio modes (MODE_IN_CALL / MODE_IN_COMMUNICATION).',
        'cmd': 'adb shell dumpsys audio',
      },
      {
        'title': '6. Remove Role & Restore Default',
        'desc': 'Removes the test role holder when testing is finished.',
        'cmd': 'adb shell cmd role remove-role-holder --bypass-role-qualification $role $pkg',
      },
    ];

    final fullScript = commands.map((c) => '# ${c['title']}\n${c['cmd']}').join('\n\n');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: Colors.teal.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.teal.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.terminal, color: Colors.teal.shade900, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ADB Automation & Role Bypass Toolkit',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'On Android 14+, SYSTEM_CALL_STREAMING is a protected system role. Use these commands via ADB to reproduce the official AOSP CTS test setup on your device or emulator.',
                  style: TextStyle(fontSize: 12, color: Colors.teal.shade800),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade800,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.copy_all, size: 18),
                  label: const Text('Copy Complete Setup Script'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: fullScript));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied complete ADB script to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        ...commands.map((c) {
          final title = c['title']!;
          final desc = c['desc']!;
          final cmd = c['cmd']!;

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cmd,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('Copy Command', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: cmd));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied "$title" command')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }
}

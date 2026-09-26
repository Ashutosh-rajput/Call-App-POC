import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/system_status.dart';
import '../services/telecom_service.dart';

class PocPhasesScreen extends StatefulWidget {
  final SystemStatus? status;
  final VoidCallback onRefresh;

  const PocPhasesScreen({
    super.key,
    required this.status,
    required this.onRefresh,
  });

  @override
  State<PocPhasesScreen> createState() => _PocPhasesScreenState();
}

class _PocPhasesScreenState extends State<PocPhasesScreen> {
  final TelecomService _telecomService = TelecomService();

  // Diagnostics Data
  bool _isProbingAudio = false;
  Map<dynamic, dynamic>? _audioDiagReport;

  // Live Audio Capture Data
  bool _isLiveCapturing = false;
  int _selectedAudioSource = 7; // VOICE_COMMUNICATION
  double _currentRmsDb = -100.0;
  int _currentMaxAmp = 0;
  int _capturedFrames = 0;

  // Network Transport Benchmark Data
  bool _isBenchmarkingTransport = false;
  Map<dynamic, dynamic>? _transportStats;
  final TextEditingController _targetHostController = TextEditingController(text: '127.0.0.1');
  final TextEditingController _targetPortController = TextEditingController(text: '19876');

  @override
  void initState() {
    super.initState();
    _telecomService.audioLevelStream.listen((data) {
      if (mounted) {
        setState(() {
          _currentRmsDb = (data['rmsDb'] as num?)?.toDouble() ?? -100.0;
          _currentMaxAmp = (data['maxAmp'] as num?)?.toInt() ?? 0;
          _capturedFrames = (data['frame'] as num?)?.toInt() ?? 0;
        });
      }
    });

    _telecomService.transportStream.listen((event) {
      if (mounted) {
        setState(() {
          _transportStats = event['stats'] as Map<dynamic, dynamic>?;
          if (event['type'] == 'TRANSPORT_COMPLETE') {
            _isBenchmarkingTransport = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _targetHostController.dispose();
    _targetPortController.dispose();
    super.dispose();
  }

  Future<void> _runAudioDiagnostics() async {
    setState(() => _isProbingAudio = true);
    try {
      final report = await _telecomService.runAudioDiagnostics();
      setState(() {
        _audioDiagReport = report;
        _isProbingAudio = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio diagnostics probe completed successfully')),
      );
    } catch (e) {
      setState(() => _isProbingAudio = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error running audio diagnostics: $e')),
      );
    }
  }

  Future<void> _toggleLiveAudioCapture() async {
    if (_isLiveCapturing) {
      await _telecomService.stopLiveAudioCapture();
      setState(() => _isLiveCapturing = false);
    } else {
      final success = await _telecomService.startLiveAudioCapture(sourceId: _selectedAudioSource);
      if (success) {
        setState(() => _isLiveCapturing = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start AudioRecord capture. Check permissions.')),
        );
      }
    }
  }

  Future<void> _toggleTransportBenchmark() async {
    if (_isBenchmarkingTransport) {
      await _telecomService.stopNetworkTransportBenchmark();
      setState(() => _isBenchmarkingTransport = false);
    } else {
      final port = int.tryParse(_targetPortController.text) ?? 19876;
      final started = await _telecomService.startNetworkTransportBenchmark(
        host: _targetHostController.text.trim(),
        port: port,
        durationSeconds: 10,
      );
      if (started) {
        setState(() => _isBenchmarkingTransport = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Intro Card
        Card(
          elevation: 0,
          color: Colors.blueGrey.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.blueGrey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.science, color: Colors.blueGrey.shade800, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Controlled Laboratory PoC (6 Phases)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Step-by-step verification based on AOSP CTS CallStreamingService architecture.',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Phase 1 Card
        _buildPhaseCard(
          phaseNum: 'Phase 1',
          title: 'Component & Manifest Verification',
          statusText: (s != null && s.isApi34Plus) ? 'Verified' : 'Ready for test',
          statusColor: Colors.green,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirms CallStreamingService & ConnectionService declarations in AndroidManifest.xml:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              _buildCodeSnippet(
                '<service android:name=".CtsCallStreamingService"\n'
                '    android:permission="android.permission.BIND_CALL_STREAMING_SERVICE"\n'
                '    android:exported="true">\n'
                '    <intent-filter>\n'
                '        <action android:name="android.telecom.CallStreamingService" />\n'
                '    </intent-filter>\n'
                '</service>',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    s?.isApi34Plus == true ? Icons.check_circle : Icons.warning_amber,
                    color: s?.isApi34Plus == true ? Colors.green : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Target SDK: 34 (Android 14) • Min SDK: 28',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Phase 2 Card
        _buildPhaseCard(
          phaseNum: 'Phase 2',
          title: 'Role Allocation & Bypass Qualification',
          statusText: s?.roleHeld == true ? 'Role Active' : 'Requires Bypass',
          statusColor: s?.roleHeld == true ? Colors.green : Colors.orange,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'In AOSP CTS, the test environment explicitly calls setByPassRoleQualification(true) to assign android.app.role.SYSTEM_CALL_STREAMING to the test package.',
                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              ),
              const SizedBox(height: 8),
              _buildCodeSnippet(s?.adbCommands['addRole'] ?? 'adb shell cmd role add-role-holder --bypass-role-qualification android.app.role.SYSTEM_CALL_STREAMING com.example.call_test'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy ADB Command'),
                    onPressed: () {
                      final cmd = s?.adbCommands['addRole'] ?? '';
                      Clipboard.setData(ClipboardData(text: cmd));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied ADB role command to clipboard')),
                      );
                    },
                  ),
                  ElevatedButton(
                    onPressed: widget.onRefresh,
                    child: const Text('Verify Status'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Phase 3 Card
        _buildPhaseCard(
          phaseNum: 'Phase 3',
          title: 'AudioManager & Audio Source Deep Probe',
          statusText: _audioDiagReport != null ? 'Probed' : 'Pending Run',
          statusColor: _audioDiagReport != null ? Colors.blue : Colors.grey,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inspects AudioManager capabilities, audio devices, and tests AudioRecord initialization on VoIP and Telephony sources (MIC, VOICE_CALL, VOICE_DOWNLINK, VOICE_UPLINK, VOICE_COMMUNICATION).',
                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: _isProbingAudio
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow),
                label: Text(_isProbingAudio ? 'Probing Audio Sources...' : 'Execute Audio Diagnostics Probe'),
                onPressed: _isProbingAudio ? null : _runAudioDiagnostics,
              ),
              if (_audioDiagReport != null) ...[
                const SizedBox(height: 12),
                _buildAudioProbeResultsWidget(_audioDiagReport!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Phase 4 Card
        _buildPhaseCard(
          phaseNum: 'Phase 4',
          title: 'Cellular / PSTN Call Interception Assessment',
          statusText: 'Analysis',
          statusColor: Colors.deepPurple,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'AOSP Architectural Finding',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• VOICE_COMMUNICATION (7): Works for VoIP / self-managed calls on all devices.\n'
                      '• VOICE_CALL (4) / VOICE_DOWNLINK (3): Requires CAPTURE_AUDIO_OUTPUT (privileged signature permission) or OEM HAL support. On consumer ROMs, attempting to record raw PSTN without SYSTEM_CALL_STREAMING throws SecurityException.\n'
                      '• With SYSTEM_CALL_STREAMING + CALL_AUDIO_INTERCEPTION: Telecom bridges the call session into CallStreamingService via StreamingCall.',
                      style: TextStyle(fontSize: 12, color: Colors.brown.shade900, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Phase 5 Card
        _buildPhaseCard(
          phaseNum: 'Phase 5',
          title: 'Live Audio Extraction & Level Monitor',
          statusText: _isLiveCapturing ? 'Capturing' : 'Idle',
          statusColor: _isLiveCapturing ? Colors.red : Colors.grey,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Test real-time PCM audio buffer extraction from selected audio source:',
                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Source:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedAudioSource,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: 7, child: Text('VOICE_COMMUNICATION (7)')),
                        DropdownMenuItem(value: 1, child: Text('MIC (1)')),
                        DropdownMenuItem(value: 4, child: Text('VOICE_CALL (4 - GSM)')),
                        DropdownMenuItem(value: 3, child: Text('VOICE_DOWNLINK (3 - Rx)')),
                        DropdownMenuItem(value: 2, child: Text('VOICE_UPLINK (2 - Tx)')),
                      ],
                      onChanged: _isLiveCapturing ? null : (val) {
                        if (val != null) setState(() => _selectedAudioSource = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Live Level Meter
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(
                          'RMS Level: ${_currentRmsDb.toStringAsFixed(1)} dB',
                          style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                        ),
                        Text(
                          'Peak: $_currentMaxAmp | Frames: $_capturedFrames',
                          style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: ((_currentRmsDb + 80.0) / 80.0).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade800,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _currentRmsDb > -10.0 ? Colors.redAccent : Colors.greenAccent,
                      ),
                      minHeight: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isLiveCapturing ? Colors.red.shade700 : Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(_isLiveCapturing ? Icons.stop : Icons.play_arrow),
                label: Text(_isLiveCapturing ? 'Stop Audio Capture' : 'Start Audio Capture & Level Monitor'),
                onPressed: _toggleLiveAudioCapture,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Phase 6 Card
        _buildPhaseCard(
          phaseNum: 'Phase 6',
          title: 'Network Transport Simulator (2-Phone Bridge)',
          statusText: _isBenchmarkingTransport ? 'Benchmarking' : 'Ready',
          statusColor: _isBenchmarkingTransport ? Colors.blue : Colors.grey,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Simulates transmitting 20ms audio frame packets to a secondary phone or local loopback to measure latency, jitter, and packet loss.',
                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _targetHostController,
                      decoration: const InputDecoration(
                        labelText: 'Target Host / IP',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _targetPortController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'UDP Port',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_transportStats != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem('Latency (RTT)', '${((_transportStats!['avgLatency'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)} ms'),
                          _buildStatItem('Jitter', '${((_transportStats!['jitter'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} ms'),
                          _buildStatItem('Packet Loss', '${((_transportStats!['loss'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)}%'),
                          _buildStatItem('Bitrate', '${((_transportStats!['bitrate'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)} kbps'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Packets: Sent ${_transportStats!['sent']} / Recv ${_transportStats!['recv']} • Status: ${_transportStats!['status']}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBenchmarkingTransport ? Colors.red.shade700 : Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(_isBenchmarkingTransport ? Icons.stop : Icons.network_check),
                label: Text(_isBenchmarkingTransport ? 'Stop Benchmark' : 'Run 10s Transport Benchmark'),
                onPressed: _toggleTransportBenchmark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildPhaseCard({
    required String phaseNum,
    required String title,
    required String statusText,
    required Color statusColor,
    required Widget content,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Text(
                    phaseNum,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.indigo.shade900),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildCodeSnippet(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        code,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.lightGreenAccent),
      ),
    );
  }

  Widget _buildAudioProbeResultsWidget(Map<dynamic, dynamic> report) {
    final sources = report['sourcesProbe'] as List<dynamic>? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Probed Audio Sources:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        ...sources.map((item) {
          final m = item as Map<dynamic, dynamic>;
          final name = m['name']?.toString() ?? '';
          final status = m['status']?.toString() ?? '';
          final message = m['message']?.toString() ?? '';
          final isSuccess = status == 'SUCCESS';

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isSuccess ? Colors.green.shade300 : Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(
                      status,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(message, style: TextStyle(fontSize: 11, color: Colors.grey.shade800)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

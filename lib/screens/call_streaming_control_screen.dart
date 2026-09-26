import 'dart:async';
import 'package:flutter/material.dart';
import '../models/system_status.dart';
import '../services/telecom_service.dart';

class CallStreamingControlScreen extends StatefulWidget {
  final SystemStatus? status;
  final VoidCallback onRefresh;

  const CallStreamingControlScreen({
    super.key,
    required this.status,
    required this.onRefresh,
  });

  @override
  State<CallStreamingControlScreen> createState() => _CallStreamingControlScreenState();
}

class _CallStreamingControlScreenState extends State<CallStreamingControlScreen> {
  final TelecomService _telecomService = TelecomService();
  final TextEditingController _callerNameController = TextEditingController(text: 'Lab Caller');
  final TextEditingController _phoneNumberController = TextEditingController(text: 'tel:5550199');
  int _callDirection = 1; // 1: Incoming, 2: Outgoing

  bool _isProcessing = false;
  String _activeStreamingState = 'IDLE';
  Map<dynamic, dynamic>? _lastCallExtras;
  Timer? _streamingTimer;
  int _streamingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _activeStreamingState = widget.status?.streamingState ?? 'IDLE';

    _telecomService.eventStream.listen((event) {
      if (!mounted) return;
      final type = event['type'];
      final data = event['data'] as Map<dynamic, dynamic>? ?? {};

      setState(() {
        if (type == 'STREAMING_STARTED') {
          _activeStreamingState = data['state']?.toString() ?? 'STREAMING';
          _lastCallExtras = data['extras'] as Map<dynamic, dynamic>?;
          _startStreamingTimer();
        } else if (type == 'STREAMING_STOPPED') {
          _activeStreamingState = 'STOPPED';
          _stopStreamingTimer();
        } else if (type == 'STREAMING_STATE_CHANGED') {
          _activeStreamingState = data['state']?.toString() ?? _activeStreamingState;
        }
      });
      widget.onRefresh();
    });
  }

  @override
  void didUpdateWidget(CallStreamingControlScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != null) {
      _activeStreamingState = widget.status!.streamingState;
    }
  }

  @override
  void dispose() {
    _streamingTimer?.cancel();
    _callerNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  void _startStreamingTimer() {
    _streamingTimer?.cancel();
    _streamingSeconds = 0;
    _streamingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _streamingSeconds++);
    });
  }

  void _stopStreamingTimer() {
    _streamingTimer?.cancel();
    _streamingTimer = null;
  }

  Future<void> _handleCreateCall() async {
    setState(() => _isProcessing = true);
    try {
      final res = await _telecomService.createTestCall(
        callerName: _callerNameController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        direction: _callDirection,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Call created')),
      );
    } finally {
      setState(() => _isProcessing = false);
      widget.onRefresh();
    }
  }

  Future<void> _handleStartStreaming() async {
    setState(() => _isProcessing = true);
    try {
      final res = await _telecomService.startCallStreaming();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Streaming command sent')),
      );
    } finally {
      setState(() => _isProcessing = false);
      widget.onRefresh();
    }
  }

  Future<void> _handleStopStreaming() async {
    setState(() => _isProcessing = true);
    try {
      final res = await _telecomService.stopCallStreaming();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Streaming stopped')),
      );
    } finally {
      setState(() => _isProcessing = false);
      widget.onRefresh();
    }
  }

  Future<void> _handleDisconnectCall() async {
    setState(() => _isProcessing = true);
    try {
      final res = await _telecomService.disconnectActiveCall();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Call disconnected')),
      );
      _stopStreamingTimer();
    } finally {
      setState(() => _isProcessing = false);
      widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final theme = Theme.of(context);
    final isStreamingActive = _activeStreamingState == 'STREAMING' || _activeStreamingState == 'STATE_STREAMING';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Live Call Streaming Status Monitor
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: isStreamingActive
                    ? [Colors.blueGrey.shade900, Colors.teal.shade900]
                    : [Colors.blueGrey.shade900, Colors.blueGrey.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isStreamingActive ? Colors.greenAccent : Colors.orangeAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Streaming State: $_activeStreamingState',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    if (isStreamingActive)
                      Text(
                        '${_streamingSeconds ~/ 60}:${(_streamingSeconds % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Service Binding: ${s?.isServiceBound == true ? "BOUND (Active)" : "IDLE"}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  'Active Telecom Call: ${s?.hasActiveTelecomCall == true ? "YES (CallId: ${s?.activeCallId ?? "active"})" : "NONE"}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (_lastCallExtras != null && _lastCallExtras!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('StreamingCall Extras:', style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _lastCallExtras.toString(),
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Test Call Creator Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Telecom Call Setup (addCall)',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Registers test call in Android Telecom with SUPPORTS_STREAM capability.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _callerNameController,
                  decoration: const InputDecoration(
                    labelText: 'Caller Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Phone URI (e.g. tel:5550199)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Direction:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Incoming'),
                      selected: _callDirection == 1,
                      onSelected: (val) {
                        if (val) setState(() => _callDirection = 1);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Outgoing'),
                      selected: _callDirection == 2,
                      onSelected: (val) {
                        if (val) setState(() => _callDirection = 2);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: _isProcessing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.phone),
                  label: const Text('Add Test Call (TelecomManager)'),
                  onPressed: _isProcessing ? null : _handleCreateCall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Call Streaming Action Controls
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2. Call Streaming Execution (startCallStreaming)',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'CTS step 7: Invokes CallControl.startCallStreaming() to bind CallStreamingService.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.stream),
                      label: const Text('Start Call Streaming'),
                      onPressed: (s?.hasActiveTelecomCall == true && !_isProcessing) ? _handleStartStreaming : null,
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Streaming'),
                      onPressed: (isStreamingActive && !_isProcessing) ? _handleStopStreaming : null,
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.call_end),
                      label: const Text('Disconnect Call'),
                      onPressed: (s?.hasActiveTelecomCall == true && !_isProcessing) ? _handleDisconnectCall : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

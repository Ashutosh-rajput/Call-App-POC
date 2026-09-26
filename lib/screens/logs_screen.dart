import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/telecom_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final TelecomService _telecomService = TelecomService();
  final List<Map<String, String>> _logs = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String _filterLevel = 'ALL';
  bool _autoScroll = true;
  String _logFilePath = 'Loading log file path...';

  @override
  void initState() {
    super.initState();
    _loadInitialLogs();
    _loadLogFilePath();

    _telecomService.logStream.listen((entry) {
      if (mounted) {
        setState(() {
          _logs.add(entry);
        });
        if (_autoScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
            }
          });
        }
      }
    });
  }

  Future<void> _loadLogFilePath() async {
    final path = await _telecomService.getLogFilePath();
    if (mounted) {
      setState(() => _logFilePath = path);
    }
  }

  Future<void> _exportLogFile() async {
    final path = await _telecomService.exportLogsToFile();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logs captured to file:\n$path')),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialLogs() async {
    final list = await _telecomService.getLogs();
    if (mounted) {
      setState(() {
        _logs.clear();
        _logs.addAll(list);
      });
      if (_autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    }
  }

  Future<void> _clearLogs() async {
    await _telecomService.clearLogs();
    setState(() {
      _logs.clear();
    });
  }

  void _copyAllLogs() {
    final text = _logs.map((l) => '[${l['time']}] [${l['level']}] [${l['tag']}] ${l['message']}').join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All logs copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _logs.where((l) {
      if (_filterLevel != 'ALL' && l['level'] != _filterLevel) return false;
      if (query.isNotEmpty) {
        final content = '${l['tag']} ${l['message']}'.toLowerCase();
        if (!content.contains(query)) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Persistent Log File Status Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.blueGrey.shade900,
          child: Row(
            children: [
              const Icon(Icons.description, color: Colors.greenAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Log File: $_logFilePath',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16, color: Colors.greenAccent),
                tooltip: 'Copy File Path',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _logFilePath));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Log file path copied')),
                  );
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.save, size: 16, color: Colors.cyanAccent),
                tooltip: 'Flush Logs to File',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _exportLogFile,
              ),
            ],
          ),
        ),
        // Controls Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              // Filter dropdown
              DropdownButton<String>(
                value: _filterLevel,
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Levels')),
                  DropdownMenuItem(value: 'INFO', child: Text('INFO')),
                  DropdownMenuItem(value: 'WARN', child: Text('WARN')),
                  DropdownMenuItem(value: 'ERROR', child: Text('ERROR')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _filterLevel = val);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search logs...',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.pause, size: 20),
                tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll PAUSED',
                onPressed: () => setState(() => _autoScroll = !_autoScroll),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                tooltip: 'Copy Logs',
                onPressed: _copyAllLogs,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Clear Logs',
                onPressed: _clearLogs,
              ),
            ],
          ),
        ),

        // Logs Viewer
        Expanded(
          child: Container(
            color: Colors.black,
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No logs matching filter',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final l = filtered[index];
                      final level = l['level'] ?? 'INFO';
                      final color = switch (level) {
                        'ERROR' => Colors.redAccent,
                        'WARN' => Colors.amberAccent,
                        _ => Colors.lightGreenAccent,
                      };

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                            children: [
                              TextSpan(
                                text: '[${l['time']}] ',
                                style: const TextStyle(color: Colors.white54),
                              ),
                              TextSpan(
                                text: '[$level] ',
                                style: TextStyle(color: color, fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: '[${l['tag']}] ',
                                style: const TextStyle(color: Colors.cyanAccent),
                              ),
                              TextSpan(
                                text: l['message'],
                                style: const TextStyle(color: Colors.white),
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
    );
  }
}

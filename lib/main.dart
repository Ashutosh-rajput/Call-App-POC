import 'package:flutter/material.dart';
import 'models/system_status.dart';
import 'services/telecom_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/poc_phases_screen.dart';
import 'screens/call_streaming_control_screen.dart';
import 'screens/adb_tools_screen.dart';
import 'screens/logs_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CallStreamingTestApp());
}

class CallStreamingTestApp extends StatelessWidget {
  const CallStreamingTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AOSP Call Streaming Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final TelecomService _telecomService = TelecomService();
  int _currentIndex = 0;
  SystemStatus? _status;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();

    _telecomService.eventStream.listen((event) {
      if (mounted) {
        _refreshStatus();
      }
    });
  }

  Future<void> _refreshStatus() async {
    setState(() => _isLoading = true);
    final status = await _telecomService.getSystemStatus();
    if (mounted) {
      setState(() {
        _status = status;
        _isLoading = false;
      });
    }
  }

  void _onNavigateTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final isStreamingActive = status?.streamingState == 'STREAMING' || status?.streamingState == 'STATE_STREAMING';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Call Streaming Test App',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              status != null ? '${status.deviceModel} (API ${status.sdkInt})' : 'Connecting Telecom stack...',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          if (isStreamingActive)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.stream, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text('STREAMING', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          IconButton(
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: _refreshStatus,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(
            status: _status,
            onRefresh: _refreshStatus,
            onNavigateTab: _onNavigateTab,
          ),
          PocPhasesScreen(
            status: _status,
            onRefresh: _refreshStatus,
          ),
          CallStreamingControlScreen(
            status: _status,
            onRefresh: _refreshStatus,
          ),
          AdbToolsScreen(
            status: _status,
          ),
          const LogsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onNavigateTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science),
            label: '6-Phase PoC',
          ),
          NavigationDestination(
            icon: Icon(Icons.phone_in_talk_outlined),
            selectedIcon: Icon(Icons.phone_in_talk),
            label: 'Call Stream',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal),
            label: 'ADB Tools',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: 'Logs',
          ),
        ],
      ),
    );
  }
}

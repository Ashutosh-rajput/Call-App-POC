class SystemStatus {
  final int sdkInt;
  final String release;
  final String deviceModel;
  final bool isApi34Plus;
  final bool roleAvailable;
  final bool roleHeld;
  final bool isPhoneAccountRegistered;
  final bool isPhoneAccountEnabled;
  final bool isServiceBound;
  final String streamingState;
  final bool hasActiveStreamingCall;
  final bool hasActiveTelecomCall;
  final String? activeCallId;
  final Map<String, bool> permissions;
  final Map<String, dynamic> adbCommands;

  SystemStatus({
    required this.sdkInt,
    required this.release,
    required this.deviceModel,
    required this.isApi34Plus,
    required this.roleAvailable,
    required this.roleHeld,
    required this.isPhoneAccountRegistered,
    required this.isPhoneAccountEnabled,
    required this.isServiceBound,
    required this.streamingState,
    required this.hasActiveStreamingCall,
    required this.hasActiveTelecomCall,
    this.activeCallId,
    required this.permissions,
    required this.adbCommands,
  });

  factory SystemStatus.fromMap(Map<dynamic, dynamic> map) {
    final rawPerms = map['permissions'] as Map<dynamic, dynamic>? ?? {};
    final perms = <String, bool>{};
    rawPerms.forEach((k, v) {
      perms[k.toString()] = v == true;
    });

    final rawAdb = map['adbCommands'] as Map<dynamic, dynamic>? ?? {};
    final adb = <String, dynamic>{};
    rawAdb.forEach((k, v) {
      adb[k.toString()] = v;
    });

    return SystemStatus(
      sdkInt: map['sdkInt'] as int? ?? 0,
      release: map['release'] as String? ?? 'Unknown',
      deviceModel: map['deviceModel'] as String? ?? 'Unknown',
      isApi34Plus: map['isApi34Plus'] == true,
      roleAvailable: map['roleAvailable'] == true,
      roleHeld: map['roleHeld'] == true,
      isPhoneAccountRegistered: map['isPhoneAccountRegistered'] == true,
      isPhoneAccountEnabled: map['isPhoneAccountEnabled'] == true,
      isServiceBound: map['isServiceBound'] == true,
      streamingState: map['streamingState'] as String? ?? 'IDLE',
      hasActiveStreamingCall: map['hasActiveStreamingCall'] == true,
      hasActiveTelecomCall: map['hasActiveTelecomCall'] == true,
      activeCallId: map['activeCallId'] as String?,
      permissions: perms,
      adbCommands: adb,
    );
  }
}

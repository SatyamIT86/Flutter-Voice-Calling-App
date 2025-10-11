// lib/services/agora_service.dart

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';

class AgoraService {
  RtcEngine? _engine;
  bool _isInitialized = false;

  // Callbacks
  Function(int uid, int elapsed)? onUserJoined;
  Function(int uid, int reason)? onUserOffline;
  Function(RtcConnection connection, int remoteUid, int elapsed)?
  onJoinChannelSuccess;
  Function(RtcConnection connection, RtcStats stats)? onLeaveChannel;

  // Initialize Agora Engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request permissions
    await _requestPermissions();

    // Create Agora Engine
    _engine = createAgoraRtcEngine();

    await _engine!.initialize(
      RtcEngineContext(
        appId: AppConstants.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    // Register event handlers
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print('Local user ${connection.localUid} joined channel');
          onJoinChannelSuccess?.call(connection, connection.localUid!, elapsed);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print('Remote user $remoteUid joined');
          onUserJoined?.call(remoteUid, elapsed);
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              print('Remote user $remoteUid left channel');
              onUserOffline?.call(remoteUid, reason.value());
            },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          print('Left channel');
          onLeaveChannel?.call(connection, stats);
        },
        onError: (ErrorCodeType err, String msg) {
          print('Agora Error: $err - $msg');
        },
      ),
    );

    _isInitialized = true;
  }

  // Request necessary permissions
  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.camera].request();
  }

  // Join a voice channel
  Future<void> joinChannel({
    required String channelName,
    required String token,
    required int uid,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Enable audio
    await _engine!.enableAudio();

    // Set audio profile for voice call
    await _engine!.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioChatroom,
    );

    // Join channel
    await _engine!.joinChannel(
      token: token.isEmpty ? "" : token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        autoSubscribeAudio: true,
      ),
    );
  }

  // Leave channel
  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
  }

  // Mute/Unmute local audio
  Future<void> muteLocalAudio(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  // Enable/Disable speaker
  Future<void> setSpeakerphone(bool enabled) async {
    await _engine?.setEnableSpeakerphone(enabled);
  }

  // Switch audio route (earpiece/speaker)
  Future<void> switchAudioRoute() async {
    await _engine?.setDefaultAudioRouteToSpeakerphone(true);
  }

  // Get call quality stats
  Future<void> enableAudioVolumeIndication({
    int interval = 200,
    int smooth = 3,
    bool reportVad = true,
  }) async {
    await _engine?.enableAudioVolumeIndication(
      interval: interval,
      smooth: smooth,
      reportVad: reportVad,
    );
  }

  // Adjust recording volume
  Future<void> adjustRecordingSignalVolume(int volume) async {
    await _engine?.adjustRecordingSignalVolume(volume);
  }

  // Adjust playback volume
  Future<void> adjustPlaybackSignalVolume(int volume) async {
    await _engine?.adjustPlaybackSignalVolume(volume);
  }

  // Destroy engine
  Future<void> destroy() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    _isInitialized = false;
  }

  // Check if engine is initialized
  bool get isInitialized => _isInitialized;

  // Get engine instance (for advanced usage)
  RtcEngine? get engine => _engine;
}

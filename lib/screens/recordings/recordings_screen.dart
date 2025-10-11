import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import '../../models/recording_model.dart';
import '../../services/recording_service.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final _recordingService = RecordingService();
  final _authService = AuthService();
  final _audioPlayer = AudioPlayer();

  List<RecordingModel> _recordings = [];
  bool _isLoading = true;
  String? _playingRecordingId;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _playingRecordingId = null;
        _isPlaying = false;
        _currentPosition = Duration.zero;
      });
    });
  }

  Future<void> _loadRecordings() async {
    setState(() => _isLoading = true);

    try {
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        final recordings = await _recordingService.getRecordings(userId);
        setState(() {
          _recordings = recordings;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading recordings: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _playRecording(RecordingModel recording) async {
    try {
      if (_playingRecordingId == recording.id && _isPlaying) {
        await _audioPlayer.pause();
      } else if (_playingRecordingId == recording.id && !_isPlaying) {
        await _audioPlayer.resume();
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(recording.localPath));
        setState(() {
          _playingRecordingId = recording.id;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error playing recording: $e')));
      }
    }
  }

  Future<void> _stopRecording() async {
    await _audioPlayer.stop();
    setState(() {
      _playingRecordingId = null;
      _isPlaying = false;
      _currentPosition = Duration.zero;
    });
  }

  void _deleteRecording(RecordingModel recording) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: Text(
          'Are you sure you want to delete this recording from ${recording.contactName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final userId = _authService.currentUser?.uid;
                if (userId != null) {
                  // Stop playback if this recording is playing
                  if (_playingRecordingId == recording.id) {
                    await _stopRecording();
                  }

                  await _recordingService.deleteRecording(
                    userId: userId,
                    recordingId: recording.id,
                    localPath: recording.localPath,
                    cloudUrl: recording.cloudUrl,
                  );

                  _loadRecordings();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Recording deleted')),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting recording: $e')),
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.dangerColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showTranscript(RecordingModel recording) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transcript'),
        content: SingleChildScrollView(
          child: Text(
            recording.transcript ?? 'No transcript available',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recordings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mic_none,
                    size: 80,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recordings yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRecordings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _recordings.length,
                itemBuilder: (context, index) {
                  final recording = _recordings[index];
                  final isPlaying =
                      _playingRecordingId == recording.id && _isPlaying;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryColor.withOpacity(
                              0.1,
                            ),
                            child: Icon(
                              Icons.mic,
                              color: AppColors.primaryColor,
                            ),
                          ),
                          title: Text(
                            recording.contactName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                DateFormat(
                                  'MMM dd, yyyy HH:mm',
                                ).format(recording.recordedAt),
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${recording.formattedDuration} • ${recording.formattedSize}',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            icon: const Icon(Icons.more_vert),
                            itemBuilder: (context) => [
                              if (recording.transcript != null)
                                const PopupMenuItem(
                                  value: 'transcript',
                                  child: Row(
                                    children: [
                                      Icon(Icons.text_snippet_outlined),
                                      SizedBox(width: 8),
                                      Text('View Transcript'),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'transcript') {
                                _showTranscript(recording);
                              } else if (value == 'delete') {
                                _deleteRecording(recording);
                              }
                            },
                          ),
                        ),

                        // Player Controls (only show for playing recording)
                        if (_playingRecordingId == recording.id)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              children: [
                                // Progress Bar
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                  ),
                                  child: Slider(
                                    value: _currentPosition.inSeconds
                                        .toDouble(),
                                    max: _totalDuration.inSeconds.toDouble(),
                                    activeColor: AppColors.primaryColor,
                                    onChanged: (value) async {
                                      await _audioPlayer.seek(
                                        Duration(seconds: value.toInt()),
                                      );
                                    },
                                  ),
                                ),

                                // Time Labels
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(_currentPosition),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(_totalDuration),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Play/Pause Button
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_playingRecordingId == recording.id)
                                IconButton(
                                  onPressed: _stopRecording,
                                  icon: const Icon(Icons.stop),
                                  color: AppColors.dangerColor,
                                ),
                              IconButton(
                                onPressed: () => _playRecording(recording),
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                ),
                                color: AppColors.primaryColor,
                                iconSize: 32,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

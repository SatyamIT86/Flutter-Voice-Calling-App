import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transcript_model.dart';
import '../../services/transcript_service.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';

class TranscriptsScreen extends StatefulWidget {
  const TranscriptsScreen({super.key});

  @override
  State<TranscriptsScreen> createState() => _TranscriptsScreenState();
}

class _TranscriptsScreenState extends State<TranscriptsScreen> {
  final TranscriptService _transcriptService = TranscriptService();
  final AuthService _authService = AuthService();

  List<TranscriptModel> _transcripts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTranscripts();
  }

  Future<void> _loadTranscripts() async {
    setState(() => _isLoading = true);
    try {
      final userId = _authService.currentUser?.uid;
      if (userId != null) {
        final transcripts = await _transcriptService.getTranscripts(userId);
        setState(() {
          _transcripts = transcripts;
        });
        print('📄 Loaded ${_transcripts.length} transcripts');
      }
    } catch (e) {
      print('Error loading transcripts: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showTranscript(TranscriptModel transcript) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Call Transcript',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'With: ${transcript.contactName}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              'Date: ${DateFormat('MMM dd, yyyy HH:mm').format(transcript.createdAt)}',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            Text(
              'Duration: ${transcript.formattedDuration}',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  transcript.transcript,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTranscript(TranscriptModel transcript) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transcript'),
        content: Text(
            'Are you sure you want to delete the transcript with ${transcript.contactName}?'),
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
                  await _transcriptService.deleteTranscript(
                    userId,
                    transcript.id,
                  );
                  _loadTranscripts();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transcript deleted')),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting transcript: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Call Transcripts'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transcripts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.transcribe_outlined,
                        size: 80,
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No transcripts yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enable transcript during calls to see them here',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTranscripts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _transcripts.length,
                    itemBuilder: (context, index) {
                      final transcript = _transcripts[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primaryColor.withOpacity(0.1),
                            child: Icon(
                              Icons.transcribe,
                              color: AppColors.primaryColor,
                            ),
                          ),
                          title: Text(
                            transcript.contactName,
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
                                DateFormat('MMM dd, yyyy HH:mm')
                                    .format(transcript.createdAt),
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Duration: ${transcript.formattedDuration}',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getPreview(transcript.transcript),
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            icon: const Icon(Icons.more_vert),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Row(
                                  children: [
                                    Icon(Icons.visibility_outlined),
                                    SizedBox(width: 8),
                                    Text('View Transcript'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline,
                                        color: Colors.red),
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
                              if (value == 'view') {
                                _showTranscript(transcript);
                              } else if (value == 'delete') {
                                _deleteTranscript(transcript);
                              }
                            },
                          ),
                          onTap: () => _showTranscript(transcript),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _getPreview(String transcript) {
    if (transcript.length <= 100) return transcript;
    return '${transcript.substring(0, 100)}...';
  }
}

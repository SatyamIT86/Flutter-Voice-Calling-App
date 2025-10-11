import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/call_log_model.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';

class CallLogsScreen extends StatefulWidget {
  const CallLogsScreen({super.key});

  @override
  State<CallLogsScreen> createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> {
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;

  Stream<List<CallLogModel>> _getCallLogsStream() {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.callLogsCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CallLogModel.fromMap(doc.data()))
              .toList();
        });
  }

  IconData _getCallIcon(CallType callType) {
    switch (callType) {
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.missed:
        return Icons.call_missed;
    }
  }

  Color _getCallColor(CallType callType) {
    switch (callType) {
      case CallType.incoming:
        return AppColors.successColor;
      case CallType.outgoing:
        return AppColors.primaryColor;
      case CallType.missed:
        return AppColors.dangerColor;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(timestamp);
    } else {
      return DateFormat('MMM dd').format(timestamp);
    }
  }

  void _showCallDetails(CallLogModel callLog) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Contact Name
                Text(
                  callLog.callType == CallType.outgoing
                      ? callLog.receiverName
                      : callLog.callerName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Call Details
                _buildDetailRow(
                  icon: Icons.access_time,
                  label: 'Duration',
                  value: callLog.formattedDuration,
                ),
                _buildDetailRow(
                  icon: Icons.calendar_today,
                  label: 'Date',
                  value: DateFormat(
                    'MMM dd, yyyy HH:mm',
                  ).format(callLog.timestamp),
                ),
                _buildDetailRow(
                  icon: _getCallIcon(callLog.callType),
                  label: 'Type',
                  value: callLog.callType
                      .toString()
                      .split('.')
                      .last
                      .toUpperCase(),
                ),

                // Transcript Section
                if (callLog.transcript != null &&
                    callLog.transcript!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Transcript',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      callLog.transcript!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryColor, size: 20),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
      body: StreamBuilder<List<CallLogModel>>(
        stream: _getCallLogsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final callLogs = snapshot.data ?? [];

          if (callLogs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 80,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No call history yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: callLogs.length,
            itemBuilder: (context, index) {
              final callLog = callLogs[index];
              final contactName = callLog.callType == CallType.outgoing
                  ? callLog.receiverName
                  : callLog.callerName;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: ListTile(
                  onTap: () => _showCallDetails(callLog),
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: _getCallColor(
                      callLog.callType,
                    ).withOpacity(0.1),
                    child: Icon(
                      _getCallIcon(callLog.callType),
                      color: _getCallColor(callLog.callType),
                    ),
                  ),
                  title: Text(
                    contactName,
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
                        callLog.callType
                            .toString()
                            .split('.')
                            .last
                            .toUpperCase(),
                        style: TextStyle(
                          color: _getCallColor(callLog.callType),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Duration: ${callLog.formattedDuration}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTimestamp(callLog.timestamp),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (callLog.recordingUrl != null) ...[
                        const SizedBox(height: 4),
                        Icon(
                          Icons.mic,
                          size: 16,
                          color: AppColors.primaryColor,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lab_managment_system/core/localization/app_localizations.dart';
import '../../services/user_service.dart';
import '../../services/patient_service.dart';
import 'package:intl/intl.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  final UserService _userService = UserService();
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _userService.getPendingRequests();
      if (!mounted) return;
      setState(() => _requests = requests);
    } catch (e) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      final errorMsg = loc != null ? loc.errorLoadingRequests(e.toString()) : 'Error loading requests: $e';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMsg)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleApprove(Map<String, dynamic> request) async {
    if (request['request_type'] == 'Password Recovery') {
      _showResetPasswordDialog(request);
    } else if (request['request_type'] == 'Unapprove Test') {
      final details = request['details'] as String? ?? '';
      final match = RegExp(r'patient_test_id:(\d+)').firstMatch(details);
      if (match != null) {
        int ptId = int.parse(match.group(1)!);
        await PatientService().updateTestStatus(ptId, 'Completed');
      }
      await _userService.updateRequestStatus(request['id'], 'Approved');
      if (!mounted) return;
      _loadRequests();
    } else {
      await _userService.updateRequestStatus(request['id'], 'Approved');
      if (!mounted) return;
      _loadRequests();
    }
  }

  Future<void> _handleReject(int requestId) async {
    await _userService.updateRequestStatus(requestId, 'Rejected');
    if (!mounted) return;
    _loadRequests();
  }

  void _showResetPasswordDialog(Map<String, dynamic> request) {
    final l10n = AppLocalizations.of(context)!;
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.resetPasswordFor(request['username'] ?? '')),
        content: TextField(
          controller: passwordController,
          decoration: InputDecoration(
            labelText: l10n.newPassword,
            border: const OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              passwordController.dispose();
            },
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.isNotEmpty) {
                final newPass = passwordController.text;
                await _userService.resetUserPassword(
                  request['username'],
                  newPass,
                );
                await _userService.updateRequestStatus(
                  request['id'],
                  'Approved',
                );
                if (!mounted) return;
                if (!dialogCtx.mounted) return;

                Navigator.of(dialogCtx).pop();
                passwordController.dispose();
                _loadRequests();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.passwordResetSuccess)),
                );
              }
            },
            child: Text(l10n.resetAndApprove),
          ),
        ],
      ),
    );
  }

  String _formatRequestType(String? rawType, AppLocalizations l10n) {
    if (rawType == 'Password Recovery') {
      return l10n.passwordRecovery;
    } else if (rawType == 'Unapprove Test') {
      return l10n.unapproveTest;
    }
    return rawType ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminRequests),
        actions: [
          IconButton(onPressed: _loadRequests, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? Center(
              child: Text(
                l10n.noPendingRequests,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                final date = DateTime.parse(req['created_at']);
                final isPasswordRecovery = req['request_type'] == 'Password Recovery';
                final displayType = _formatRequestType(req['request_type'], l10n);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isPasswordRecovery
                          ? Colors.orange.withValues(alpha: 0.2)
                          : theme.colorScheme.primary.withValues(alpha: 0.15),
                      child: Icon(
                        isPasswordRecovery
                            ? Icons.lock_outlined
                            : Icons.edit_note,
                        color: isPasswordRecovery
                            ? Colors.orange
                            : theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      '$displayType - ${req['username']}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      l10n.requestedOn(DateFormat('yyyy-MM-dd HH:mm').format(date)),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _handleApprove(req),
                          tooltip: l10n.approve,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _handleReject(req['id']),
                          tooltip: l10n.reject,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}


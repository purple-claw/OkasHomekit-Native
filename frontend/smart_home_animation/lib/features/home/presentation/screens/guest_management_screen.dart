import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/theme/sh_colors.dart';
import 'package:smart_home_animation/services/token_auth_service.dart';

class GuestManagementScreen extends StatefulWidget {
  final bool showAppBar;

  const GuestManagementScreen({super.key, this.showAppBar = true});

  @override
  State<GuestManagementScreen> createState() => _GuestManagementScreenState();
}

class _GuestManagementScreenState extends State<GuestManagementScreen> {
  static const int _maxGuestDurationMinutes = 30 * 24 * 60;
  List<Map<String, dynamic>> _guests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  Future<void> _loadGuests() async {
    setState(() { _loading = true; _error = null; });
    try {
      _guests = await context.read<TokenAuthService>().listGuests();
    } catch (error) {
      _error = error is AuthApiException ? error.message : 'Unable to load guests.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openGuestForm({Map<String, dynamic>? guest}) async {
    final editing = guest != null;
    final name = TextEditingController(text: guest?['label'] as String? ?? '');
    DateTime selectedDate = _initialExpiryDate(guest);
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: SHColors.cardColor,
          title: Text(editing ? 'Update guest' : 'Add guest', style: const TextStyle(color: SHColors.textColor)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: name,
              style: const TextStyle(color: SHColors.textColor),
              decoration: const InputDecoration(
                labelText: 'Guest name',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: SHColors.primary)),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined, color: SHColors.primary),
              title: const Text('Access valid until', style: TextStyle(color: SHColors.textColor)),
              subtitle: Text(_formatDate(selectedDate), style: const TextStyle(color: Colors.white70)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white70),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: SHColors.primary,
                        surface: SHColors.cardColor,
                        onSurface: SHColors.textColor,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setDialogState(() => selectedDate = picked);
              },
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: SHColors.primary),
              onPressed: () => Navigator.pop(dialogContext, {
                'label': name.text,
                'duration': _durationMinutesUntilEndOfDay(selectedDate),
              }),
              child: Text(editing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
    if (request == null) {
      name.dispose();
      return;
    }
    try {
      Map<String, dynamic>? result;
      if (editing) {
        result = await context.read<TokenAuthService>().updateGuest(
          guestId: guest['id'] as String,
          label: request['label'] as String? ?? 'Guest',
          durationMinutes: request['duration'] as int,
        );
      } else {
        result = await context.read<TokenAuthService>().createGuest(
          label: request['label'] as String? ?? 'Guest',
          durationMinutes: request['duration'] as int,
        );
      }
      await _loadGuests();
      if (!mounted || editing) return;
      final token = result['guestToken'] as String;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: SHColors.cardColor,
          title: const Text('Share this guest token now', style: TextStyle(color: SHColors.textColor)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('It is shown once and cannot be recovered later.', style: TextStyle(color: SHColors.textColor)),
            const SizedBox(height: 12),
            SelectableText(token, style: const TextStyle(color: SHColors.primary, fontSize: 22, fontWeight: FontWeight.bold)),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is AuthApiException ? error.message : 'Could not save guest.')));
    } finally {
      name.dispose();
    }
  }

  Future<void> _toggleGuestStatus(Map<String, dynamic> guest) async {
    final isRevoked = guest['revokedAt'] != null;
    try {
      if (isRevoked) {
        // Enable guest (unrevoke)
        await context.read<TokenAuthService>().updateGuest(
          guestId: guest['id'] as String,
          label: guest['label'] as String? ?? 'Guest',
          durationMinutes: 1440, 
        );
      } else {
        // Revoke guest
        await context.read<TokenAuthService>().revokeGuest(guest['id'] as String);
      }
      await _loadGuests();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is AuthApiException ? error.message : 'Could not update guest status.')));
    }
  }

  Future<void> _deleteGuest(Map<String, dynamic> guest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SHColors.cardColor,
        title: const Text('Delete guest', style: TextStyle(color: SHColors.textColor)),
        content: Text('Delete ${guest['label'] as String? ?? 'this guest'} access?', style: const TextStyle(color: SHColors.textColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await context.read<TokenAuthService>().deleteGuest(guest['id'] as String);
    await _loadGuests();
  }

  DateTime _initialExpiryDate(Map<String, dynamic>? guest) {
    final parsed = DateTime.tryParse(guest?['expiresAt']?.toString() ?? '');
    if (parsed == null || parsed.isBefore(DateTime.now())) {
      return DateTime.now().add(const Duration(days: 1));
    }
    return parsed.toLocal();
  }

  static int _durationMinutesUntilEndOfDay(DateTime date) {
    final expiry = DateTime(date.year, date.month, date.day, 23, 59, 59);
    final minutes = expiry.difference(DateTime.now()).inMinutes;
    if (minutes < 5) return 5;
    if (minutes > _maxGuestDurationMinutes) return _maxGuestDurationMinutes;
    return minutes;
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  static String _formatExpiry(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null ? 'Unknown' : _formatDate(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: widget.showAppBar ? AppBar(title: const Text('Guest access')) : null,
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _openGuestForm(),
      backgroundColor: SHColors.primary,
      icon: const Icon(Icons.person_add),
      label: const Text('Add guest'),
    ),
    body: RefreshIndicator(
      onRefresh: _loadGuests,
      child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _guests.isEmpty
                  ? const [
                      SizedBox(height: 120),
                      Icon(Icons.group_outlined, size: 56, color: Colors.white54),
                      SizedBox(height: 16),
                      Center(child: Text('No guest access tokens yet.', style: TextStyle(color: Colors.white70))),
                    ]
                  : _guests.map((guest) {
                final revoked = guest['revokedAt'] != null;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: SHColors.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: revoked ? Colors.redAccent.withOpacity(0.1) : SHColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(revoked ? Icons.person_off : Icons.person, color: revoked ? Colors.redAccent : SHColors.primary),
                    ),
                    title: Text(guest['label'] as String? ?? 'Guest', style: const TextStyle(color: SHColors.textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text(revoked ? 'Revoked' : 'Expires: ${_formatExpiry(guest['expiresAt'])}', style: const TextStyle(color: Colors.white70)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            revoked ? Icons.check_circle_outline : Icons.block,
                            color: revoked ? Colors.greenAccent : Colors.orangeAccent,
                          ),
                          tooltip: revoked ? 'Enable guest' : 'Revoke guest',
                          onPressed: () => _toggleGuestStatus(guest),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: SHColors.primary),
                          tooltip: 'Update guest',
                          onPressed: revoked ? null : () => _openGuestForm(guest: guest),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Delete guest',
                          onPressed: () => _deleteGuest(guest),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    ),
  );
}

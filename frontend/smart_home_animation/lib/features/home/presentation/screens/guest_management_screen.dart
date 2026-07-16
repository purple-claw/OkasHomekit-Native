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

  Future<void> _addGuest() async {
    final name = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add guest'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Guest name')),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Access valid until'),
              subtitle: Text(_formatDate(selectedDate)),
              trailing: const Icon(Icons.chevron_right),
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
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'label': name.text,
                'duration': _durationMinutesUntilEndOfDay(selectedDate),
              }),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    if (request == null) return;
    try {
      final result = await context.read<TokenAuthService>().createGuest(
        label: request['label'] as String? ?? 'Guest',
        durationMinutes: request['duration'] as int,
      );
      await _loadGuests();
      if (!mounted) return;
      final token = result['guestToken'] as String;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Share this guest token now'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('It is shown once and cannot be recovered later.'),
            const SizedBox(height: 12),
            SelectableText(token),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is AuthApiException ? error.message : 'Could not create guest.')));
    }
  }

  Future<void> _revoke(String id) async {
    await context.read<TokenAuthService>().revokeGuest(id);
    await _loadGuests();
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
      onPressed: _addGuest,
      backgroundColor: SHColors.primary,
      icon: const Icon(Icons.person_add),
      label: const Text('Add guest'),
    ),
    body: RefreshIndicator(
      onRefresh: _loadGuests,
      child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _guests.isEmpty
                  ? const [
                      SizedBox(height: 120),
                      Icon(Icons.group_outlined, size: 56, color: Colors.white54),
                      SizedBox(height: 16),
                      Center(child: Text('No guest access tokens yet.')),
                    ]
                  : _guests.map((guest) {
                final revoked = guest['revokedAt'] != null;
                return Card(child: ListTile(
                  leading: Icon(revoked ? Icons.person_off : Icons.person, color: revoked ? Colors.red : null),
                  title: Text(guest['label'] as String? ?? 'Guest'),
                  subtitle: Text(revoked ? 'Revoked' : 'Expires: ${_formatExpiry(guest['expiresAt'])}'),
                  trailing: revoked ? null : IconButton(icon: const Icon(Icons.block), tooltip: 'Revoke access', onPressed: () => _revoke(guest['id'] as String)),
                ));
              }).toList(),
            ),
    ),
  );
}

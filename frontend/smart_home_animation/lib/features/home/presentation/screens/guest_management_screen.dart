import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/services/token_auth_service.dart';

class GuestManagementScreen extends StatefulWidget {
  const GuestManagementScreen({super.key});

  @override
  State<GuestManagementScreen> createState() => _GuestManagementScreenState();
}

class _GuestManagementScreenState extends State<GuestManagementScreen> {
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
    var duration = 60;
    final values = [15, 60, 24 * 60, 7 * 24 * 60, 30 * 24 * 60];
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add guest'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Guest name')),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: duration,
              decoration: const InputDecoration(labelText: 'Access duration'),
              items: values.map((minutes) => DropdownMenuItem(value: minutes, child: Text(_durationLabel(minutes)))).toList(),
              onChanged: (value) => setDialogState(() => duration = value!),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, {'label': name.text, 'duration': duration}), child: const Text('Create')),
          ],
        ),
      ),
    );
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

  static String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    if (minutes < 24 * 60) return '${minutes ~/ 60} hour${minutes == 60 ? '' : 's'}';
    return '${minutes ~/ (24 * 60)} day${minutes == 24 * 60 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Guest access')),
    floatingActionButton: FloatingActionButton.extended(onPressed: _addGuest, icon: const Icon(Icons.person_add), label: const Text('Add guest')),
    body: RefreshIndicator(
      onRefresh: _loadGuests,
      child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _guests.map((guest) {
                final revoked = guest['revokedAt'] != null;
                return Card(child: ListTile(
                  leading: Icon(revoked ? Icons.person_off : Icons.person, color: revoked ? Colors.red : null),
                  title: Text(guest['label'] as String? ?? 'Guest'),
                  subtitle: Text(revoked ? 'Revoked' : 'Expires: ${guest['expiresAt']}'),
                  trailing: revoked ? null : IconButton(icon: const Icon(Icons.block), tooltip: 'Revoke access', onPressed: () => _revoke(guest['id'] as String)),
                ));
              }).toList(),
            ),
    ),
  );
}

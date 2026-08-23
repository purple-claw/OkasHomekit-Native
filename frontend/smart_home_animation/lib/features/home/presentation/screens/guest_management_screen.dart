import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/glass_panel.dart';
import 'package:smart_home_animation/core/theme/sh_colors.dart';
import 'package:smart_home_animation/services/token_auth_service.dart';

class GuestManagementScreen extends StatefulWidget {
  final bool showAppBar;

  const GuestManagementScreen({super.key, this.showAppBar = true});

  @override
  State<GuestManagementScreen> createState() => _GuestManagementScreenState();
}

class _GuestManagementScreenState extends State<GuestManagementScreen> {
  static const double _guestCardWidth = 168; // ponytail: +18px for 4th eye icon (was 150 -> 165 -> 168 for row fit)
  PageController? _guestCarouselController;
  static const int _maxGuestDurationMinutes = 30 * 24 * 60;
  List<Map<String, dynamic>> _guests = [];
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ponytail: fixed card width -> page == card width so peek stays tight
    _guestCarouselController ??= PageController(
      viewportFraction: _guestCardWidth / MediaQuery.sizeOf(context).width,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  Future<void> _loadGuests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _guests = await context.read<TokenAuthService>().listGuests();
    } catch (error) {
      _error = error is AuthApiException
          ? error.message
          : 'Unable to load guests.';
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
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => FrostedAlertDialog(
          backgroundColor: SHColors.elevatedCardColor,
          title: Text(
            editing ? 'Update guest' : 'Add guest',
            style: const TextStyle(
              color: SHColors.textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                style: const TextStyle(color: SHColors.textColor),
                decoration: const InputDecoration(
                  labelText: 'Guest name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: SHColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.calendar_today_outlined,
                  color: SHColors.primary,
                ),
                title: const Text(
                  'Access valid until',
                  style: TextStyle(color: SHColors.textColor),
                ),
                subtitle: Text(
                  _formatDate(selectedDate),
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                ),
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
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
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
    if (!mounted) return;
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
        builder: (context) => FrostedAlertDialog(
          backgroundColor: SHColors.elevatedCardColor,
          title: const Text(
            'Share this guest token now',
            style: TextStyle(
              color: SHColors.textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You can view this token again anytime via the eye icon on the guest card.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              SelectableText(
                token,
                style: const TextStyle(
                  color: SHColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: token));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token copied.')));
              },
              child: const Text('Copy', style: TextStyle(color: SHColors.primary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Done',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AuthApiException
                  ? error.message
                  : 'Could not save guest.',
            ),
          ),
        );
      }
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
        await context.read<TokenAuthService>().revokeGuest(
          guest['id'] as String,
        );
      }
      await _loadGuests();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AuthApiException
                  ? error.message
                  : 'Could not update guest status.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteGuest(Map<String, dynamic> guest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => FrostedAlertDialog(
        backgroundColor: SHColors.elevatedCardColor,
        title: const Text(
          'Delete guest',
          style: TextStyle(color: SHColors.textColor),
        ),
        content: Text(
          'Delete ${guest['label'] as String? ?? 'this guest'} access?',
          style: const TextStyle(color: SHColors.textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await context.read<TokenAuthService>().deleteGuest(guest['id'] as String);
    await _loadGuests();
  }

  Future<void> _viewGuestToken(Map<String, dynamic> guest) async {
    final label = guest['label'] as String? ?? 'Guest';
    try {
      final token = await context.read<TokenAuthService>().getGuestToken(guest['id'] as String);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (context) => FrostedAlertDialog(
          backgroundColor: SHColors.elevatedCardColor,
          title: Text(
            '$label — Guest token',
            style: const TextStyle(color: SHColors.textColor, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share this token with the guest. It stays valid until expiry or revocation.', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: SelectableText(
                  token,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SHColors.primary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 3),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: token));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token copied to clipboard.')));
              },
              child: const Text('Copy', style: TextStyle(color: SHColors.primary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is AuthApiException ? error.message : 'Could not load token.')));
    }
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

  /// Add Guest frosted pill — shown in both the empty state and
  /// the guest-carousel state.
  Widget _addGuestPill() => Center(
    child: GlassPanel(
      radius: 18,
      blur: 7,
      fillColor: Colors.white.withValues(alpha: 0.04),
      onTap: () => _openGuestForm(),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add, size: 20, color: SHColors.primary),
            SizedBox(width: 8),
            Text(
              'Add Guest',
              style: TextStyle(
                color: SHColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: widget.showAppBar
        ? AppBar(title: const Text('Guest access'))
        : null,
    body: RefreshIndicator(
      onRefresh: _loadGuests,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: SHColors.primary),
            )
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: _guests.isEmpty
                  ? [
                      SizedBox(height: 120),
                      Icon(
                        Icons.group_outlined,
                        size: 56,
                        color: Colors.white54,
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          'No guest access tokens yet.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      SizedBox(height: 24),
                      _addGuestPill(),
                    ]
                  : [
                      // Guest cards carousel (same pattern as the room
                      // showcase: active card + peek of the neighbours).
                      SizedBox(
                        height: 192, // ponytail: +14px for 4-icon row (was 178)
                        child: PageView.builder(
                          controller: _guestCarouselController!,
                          clipBehavior: Clip.none,
                          padEnds: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _guests.length,
                          itemBuilder: (context, index) {
                            final guest = _guests[index];
                            final carousel = _guestCarouselController!;
                            return AnimatedBuilder(
                              animation: carousel,
                              child: Center(
                                child: SizedBox(
                                  width: _guestCardWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    child: _GuestCard(
                                      guest: guest,
                                      onView: () => _viewGuestToken(guest),
                                      onEdit: guest['revokedAt'] != null
                                          ? null
                                          : () => _openGuestForm(guest: guest),
                                      onDelete: () => _deleteGuest(guest),
                                      onToggle: () => _toggleGuestStatus(guest),
                                    ),
                                  ),
                                ),
                              ),
                              builder: (context, child) {
                                final page =
                                    carousel.hasClients && carousel.page != null
                                    ? carousel.page!
                                    : index.toDouble();
                                final distance = (page - index).abs().clamp(
                                  0.0,
                                  1.0,
                                );
                                return Transform.scale(
                                  alignment: Alignment.center,
                                  scale: 1 - (distance * 0.14),
                                  child: child,
                                );
                              },
                            );
                          },
                        ),
                      ),
                      // Add Guest: centered frosted pill below the cards.
                      const SizedBox(height: 18),
                      _addGuestPill(),
                    ],
            ),
    ),
  );
}

/// Figma guest card: teal avatar disc, name, orange expiry, action icons.
class _GuestCard extends StatelessWidget {
  const _GuestCard({
    required this.guest,
    this.onView,
    this.onEdit,
    this.onDelete,
    this.onToggle,
  });

  final Map<String, dynamic> guest;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final revoked = guest['revokedAt'] != null;
    return GlassPanel(
      radius: 16,
      blur: 6,
      fillColor: Colors.white.withValues(alpha: 0.039),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: SHColors.guestAvatar,
                shape: BoxShape.circle,
              ),
              child: Icon(
                revoked ? Icons.person_off : Icons.person,
                color: Colors.white.withValues(alpha: 0.9),
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              guest['label'] as String? ?? 'Guest',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              revoked
                  ? 'Revoked'
                  : 'Expires: ${_GuestManagementScreenState._formatExpiry(guest['expiresAt'])}',
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: revoked ? SHColors.figmaRed : SHColors.figmaOrange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GlassIconButton(
                  icon: Icons.visibility_outlined,
                  color: Colors.white70,
                  tooltip: 'View token',
                  size: 26,
                  iconSize: 18,
                  onPressed: onView,
                ),
                const SizedBox(width: 6),
                GlassIconButton(
                  icon: Icons.edit_outlined,
                  color: SHColors.primary,
                  tooltip: 'Update guest',
                  size: 26,
                  iconSize: 18,
                  onPressed: onEdit,
                ),
                const SizedBox(width: 6),
                GlassIconButton(
                  icon: Icons.delete_outline,
                  color: SHColors.figmaRed,
                  tooltip: 'Delete guest',
                  size: 26,
                  iconSize: 17,
                  onPressed: onDelete,
                ),
                const SizedBox(width: 6),
                Opacity(
                  opacity: 0.65,
                  child: Transform.flip(
                    flipY: true,
                    child: GlassIconButton(
                      icon: revoked ? Icons.check_circle_outline : Icons.block,
                      color: revoked ? SHColors.green : SHColors.figmaRed,
                      tooltip: revoked ? 'Enable guest' : 'Revoke guest',
                      size: 26,
                      iconSize: 18,
                      onPressed: onToggle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

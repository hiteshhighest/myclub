import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../clubs/public_clubs_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../updates/updates_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  int _previousIndex = 0;
  bool _checkingMessages = false;

  late final List<Widget> _screens = const [
    HomeScreen(),
    PublicClubsScreen(),
    UpdatesScreen(),
    ProfileScreen(),
  ];

  final List<IconData> _icons = const [
    Icons.groups_outlined,
    Icons.explore_outlined,
    Icons.dynamic_feed_outlined,
    Icons.person_outline_rounded,
  ];

  final List<IconData> _selectedIcons = const [
    Icons.groups_rounded,
    Icons.explore_rounded,
    Icons.dynamic_feed_rounded,
    Icons.person_rounded,
  ];

  final List<String> _labels = const ['Home', 'Clubs', 'Updates', 'Me'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showPendingAdminMessages(),
    );
  }

  Future<void> _showPendingAdminMessages() async {
    if (_checkingMessages ||
        Supabase.instance.client.auth.currentUser == null) {
      return;
    }

    _checkingMessages = true;
    final db = Supabase.instance.client;
    try {
      final rows = await db.rpc('get_my_admin_messages') as List? ?? [];
      for (final raw in rows) {
        if (!mounted) return;
        final message = Map<String, dynamic>.from(raw as Map);
        final acknowledged = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.campaign_outlined, size: 34),
            title: Text(message['title']?.toString() ?? 'A message from Klubb'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(message['body']?.toString() ?? ''),
                  if ((message['link_url']?.toString() ?? '')
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(
                            message['link_url'].toString(),
                          );
                          if (uri == null ||
                              !uri.hasAuthority ||
                              (uri.scheme != 'https' && uri.scheme != 'http')) {
                            return;
                          }
                          final opened = await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                          if (!opened && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not open this link.'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open link'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Okay, got it'),
              ),
            ],
          ),
        );

        if (acknowledged == true) {
          await db.rpc(
            'acknowledge_admin_message',
            params: {'p_message_id': message['id']},
          );
        } else {
          break;
        }
      }
    } catch (error) {
      debugPrint('Could not load Klubb admin messages: $error');
    } finally {
      _checkingMessages = false;
    }
  }

  void _selectSection(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = index;
    });
  }

  Widget _buildSection(int index) {
    final selected = _selectedIndex == index;
    final movingForward = _selectedIndex > _previousIndex;
    final restingOffset = index == _selectedIndex
        ? Offset.zero
        : Offset(movingForward ? -0.035 : 0.035, 0);

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !selected,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          opacity: selected ? 1 : 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            offset: restingOffset,
            child: TickerMode(enabled: selected, child: _screens[index]),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterItem(BuildContext context, int index) {
    final selected = _selectedIndex == index;
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: _labels[index],
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _selectSection(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? MyClubTheme.accentCoral.withValues(alpha: 0.28)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: AnimatedScale(
                      scale: selected ? 1 : .92,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: Icon(
                          selected ? _selectedIcons[index] : _icons[index],
                          key: ValueKey(selected),
                          size: 22,
                          color: selected
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    child: Text(_labels[index], maxLines: 1),
                  ),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    width: selected ? 18 : 4,
                    height: 3,
                    decoration: BoxDecoration(
                      color: selected ? colors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.10),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              for (var index = 0; index < _labels.length; index++)
                _buildFooterItem(context, index),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          for (var index = 0; index < _screens.length; index++)
            _buildSection(index),
        ],
      ),
      bottomNavigationBar: _buildFooter(context),
    );
  }
}

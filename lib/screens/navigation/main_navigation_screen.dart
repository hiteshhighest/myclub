import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _checkingMessages = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showPendingAdminMessages(),
    );
  }

  Future<void> _showPendingAdminMessages() async {
    if (_checkingMessages || Supabase.instance.client.auth.currentUser == null)
      return;
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
            title: Text(
              message['title']?.toString() ?? 'A message from MyClub',
            ),
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
                              (uri.scheme != 'https' && uri.scheme != 'http'))
                            return;
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
      debugPrint('Could not load MyClub admin messages: $error');
    } finally {
      _checkingMessages = false;
    }
  }

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

  final List<String> _labels = const ['Home', 'Discover', 'Updates', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant
                    .withValues(alpha: 0.45),
              ),
            ),
          ),
          child: Row(
            children: List.generate(_labels.length, (index) {
              final selected = _selectedIndex == index;
              final colors = Theme.of(context).colorScheme;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? colors.primary.withValues(alpha: 0.13)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            selected ? _selectedIcons[index] : _icons[index],
                            size: 22,
                            color: selected
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _labels[index],
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: selected
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

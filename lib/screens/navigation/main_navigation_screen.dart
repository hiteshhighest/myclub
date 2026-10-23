import 'package:flutter/material.dart';

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


import 'package:flutter/material.dart';

import '../clubs/public_clubs_screen.dart';
import '../home/home_screen.dart';
import '../events/events_screen.dart';
import '../announcements/announcements_screen.dart';
import '../profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens = const [
    HomeScreen(),
    PublicClubsScreen(),
    EventsScreen(),
    AnnouncementsScreen(),
    ProfileScreen(),
  ];

  final List<IconData> _icons = const [
    Icons.groups_outlined,
    Icons.explore_outlined,
    Icons.event_outlined,
    Icons.campaign_outlined,
    Icons.person_outline,
  ];

  final List<IconData> _selectedIcons = const [
    Icons.groups,
    Icons.explore,
    Icons.event,
    Icons.campaign,
    Icons.person,
  ];

  final List<String> _labels = const [
    'Home',
    'Discover',
    'Events',
    'Announcements',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              top: BorderSide(
                color: colors.outlineVariant.withOpacity(0.5),
                width: 0.7,
              ),
            ),
          ),
          child: Row(
            children: List.generate(_labels.length, (index) {
              final isSelected = _selectedIndex == index;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 1,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.secondaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isSelected
                                ? _selectedIcons[index]
                                : _icons[index],
                            size: 22,
                            color: isSelected
                                ? colors.onSecondaryContainer
                                : colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _labels[index],
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: index == 3 ? 9 : 11,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
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

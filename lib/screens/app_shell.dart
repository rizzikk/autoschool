import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../core/breakpoints.dart';
import '../router/sections.dart';
import '../widgets/dialogs.dart';

class AppShell extends StatelessWidget {
  final String location;
  final Widget child;

  const AppShell({super.key, required this.location, required this.child});

  static String targetOf(BuildContext context, AppSection section) =>
      section.path;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final sections = sectionsFor(auth);
    final current = sectionOf(location, sections);
    final index = current == null ? null : sections.indexOf(current);
    final size = screenSizeOf(context);

    void select(int i) => context.go(targetOf(context, sections[i]));

    if (size == ScreenSize.compact) {
      final main = sections.length > 5 ? sections.sublist(0, 4) : sections;
      final more = sections.length > 5 ? sections.sublist(4) : <AppSection>[];
      final selected = index == null
          ? 0
          : index < main.length
              ? index
              : main.length;
      return Scaffold(
        body: Column(
          children: [
            const UserBar(compact: true),
            const Divider(height: 1),
            Expanded(child: _contentBoundary(child)),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (i) {
            if (i < main.length) {
              select(i);
            } else {
              _showMore(context, more);
            }
          },
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: [
            for (final s in main)
              NavigationDestination(
                  icon: Icon(s.icon), label: s.labelFor(auth.role)),
            if (more.isNotEmpty)
              const NavigationDestination(
                  icon: Icon(Icons.more_horiz), label: 'Ещё'),
          ],
        ),
      );
    }

    final extended = size == ScreenSize.expanded;
    return Scaffold(
      body: Column(
        children: [
          const UserBar(),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: NavigationRail(
                          selectedIndex: index,
                          onDestinationSelected: select,
                          extended: extended,
                          labelType: extended
                              ? NavigationRailLabelType.none
                              : NavigationRailLabelType.all,
                          destinations: [
                            for (final s in sections)
                              NavigationRailDestination(
                                icon: Icon(s.icon),
                                label: Text(s.labelFor(auth.role)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _contentBoundary(ContentFrame(child: child))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMore(BuildContext context, List<AppSection> more) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in more)
              ListTile(
                leading: Icon(s.icon),
                title: Text(s.labelFor(context.read<AuthNotifier>().role)),
                subtitle: Text(s.description),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go(targetOf(context, s));
                },
              ),
          ],
        ),
      ),
    );
  }
}

class UserBar extends StatelessWidget {
  const UserBar({super.key, this.compact = false});
  final bool compact;

  Future<void> _logout(BuildContext context) async {
    final auth = context.read<AuthNotifier>();
    final ok = await confirmAction(
      context,
      title: 'Выйти из системы?',
      message: 'Данные входа будут удалены из браузера, для продолжения '
          'работы понадобится войти снова.',
      confirmLabel: 'Выйти',
      destructive: false,
    );
    if (ok) await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.directions_car, color: scheme.primary),
              const SizedBox(width: 10),
              if (!compact)
                Text('Автошкола', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (user != null) ...[
                if (!compact) ...[
                  Chip(
                    avatar: const Icon(Icons.verified_user_outlined, size: 18),
                    label: Text(user.role.label),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 12),
                ],
                CircleAvatar(
                  radius: 15,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    user.displayName.isEmpty
                        ? '?'
                        : user.displayName.characters.first.toUpperCase(),
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? 140 : 280),
                  child: Text(
                    user.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                compact
                    ? IconButton(
                        tooltip: 'Выйти',
                        icon: const Icon(Icons.logout),
                        onPressed: () => _logout(context),
                      )
                    : TextButton.icon(
                        onPressed: () => _logout(context),
                        icon: const Icon(Icons.logout),
                        label: const Text('Выйти'),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Widget _contentBoundary(Widget child) =>
    Semantics(container: true, explicitChildNodes: true, child: child);

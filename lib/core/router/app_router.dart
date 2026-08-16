import 'package:go_router/go_router.dart';
import '../../features/settings/presentation/pages/about_page.dart';
import '../../features/settings/presentation/pages/connections_page.dart';
import '../../features/settings/presentation/pages/faq_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/settings/presentation/pages/logs_page.dart';
import '../../features/settings/presentation/pages/ping_settings_page.dart';
import '../../features/settings/presentation/pages/routing_distribution_page.dart';
import '../../features/settings/presentation/pages/routing_preset_manager_page.dart';
import '../../features/settings/presentation/pages/routing_preset_page.dart';
import '../../features/settings/presentation/pages/rule_editor_page.dart';
import '../../features/settings/presentation/pages/routes_rules_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/statistics_page.dart';
import '../../features/settings/presentation/pages/tunnel_settings_page.dart';
import '../../features/settings/presentation/pages/xray_settings_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/settings/statistics',
        name: 'statistics',
        builder: (context, state) => const StatisticsPage(),
      ),
      GoRoute(
        path: '/settings/faq',
        name: 'faq',
        builder: (context, state) => const FaqPage(),
      ),
      GoRoute(
        path: '/settings/about',
        name: 'about',
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: '/settings/connections',
        name: 'connections',
        builder: (context, state) => const ConnectionsPage(),
      ),
      GoRoute(
        path: '/settings/ping',
        name: 'ping-settings',
        builder: (context, state) => const PingSettingsPage(),
      ),
      GoRoute(
        path: '/settings/logs',
        name: 'logs',
        builder: (context, state) => const LogsPage(),
      ),
      GoRoute(
        path: '/settings/tunnel',
        name: 'tunnel-settings',
        builder: (context, state) => const TunnelSettingsPage(),
      ),
      GoRoute(
        path: '/settings/xray',
        name: 'xray-settings',
        builder: (context, state) => const XraySettingsPage(),
      ),
      GoRoute(
        path: '/settings/routes',
        name: 'routes-rules',
        builder: (context, state) => const RoutesRulesPage(),
      ),
      GoRoute(
        path: '/settings/routes/presets',
        name: 'routing-preset-manager',
        builder: (context, state) => const RoutingPresetManagerPage(),
      ),
      GoRoute(
        path: '/settings/routes/preset/:presetId',
        name: 'routing-preset',
        builder: (context, state) => RoutingPresetPage(
          presetId: state.pathParameters['presetId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/settings/routes/preset/:presetId/distribution',
        name: 'routes-distribution',
        builder: (context, state) => RoutingDistributionPage(
          presetId: state.pathParameters['presetId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/settings/routes/preset/:presetId/rules/:kind',
        name: 'route-rule-editor',
        builder: (context, state) => RuleEditorPage(
          presetId: state.pathParameters['presetId'] ?? '',
          kind: RuleEditorKindParsing.fromPath(
            state.pathParameters['kind'],
          ),
        ),
      ),
    ],
  );
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/models/server_group.dart';
import '../../../../core/models/tunnel_health.dart';
import '../../../../core/models/vpn_node.dart';
import '../../../../core/providers/connection_source_refresh_provider.dart';
import '../../../../core/providers/ping_monitor_provider.dart';
import '../../../../core/providers/server_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/providers/vpn_provider.dart';
import '../../../../core/services/routing_service.dart';
import '../../../../core/services/vpn_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/bottom_menu.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/ladybug_icon.dart';
import '../widgets/vpn_toggle_button.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _isAutoMode = true;
  Timer? _healthRefreshTimer;
  TunnelHealth? _tunnelHealth;

  @override
  void initState() {
    super.initState();
    _checkRouting();
    unawaited(_refreshTunnelHealth());
    _healthRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_refreshTunnelHealth()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(connectionSourceRefreshProvider);
    });
  }

  @override
  void dispose() {
    _healthRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkRouting() async {
    final countryCode = await RoutingService.getUserCountryCode();
    if (!mounted || countryCode == null) {
      return;
    }

    final message = context.l10n.routingMessage(countryCode);
    if (message.isEmpty) {
      return;
    }

    final colors = AppTheme.colors(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: colors.connected,
      ),
    );
  }

  Future<void> _toggleConnection(ConnectionStatus status) async {
    if (status == ConnectionStatus.connecting ||
        status == ConnectionStatus.disconnecting) {
      return;
    }

    if (status == ConnectionStatus.connected) {
      await ref.read(vpnConnectionProvider.notifier).disconnect();
      return;
    }

    await ref.read(pingMonitorProvider).ensureFreshMetrics(
          reason: 'before-connect',
        );

    var currentSelectedServer = ref.read(selectedServerProvider);
    if (_isAutoMode) {
      if (mounted) {
        setState(() {
          _isAutoMode = true;
        });
      }
      await ref.read(selectedServerProvider.notifier).autoSelect();
      currentSelectedServer = ref.read(selectedServerProvider);
    } else if (currentSelectedServer == null) {
      if (mounted) {
        setState(() {
          _isAutoMode = true;
        });
      }
      await ref.read(selectedServerProvider.notifier).autoSelect();
      currentSelectedServer = ref.read(selectedServerProvider);
    } else if (!_isAutoMode && currentSelectedServer.selectedNode == null) {
      currentSelectedServer = await ref
          .read(selectedServerProvider.notifier)
          .resolveBestNodeForGroup(currentSelectedServer);
    }

    final node = currentSelectedServer?.selectedNode ??
        (currentSelectedServer?.nodes.isNotEmpty == true
            ? currentSelectedServer!.nodes.first
            : null);

    if (node != null) {
      await ref.read(vpnConnectionProvider.notifier).connect(node);
    }
  }

  Future<void> _refreshTunnelHealth() async {
    if ((!Platform.isMacOS && !Platform.isIOS) || !mounted) {
      return;
    }

    final nextHealth = await ref.read(vpnServiceProvider).readTunnelHealth();
    if (!mounted) {
      return;
    }

    setState(() {
      _tunnelHealth = nextHealth;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final connectionStatus = ref.watch(vpnConnectionProvider);
    final selectedServer = ref.watch(selectedServerProvider);
    final serverList = ref.watch(serverListProvider);
    final serverGroups = ref.watch(serverGroupsProvider);
    final currentNode = ref.read(vpnConnectionProvider.notifier).currentNode;
    final selectedCountryCode = _isAutoMode
        ? null
        : _selectedCountryCode(
            selectedServer: selectedServer,
            activeNode: currentNode,
            serverGroups: serverGroups,
          );
    final collapsedSelectionTitle = _collapsedSelectionTitle(
      selectedServer: selectedServer,
      activeNode: currentNode,
      selectedCountryCode: selectedCountryCode,
    );
    final subscriptionError =
        serverList.hasError ? serverList.error.toString() : null;

    final hasServers = serverList.when(
      data: (nodes) => nodes.isNotEmpty,
      loading: () => false,
      error: (_, __) => false,
    );

    return Scaffold(
      backgroundColor: AppTheme.colors(context).background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: _AmbientGlowBackdrop(),
            ),
          ),
          Positioned(
            top: 38,
            left: 22,
            right: 22,
            child: _DesktopHeader(
              isDevMode: settings.devMode,
              onSettingsTap: () => context.push('/settings'),
            ),
          ),
          Positioned.fill(
            child: hasServers
                ? _MainView(
                    connectionStatus: connectionStatus,
                    healthWarning: _healthWarningText(
                      context,
                      connectionStatus,
                    ),
                    onToggle: () => _toggleConnection(connectionStatus),
                  )
                : EmptyStateView(
                    isLoading: serverList.isLoading &&
                        settings.enabledConnectionSources.isNotEmpty,
                    errorText: subscriptionError,
                  ),
          ),
          if (hasServers)
            Positioned.fill(
              child: BottomMenu(
                serverGroups: serverGroups,
                isDevMode: settings.devMode,
                activeNode: currentNode ?? selectedServer?.selectedNode,
                selectedCountryCode: selectedCountryCode,
                isAutoMode: _isAutoMode,
                collapsedTitle: collapsedSelectionTitle,
                collapsedSubtitle:
                    collapsedSelectionTitle == context.l10n.chooseConnection
                        ? null
                        : context.l10n.chooseConnection,
                onAutoSelected: () {
                  setState(() {
                    _isAutoMode = true;
                  });
                  ref.read(selectedServerProvider.notifier).clearSelection();
                },
                onCountrySelected: (group) {
                  setState(() {
                    _isAutoMode = false;
                  });
                  ref
                      .read(selectedServerProvider.notifier)
                      .selectGroup(group.copyWith(selectedNode: null));
                },
                onNodeSelected: (group, node) {
                  setState(() {
                    _isAutoMode = false;
                  });
                  ref.read(selectedServerProvider.notifier).selectGroup(
                        group.copyWith(selectedNode: node),
                      );
                },
              ),
            ),
        ],
      ),
    );
  }

  String? _selectedCountryCode({
    required List<ServerGroup> serverGroups,
    required ServerGroup? selectedServer,
    required VpnNode? activeNode,
  }) {
    if (selectedServer != null) {
      return selectedServer.countryCode;
    }

    if (activeNode == null) {
      return null;
    }

    for (final group in serverGroups) {
      final containsNode = group.nodes.any((node) => node.id == activeNode.id);
      if (containsNode) {
        return group.countryCode;
      }
    }

    return null;
  }

  String _collapsedSelectionTitle({
    required ServerGroup? selectedServer,
    required VpnNode? activeNode,
    required String? selectedCountryCode,
  }) {
    final l10n = context.l10n;
    if (_isAutoMode) {
      return l10n.automatic;
    }
    final selectedNode = selectedServer?.selectedNode ?? activeNode;
    if (selectedNode != null) {
      return selectedNode.name;
    }
    if (selectedCountryCode != null && selectedCountryCode.isNotEmpty) {
      return l10n.countryName(selectedCountryCode);
    }
    return l10n.chooseConnection;
  }

  String? _healthWarningText(
    BuildContext context,
    ConnectionStatus connectionStatus,
  ) {
    if (connectionStatus != ConnectionStatus.connected) {
      return null;
    }

    final health = _tunnelHealth;
    if (health == null) {
      return null;
    }

    if (Platform.isMacOS) {
      if (!health.helperInstalled) {
        return context.l10n.helperInstallWarning;
      }
      if (!health.helperReachable) {
        return context.l10n.helperUnavailableWarning;
      }
      if (!health.routesConfigured) {
        return context.l10n.utunRoutesWarning;
      }
      if (!health.dnsConfigured &&
          _readTunnelDnsMode() == 'custom') {
        return context.l10n.utunDnsWarning;
      }
      return null;
    }

    if (Platform.isIOS) {
      if (!health.xrayRunning || health.nativeState != 'connected') {
        return context.l10n.iosTunnelRecoveryWarning;
      }
      if (health.memoryPressure == 'critical') {
        return context.l10n.iosMemoryCriticalWarning;
      }
      if (health.memoryPressure == 'high') {
        return context.l10n.iosMemoryPressureWarning;
      }
    }

    return null;
  }

  String _readTunnelDnsMode() {
    return ref.read(settingsProvider).tunnelSettings.dnsMode;
  }
}

class _MainView extends StatelessWidget {
  final ConnectionStatus connectionStatus;
  final String? healthWarning;
  final VoidCallback onToggle;

  const _MainView({
    required this.connectionStatus,
    required this.healthWarning,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 116),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _statusText(context, connectionStatus),
              style: TextStyle(
                color: AppTheme.colors(context).text,
                fontSize: 18,
                fontFamily: '.SF Pro Text',
                fontWeight: FontWeight.w400,
                height: 1,
                letterSpacing: -0.4,
              ),
            ),
            if (healthWarning != null) ...[
              const SizedBox(height: 12),
              _HealthWarningBanner(text: healthWarning!),
            ],
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                _HeroToggleAura(connectionStatus: connectionStatus),
                VpnToggleButton(
                  isConnected: connectionStatus == ConnectionStatus.connected,
                  isConnecting: connectionStatus == ConnectionStatus.connecting,
                  onToggle: onToggle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(BuildContext context, ConnectionStatus status) {
    final l10n = context.l10n;
    switch (status) {
      case ConnectionStatus.disconnected:
      case ConnectionStatus.disconnecting:
        return l10n.disconnected;
      case ConnectionStatus.connecting:
        return l10n.connecting;
      case ConnectionStatus.connected:
        return l10n.connected;
      case ConnectionStatus.error:
        return l10n.error;
    }
  }
}

class _HealthWarningBanner extends StatelessWidget {
  final String text;

  const _HealthWarningBanner({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0x55FFB45C),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: Color(0xFFFFB45C),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text.withValues(alpha: 0.92),
                fontSize: 12.5,
                fontFamily: '.SF Pro Text',
                fontWeight: FontWeight.w500,
                height: 1.3,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  final bool isDevMode;
  final VoidCallback onSettingsTap;

  const _DesktopHeader({
    required this.isDevMode,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _HeaderIconButton(
          onTap: onSettingsTap,
          child: SvgPicture.asset(
            'assets/icons/gear.svg',
            width: 21,
            height: 21,
            colorFilter: ColorFilter.mode(
              AppTheme.colors(context).text,
              BlendMode.srcIn,
            ),
          ),
        ),
        if (isDevMode) ...[
          const SizedBox(width: 10),
          const _DevBadge(),
        ],
        const Spacer(),
        if (isDevMode)
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: AppTheme.glassPanel(
              context,
              radius: 19,
              baseColor: AppTheme.colors(context).card,
              glowColor: AppTheme.colors(context).ambientSecondary,
            ),
            child: const LadybugIcon(size: 24),
          ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _HeaderIconButton({
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: onTap,
            containedInkWell: true,
            highlightShape: BoxShape.circle,
            radius: 19,
            child: Container(
              decoration: AppTheme.glassPanel(
                context,
                radius: 19,
                baseColor: colors.card,
                glowColor: colors.ambientPrimary,
              ),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _DevBadge extends StatelessWidget {
  const _DevBadge();

  @override
  Widget build(BuildContext context) {
    const textGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFF8C287),
        Color(0xFFF3A65B),
        Color(0xFFDE7C2D),
      ],
    );

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x332C1A0B),
            Color(0x663B2410),
          ],
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: const Color(0x66E79C4D),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26E0893A),
            blurRadius: 16,
            spreadRadius: -8,
            offset: Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: ShaderMask(
        shaderCallback: (bounds) => textGradient.createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: const Text(
          'Pro',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: '.SF Pro Text',
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

class _HeroToggleAura extends StatelessWidget {
  final ConnectionStatus connectionStatus;

  const _HeroToggleAura({
    required this.connectionStatus,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final glowColor = switch (connectionStatus) {
      ConnectionStatus.connected => colors.connected,
      ConnectionStatus.connecting => colors.ambientPrimary,
      _ => colors.ambientSecondary,
    };

    return IgnorePointer(
      child: SizedBox(
        width: 280,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.14),
                    blurRadius: 80,
                    spreadRadius: -6,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
            ),
            Container(
              width: 138,
              height: 138,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    glowColor.withValues(alpha: 0.08),
                    glowColor.withValues(alpha: 0.025),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientGlowBackdrop extends StatelessWidget {
  const _AmbientGlowBackdrop();

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(colors.background, Colors.black, 0.10) ??
                    colors.background,
                colors.background,
                Color.lerp(colors.background, colors.card, 0.12) ??
                    colors.background,
              ],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -20,
          child: _AmbientOrb(
            size: 220,
            color: colors.ambientPrimary,
            opacity: 0.08,
          ),
        ),
        Positioned(
          top: 190,
          left: -60,
          child: _AmbientOrb(
            size: 240,
            color: colors.ambientSecondary,
            opacity: 0.06,
          ),
        ),
        Positioned(
          bottom: 50,
          right: 60,
          child: _AmbientOrb(
            size: 220,
            color: colors.ambientSuccess,
            opacity: 0.045,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  colors.background.withValues(alpha: 0.04),
                  colors.background.withValues(alpha: 0.18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _AmbientOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: opacity),
              blurRadius: size * 0.48,
              spreadRadius: size * 0.05,
            ),
          ],
        ),
      ),
    );
  }
}

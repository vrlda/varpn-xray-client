import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/models/server_group.dart';
import '../../../../core/models/vpn_node.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/country_flag_widget.dart';

class BottomMenu extends StatefulWidget {
  final List<ServerGroup> serverGroups;
  final bool isDevMode;
  final VpnNode? activeNode;
  final String? selectedCountryCode;
  final bool isAutoMode;
  final String collapsedTitle;
  final String? collapsedSubtitle;
  final VoidCallback onAutoSelected;
  final void Function(ServerGroup group) onCountrySelected;
  final void Function(ServerGroup group, VpnNode node) onNodeSelected;

  const BottomMenu({
    super.key,
    required this.serverGroups,
    required this.isDevMode,
    required this.activeNode,
    required this.selectedCountryCode,
    required this.isAutoMode,
    required this.collapsedTitle,
    required this.collapsedSubtitle,
    required this.onAutoSelected,
    required this.onCountrySelected,
    required this.onNodeSelected,
  });

  @override
  State<BottomMenu> createState() => _BottomMenuState();
}

class _BottomMenuState extends State<BottomMenu>
    with SingleTickerProviderStateMixin {
  static const _closedHeight = 84.0;
  static const _baseExpandedHeight = 104.0;
  static const _countryTileHeight = 37.0;
  static const _countryRunSpacing = 14.0;
  static const _nodeTileHeight = 38.0;
  static const _nodeRunSpacing = 8.0;
  static const _horizontalPadding = 18.0;
  static const _columnSpacing = 14.0;

  late final AnimationController _controller;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _closeMenu() {
    if (!_isOpen) {
      return;
    }
    setState(() {
      _isOpen = false;
      _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final sortedGroups = _sortedGroups(widget.serverGroups);
    final nodes = widget.isDevMode
        ? _buildNodeEntries(sortedGroups)
        : const <_NodeEntry>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = math
            .max(
              constraints.maxWidth - (_horizontalPadding * 2),
              0,
            )
            .toDouble();
        final maxOpenHeight = (constraints.maxHeight * 0.50)
            .clamp(
              164.0,
              340.0,
            )
            .toDouble();
        final expandedContentHeight = _estimateExpandedContentHeight(
          context: context,
          maxWidth: contentWidth,
          sortedGroups: sortedGroups,
          nodes: nodes,
        );
        final targetOpenHeight = (_baseExpandedHeight + expandedContentHeight)
            .clamp(
              _closedHeight,
              maxOpenHeight,
            )
            .toDouble();

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final height = _closedHeight +
                ((targetOpenHeight - _closedHeight) * _controller.value);
            final isExpanded = _controller.value > 0.05;

            return Stack(
              children: [
                if (isExpanded)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _closeMenu,
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: double.infinity,
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(
                                  colors.surfaceElevated, Colors.white, 0.03) ??
                              colors.surfaceElevated,
                          colors.surfaceElevated,
                          Color.lerp(
                                colors.surfaceElevated,
                                colors.background,
                                0.06,
                              ) ??
                              colors.surfaceElevated,
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(36),
                        topRight: Radius.circular(36),
                      ),
                      border: Border.all(color: colors.panelStroke),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 8,
                          left: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _toggleMenu,
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: Transform.rotate(
                                angle:
                                    (1 - _controller.value) * 3.141592653589793,
                                child: SvgPicture.asset(
                                  'assets/icons/chevron.up.svg',
                                  width: 15,
                                  height: 10,
                                  colorFilter: ColorFilter.mode(
                                    colors.text,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!isExpanded)
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: _toggleMenu,
                              behavior: HitTestBehavior.opaque,
                              child: Align(
                                alignment: const Alignment(0, 0.22),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.collapsedTitle,
                                      style: TextStyle(
                                        color: colors.text,
                                        fontSize: 17,
                                        fontFamily: '.SF Pro Text',
                                        fontWeight: FontWeight.w500,
                                        height: 1,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    if (widget.collapsedSubtitle != null) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        widget.collapsedSubtitle!,
                                        style: TextStyle(
                                          color: colors.mutedText,
                                          fontSize: 13,
                                          fontFamily: '.SF Pro Text',
                                          fontWeight: FontWeight.w400,
                                          height: 1,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (isExpanded)
                          Opacity(
                            opacity: _controller.value,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                _horizontalPadding,
                                40,
                                _horizontalPadding,
                                18,
                              ),
                              child: Column(
                                children: [
                                  _AutoModeChip(
                                    isActive: widget.isAutoMode,
                                    onTap: () {
                                      widget.onAutoSelected();
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  Expanded(
                                    child: _buildExpandedContent(
                                      sortedGroups: sortedGroups,
                                      nodes: nodes,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double _estimateExpandedContentHeight({
    required BuildContext context,
    required double maxWidth,
    required List<ServerGroup> sortedGroups,
    required List<_NodeEntry> nodes,
  }) {
    if (widget.isDevMode) {
      if (nodes.isEmpty) {
        return 56;
      }

      final columnCount = maxWidth >= 620 ? 2 : 1;
      final rowCount = (nodes.length / columnCount).ceil();
      return (rowCount * _nodeTileHeight) +
          (math.max(rowCount - 1, 0) * _nodeRunSpacing);
    }

    if (sortedGroups.isEmpty) {
      return 56;
    }

    final rowCount = _estimateCountryRows(
      context: context,
      groups: sortedGroups,
      maxWidth: maxWidth,
    );
    return (rowCount * _countryTileHeight) +
        (math.max(rowCount - 1, 0) * _countryRunSpacing);
  }

  int _estimateCountryRows({
    required BuildContext context,
    required List<ServerGroup> groups,
    required double maxWidth,
  }) {
    if (groups.isEmpty || maxWidth <= 0) {
      return 1;
    }

    const textStyle = TextStyle(
      fontSize: 17,
      fontFamily: '.SF Pro Text',
      fontWeight: FontWeight.w400,
      letterSpacing: -0.4,
    );

    var rows = 1;
    var usedWidth = 0.0;
    for (final group in groups) {
      final tileWidth = _measureCountryTileWidth(
        label: context.l10n.countryName(group.countryCode),
        style: textStyle,
      );
      if (usedWidth > 0 && (usedWidth + 14 + tileWidth) > maxWidth) {
        rows += 1;
        usedWidth = tileWidth;
      } else {
        usedWidth += usedWidth == 0 ? tileWidth : 14 + tileWidth;
      }
    }

    return rows;
  }

  double _measureCountryTileWidth({
    required String label,
    required TextStyle style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width + 18 + 6 + 24;
  }

  Widget _buildExpandedContent({
    required List<ServerGroup> sortedGroups,
    required List<_NodeEntry> nodes,
  }) {
    final colors = AppTheme.colors(context);
    final l10n = context.l10n;
    final isEmpty = widget.isDevMode ? nodes.isEmpty : sortedGroups.isEmpty;
    if (isEmpty) {
      return Center(
        child: Text(
          l10n.noConnections,
          style: TextStyle(
            color: colors.mutedText,
            fontSize: 15,
            fontFamily: '.SF Pro Text',
            fontWeight: FontWeight.w400,
            letterSpacing: -0.4,
          ),
        ),
      );
    }

    if (widget.isDevMode) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final columnCount = constraints.maxWidth >= 620 ? 2 : 1;
          final columnWidth = columnCount == 1
              ? constraints.maxWidth
              : ((constraints.maxWidth - _columnSpacing) / 2).toDouble();

          return Align(
            alignment: Alignment.topCenter,
            child: Scrollbar(
              thumbVisibility: true,
              radius: const Radius.circular(999),
              child: SingleChildScrollView(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: columnCount == 1 ? 0 : _columnSpacing,
                  runSpacing: 8,
                  children: nodes
                      .map(
                        (entry) => _NodeTile(
                          group: entry.group,
                          node: entry.node,
                          isSelected: widget.activeNode?.id == entry.node.id,
                          width: columnWidth,
                          onTap: () {
                            widget.onNodeSelected(entry.group, entry.node);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          );
        },
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: Scrollbar(
        thumbVisibility: true,
        radius: const Radius.circular(999),
        child: SingleChildScrollView(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: sortedGroups
                .map(
                  (group) => _CountryTile(
                    group: group,
                    isSelected: !widget.isAutoMode &&
                        widget.selectedCountryCode == group.countryCode,
                    onTap: () {
                      widget.onCountrySelected(group);
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  List<ServerGroup> _sortedGroups(List<ServerGroup> groups) {
    final sortedGroups = [...groups]
      ..sort((a, b) => a.countryName.compareTo(b.countryName));
    return sortedGroups;
  }

  List<_NodeEntry> _buildNodeEntries(List<ServerGroup> groups) {
    final entries = <_NodeEntry>[];

    for (final group in groups) {
      final sortedNodes = [...group.nodes]
        ..sort((a, b) => _pingFor(a).compareTo(_pingFor(b)));

      for (final node in sortedNodes) {
        entries.add(_NodeEntry(group: group, node: node));
      }
    }

    return entries;
  }

  int _pingFor(VpnNode node) {
    if (node.ping > 0) {
      return node.ping;
    }
    if (node.httpResponseTime > 0) {
      return node.httpResponseTime;
    }
    return 9999;
  }
}

class _AutoModeChip extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _AutoModeChip({
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isActive
                ? [
                    Color.lerp(colors.chipSelected, Colors.white, 0.08) ??
                        colors.chipSelected,
                    colors.chipSelected,
                  ]
                : [
                    Color.lerp(colors.chip, Colors.white, 0.02) ?? colors.chip,
                    colors.chip,
                  ],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: colors.chipSelected.withValues(alpha: 0.18),
                    blurRadius: 14,
                    spreadRadius: -8,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          context.l10n.automatic,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontFamily: '.SF Pro Text',
            fontWeight: FontWeight.w400,
            height: 1,
            letterSpacing: -0.4,
          ),
        ),
      ),
    );
  }
}

class _CountryTile extends StatelessWidget {
  final ServerGroup group;
  final bool isSelected;
  final VoidCallback onTap;

  const _CountryTile({
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final l10n = context.l10n;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 37),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.chipSelected : colors.chip,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colors.chipSelected.withValues(alpha: 0.28)
                : colors.panelStroke,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.chipSelected.withValues(alpha: 0.14),
                    blurRadius: 12,
                    spreadRadius: -8,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CountryFlagWidget(
              countryCode: group.countryCode,
              width: 18,
              height: 18,
            ),
            const SizedBox(width: 6),
            Text(
              l10n.countryName(group.countryCode),
              style: TextStyle(
                color: isSelected ? Colors.white : colors.text,
                fontSize: 17,
                fontFamily: '.SF Pro Text',
                fontWeight: FontWeight.w400,
                height: 1,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  final ServerGroup group;
  final VpnNode node;
  final bool isSelected;
  final double width;
  final VoidCallback onTap;

  const _NodeTile({
    required this.group,
    required this.node,
    required this.isSelected,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final ping = node.ping > 0 ? node.ping : node.httpResponseTime;
    final detailTag = _modeBadge(node);
    final tags = <String>[
      node.protocol,
      if ((node.network ?? '').isNotEmpty) node.network!,
      if (detailTag != null) detailTag,
    ];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? colors.chipSelected : colors.card,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: isSelected
                ? colors.chipSelected.withValues(alpha: 0.24)
                : colors.panelStroke,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.chipSelected.withValues(alpha: 0.14),
                    blurRadius: 14,
                    spreadRadius: -10,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            CountryFlagWidget(
              countryCode: group.countryCode,
              width: 18,
              height: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                node.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : colors.text,
                  fontSize: 17,
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w400,
                  height: 1,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            if (ping > 0) ...[
              SizedBox(
                width: 46,
                child: Text(
                  '${ping}ms',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.8)
                        : colors.mutedText,
                    fontSize: 11,
                    fontFamily: '.SF Pro Text',
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            ...tags.map(
              (tag) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _NodeTag(
                  label: tag,
                  isSelected: isSelected,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _modeBadge(VpnNode node) {
    final security = (node.security ?? '').toLowerCase();
    final network = (node.network ?? '').toLowerCase();

    if (security == 'reality') {
      return 'r';
    }
    if (network == 'tcp') {
      return 't';
    }
    if (security == 'none') {
      return 'n';
    }

    return null;
  }
}

class _NodeTag extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _NodeTag({
    required this.label,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Container(
      height: 19,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withValues(alpha: 0.16) : colors.chip,
        borderRadius: BorderRadius.circular(7),
      ),
      alignment: Alignment.center,
      child: Text(
        label.toLowerCase(),
        style: TextStyle(
          color: isSelected ? Colors.white : colors.text,
          fontSize: 12,
          fontFamily: '.SF Pro Text',
          fontWeight: FontWeight.w400,
          height: 1,
        ),
      ),
    );
  }
}

class _NodeEntry {
  final ServerGroup group;
  final VpnNode node;

  const _NodeEntry({
    required this.group,
    required this.node,
  });
}

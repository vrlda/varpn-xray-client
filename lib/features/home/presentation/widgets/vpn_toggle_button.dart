import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class VpnToggleButton extends StatefulWidget {
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onToggle;

  const VpnToggleButton({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    required this.onToggle,
  });

  @override
  State<VpnToggleButton> createState() => _VpnToggleButtonState();
}

class _VpnToggleButtonState extends State<VpnToggleButton>
    with SingleTickerProviderStateMixin {
  static const _trackWidth = 128.0;
  static const _trackHeight = 214.0;
  static const _knobSize = 114.0;
  static const _padding = 7.0;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: _targetValue,
    );
  }

  @override
  void didUpdateWidget(covariant VpnToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_targetValue != _controller.value) {
      _controller.animateTo(
        _targetValue,
        curve: Curves.easeOutCubic,
      );
    }
  }

  double get _targetValue {
    if (widget.isConnected) {
      return 1.0;
    }
    if (widget.isConnecting) {
      return 0.5;
    }
    return 0.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return GestureDetector(
      onTap: widget.isConnecting ? null : widget.onToggle,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final knobTop = TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween<double>(
                begin: _trackHeight - _knobSize - _padding,
                end: (_trackHeight - _knobSize) / 2,
              ),
              weight: 1,
            ),
            TweenSequenceItem(
              tween: Tween<double>(
                begin: (_trackHeight - _knobSize) / 2,
                end: _padding,
              ),
              weight: 1,
            ),
          ]).transform(_controller.value);

          final trackColor = _controller.value <= 0.5
              ? Color.lerp(
                  colors.disconnected,
                  colors.card,
                  _controller.value / 0.5,
                )
              : Color.lerp(
                  colors.card,
                  colors.connected,
                  (_controller.value - 0.5) / 0.5,
                );
          final auraColor = widget.isConnected
              ? colors.connected
              : widget.isConnecting
                  ? colors.ambientPrimary
                  : colors.ambientSecondary;
          final resolvedTrackColor = trackColor ?? colors.card;

          return Container(
            width: _trackWidth,
            height: _trackHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(resolvedTrackColor, Colors.white, 0.08) ??
                      resolvedTrackColor,
                  resolvedTrackColor,
                ],
              ),
              borderRadius: BorderRadius.circular(_trackWidth / 2),
              border: Border.all(color: colors.panelStroke),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: auraColor.withValues(
                    alpha: widget.isConnected
                        ? 0.16
                        : widget.isConnecting
                            ? 0.12
                            : 0.08,
                  ),
                  blurRadius: 40,
                  spreadRadius: -12,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_trackWidth / 2),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.transparent,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: (_trackWidth - _knobSize) / 2,
                  top: knobTop,
                  child: Container(
                    width: _knobSize,
                    height: _knobSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Color(0xFFF0F3FA),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: auraColor.withValues(alpha: 0.08),
                          blurRadius: 18,
                          spreadRadius: -10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

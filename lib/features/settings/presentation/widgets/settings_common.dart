import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

class SettingsPageShell extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget child;
  final Widget? trailing;

  const SettingsPageShell({
    super.key,
    required this.title,
    required this.onBack,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            top: 38,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w600,
                  height: 1,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
          Positioned(
            top: 38,
            left: 24,
            child: SettingsCircleButton(
              onTap: onBack,
              size: 44,
              child: SvgPicture.asset(
                'assets/icons/chevron.left.svg',
                width: 8,
                height: 16,
                colorFilter: ColorFilter.mode(
                  colors.text,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          if (trailing != null)
            Positioned(
              top: 38,
              right: 24,
              child: trailing!,
            ),
        ],
      ),
    );
  }
}

class SettingsCircleButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final double size;

  const SettingsCircleButton({
    super.key,
    required this.onTap,
    required this.child,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: onTap,
            containedInkWell: true,
            highlightShape: BoxShape.circle,
            radius: size / 2,
            child: Center(
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: AppTheme.glassPanel(
                      context,
                      radius: size / 2,
                      shape: BoxShape.circle,
                      baseColor: colors.card.withValues(alpha: 0.82),
                      glowColor: colors.ambientPrimary,
                    ),
                    alignment: Alignment.center,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsSectionLabel extends StatelessWidget {
  final String title;

  const SettingsSectionLabel({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: AppTheme.colors(context).mutedText,
        fontSize: 16,
        fontFamily: '.SF Pro Text',
        fontWeight: FontWeight.w500,
        height: 1,
        letterSpacing: -0.3,
      ),
    );
  }
}

class SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsCard({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassPanel(
        context,
        radius: 22,
        baseColor: AppTheme.colors(context).card,
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppTheme.colors(context).divider,
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double height;

  const SettingsRow({
    super.key,
    required this.title,
    this.trailing,
    this.onTap,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    final content = SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.text,
                fontSize: 18,
                fontFamily: '.SF Pro Text',
                fontWeight: FontWeight.w400,
                height: 1,
                letterSpacing: -0.4,
              ),
            ),
          ),
          trailing ??
              Icon(
                Icons.chevron_right_rounded,
                color: colors.mutedText,
                size: 18,
              ),
        ],
      ),
    );

    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: content,
    );

    if (onTap == null) {
      return child;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

class SettingsValueChevron extends StatelessWidget {
  final String value;

  const SettingsValueChevron({
    super.key,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: colors.mutedText,
            fontSize: 18,
            fontFamily: '.SF Pro Text',
            fontWeight: FontWeight.w400,
            height: 1,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          Icons.chevron_right_rounded,
          color: colors.mutedText,
          size: 18,
        ),
      ],
    );
  }
}

class SettingsToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 56,
        height: 26,
        decoration: BoxDecoration(
          color: value ? colors.chipSelected : colors.chip,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              left: value ? 20 : 2,
              top: 2,
              child: Container(
                width: 34,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsTextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const SettingsTextAction({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.colors(context).chipSelected,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontFamily: '.SF Pro Text',
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
    );
  }
}

class SelectionOption {
  final String value;
  final String label;

  const SelectionOption({
    required this.value,
    required this.label,
  });
}

Future<String?> showSettingsSelectionDialog({
  required BuildContext context,
  required String title,
  required List<SelectionOption> options,
  required String selectedValue,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final colors = AppTheme.colors(dialogContext);

      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.text.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
              const SizedBox(height: 16),
              ...options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => Navigator.of(dialogContext).pop(option.value),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: option.value == selectedValue
                            ? colors.chipSelected
                            : colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        option.label,
                        style: TextStyle(
                          color: option.value == selectedValue
                              ? Colors.white
                              : colors.text,
                          fontSize: 16,
                          fontFamily: '.SF Pro Text',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<String?> showSettingsTextInputDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  int minLines = 1,
  int maxLines = 1,
}) {
  final controller = TextEditingController(text: initialValue);

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final colors = AppTheme.colors(dialogContext);

      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.text.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                minLines: minLines,
                maxLines: maxLines,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 16,
                  fontFamily: '.SF Pro Text',
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      dialogContext.l10n.cancel,
                      style: TextStyle(color: colors.mutedText),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(controller.text.trim()),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.chipSelected,
                    ),
                    child: Text(dialogContext.l10n.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_localizations.dart';
import '../providers/server_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/vpn_provider.dart';
import '../theme/app_theme.dart';

Future<int?> showSubscriptionImportDialog(
  BuildContext context, {
  String? initialValue,
}) {
  return showDialog<int>(
    context: context,
    barrierDismissible: true,
    builder: (_) => SubscriptionImportDialog(
      initialValue: initialValue,
    ),
  );
}

class SubscriptionImportDialog extends ConsumerStatefulWidget {
  final String? initialValue;

  const SubscriptionImportDialog({
    super.key,
    this.initialValue,
  });

  @override
  ConsumerState<SubscriptionImportDialog> createState() =>
      _SubscriptionImportDialogState();
}

class _SubscriptionImportDialogState
    extends ConsumerState<SubscriptionImportDialog> {
  late final TextEditingController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final savedLink = ref.read(settingsProvider).subscriptionLink.trim();
    final initialValue = widget.initialValue?.trim();
    _controller = TextEditingController(
      text: initialValue != null && initialValue.isNotEmpty
          ? initialValue
          : savedLink,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final value = clipboardData?.text?.trim();
    if (value == null || value.isEmpty) {
      return;
    }

    _controller
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
  }

  Future<void> _importSubscription() async {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(vpnConnectionProvider.notifier).disconnect();
      final nodes =
          await ref.read(serverListProvider.notifier).loadFromSubscription(
                input,
              );
      ref.read(selectedServerProvider.notifier).clearSelection();
      ref.read(settingsProvider.notifier).setSubscriptionLink(input);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(nodes.length);
    } catch (error) {
      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.maybeOf(context);
      final colors = AppTheme.colors(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.importFailed(error)),
          backgroundColor: colors.disconnected,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final l10n = context.l10n;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colors.text.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.importSubscription,
              style: TextStyle(
                color: colors.text,
                fontSize: 22,
                fontFamily: '.SF Pro Text',
                fontWeight: FontWeight.w500,
                height: 1,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.importSubscriptionHint,
              style: TextStyle(
                color: colors.mutedText,
                fontSize: 16,
                fontFamily: '.SF Pro Text',
                fontWeight: FontWeight.w400,
                height: 1.3,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 8,
              style: TextStyle(
                color: colors.text,
                fontSize: 16,
                fontFamily: '.SF Pro Text',
              ),
              decoration: InputDecoration(
                hintText: 'https://example.com/subscription',
                hintStyle: TextStyle(
                  color: colors.mutedText,
                ),
                filled: true,
                fillColor: colors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(18),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: _isLoading ? null : _pasteFromClipboard,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.text,
                    backgroundColor: colors.surfaceElevated,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(l10n.paste),
                ),
                const Spacer(),
                TextButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.mutedText,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isLoading ? null : _importSubscription,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.connected,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(l10n.importAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

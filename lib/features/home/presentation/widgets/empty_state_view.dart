import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

class EmptyStateView extends ConsumerStatefulWidget {
  final bool isLoading;
  final String? errorText;

  const EmptyStateView({
    super.key,
    this.isLoading = false,
    this.errorText,
  });

  @override
  ConsumerState<EmptyStateView> createState() => _EmptyStateViewState();
}

class _EmptyStateViewState extends ConsumerState<EmptyStateView> {
  bool _isPreparingImport = false;

  Future<void> _openImportDialog() async {
    setState(() {
      _isPreparingImport = true;
    });

    if (mounted) {
      setState(() {
        _isPreparingImport = false;
      });
    }

    if (!mounted) {
      return;
    }

    context.push('/settings/connections');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final l10n = context.l10n;
    final isBusy = widget.isLoading || _isPreparingImport;
    final errorText = widget.errorText?.replaceFirst('Exception: ', '');
    final blobColor = isBusy ? colors.card : colors.surfaceElevated;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.addConnection,
            style: TextStyle(
              color: colors.text,
              fontSize: 18,
              fontFamily: '.SF Pro Text',
              fontWeight: FontWeight.w400,
              height: 1,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: isBusy ? null : _openImportDialog,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 132,
              height: 220,
              decoration: BoxDecoration(
                color: blobColor,
                borderRadius: BorderRadius.circular(66),
              ),
              child: Center(
                child: isBusy
                    ? const SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        l10n.pasteLink,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 18,
                          fontFamily: '.SF Pro Text',
                          fontWeight: FontWeight.w400,
                          height: 1.15,
                          letterSpacing: -0.4,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.isLoading
                ? l10n.loadingSavedSubscription
                : l10n.importPrompt,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.mutedText,
              fontSize: 14,
              fontFamily: '.SF Pro Text',
              fontWeight: FontWeight.w400,
              height: 1.2,
              letterSpacing: -0.4,
            ),
          ),
          if (errorText != null && errorText.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 340,
              child: Text(
                errorText,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.disconnected,
                  fontSize: 14,
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

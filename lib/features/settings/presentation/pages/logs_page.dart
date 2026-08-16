import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/app_log_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/settings_common.dart';

class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(appLogsProvider.notifier).syncNativeLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppTheme.colors(context);
    final entries = ref.watch(appLogsProvider).reversed.toList();

    return SettingsPageShell(
      title: l10n.logs,
      onBack: () => context.pop(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsTextAction(
            label: l10n.refresh,
            onTap: () {
              ref.read(appLogsProvider.notifier).syncNativeLogs();
            },
          ),
          SettingsTextAction(
            label: l10n.clear,
            onTap: () {
              ref.read(appLogsProvider.notifier).clear();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.logsCleared)),
              );
            },
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 92, 26, 24),
        child: entries.isEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    l10n.noLogsYet,
                    style: TextStyle(
                      color: colors.mutedText,
                      fontSize: 16,
                      fontFamily: '.SF Pro Text',
                    ),
                  ),
                ),
              )
            : SettingsCard(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    _LogEntryTile(entry: entries[i]),
                    if (i != entries.length - 1) const SettingsDivider(),
                  ],
                ],
              ),
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final AppLogEntry entry;

  const _LogEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final timestamp = DateFormat('dd.MM HH:mm:ss').format(entry.timestamp);
    final levelColor = switch (entry.level) {
      AppLogLevel.warning => const Color(0xFFFFB44D),
      AppLogLevel.error => const Color(0xFFFF6B6B),
      AppLogLevel.info => colors.chipSelected,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                timestamp,
                style: TextStyle(
                  color: colors.mutedText,
                  fontSize: 12,
                  fontFamily: '.SF Pro Text',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  entry.source,
                  style: TextStyle(
                    color: levelColor,
                    fontSize: 12,
                    fontFamily: '.SF Pro Text',
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            entry.message,
            style: TextStyle(
              color: colors.text,
              fontSize: 14,
              fontFamily: '.SF Mono',
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

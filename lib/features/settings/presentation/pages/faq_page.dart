import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/settings_common.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SettingsPageShell(
      title: l10n.faq,
      onBack: () => context.pop(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 92, 26, 24),
        child: SettingsCard(
          children: [
            _FaqTile(
              questionBuilder: _faqConnectionsQuestion,
              answerBuilder: _faqConnectionsAnswer,
            ),
            const SettingsDivider(),
            _FaqTile(
              questionBuilder: _faqProxyQuestion,
              answerBuilder: _faqProxyAnswer,
            ),
            const SettingsDivider(),
            _FaqTile(
              questionBuilder: _faqLogsQuestion,
              answerBuilder: _faqLogsAnswer,
            ),
            const SettingsDivider(),
            _FaqTile(
              questionBuilder: _faqDeveloperQuestion,
              answerBuilder: _faqDeveloperAnswer,
            ),
          ],
        ),
      ),
    );
  }
}

String _faqConnectionsQuestion(BuildContext context) =>
    context.l10n.faqConnectionsQuestion;
String _faqConnectionsAnswer(BuildContext context) =>
    context.l10n.faqConnectionsAnswer;
String _faqProxyQuestion(BuildContext context) => context.l10n.faqProxyQuestion;
String _faqProxyAnswer(BuildContext context) => context.l10n.faqProxyAnswer;
String _faqLogsQuestion(BuildContext context) => context.l10n.faqLogsQuestion;
String _faqLogsAnswer(BuildContext context) => context.l10n.faqLogsAnswer;
String _faqDeveloperQuestion(BuildContext context) =>
    context.l10n.faqDeveloperQuestion;
String _faqDeveloperAnswer(BuildContext context) =>
    context.l10n.faqDeveloperAnswer;

class _FaqTile extends StatelessWidget {
  final String Function(BuildContext context) questionBuilder;
  final String Function(BuildContext context) answerBuilder;

  const _FaqTile({
    required this.questionBuilder,
    required this.answerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questionBuilder(context),
            style: TextStyle(
              color: colors.text,
              fontSize: 17,
              fontFamily: '.SF Pro Text',
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            answerBuilder(context),
            style: TextStyle(
              color: colors.mutedText,
              fontSize: 14,
              fontFamily: '.SF Pro Text',
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

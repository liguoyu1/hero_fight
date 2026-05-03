import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/nickname.dart';
import '../i18n/app_localizations.dart';

/// Shows a nickname input dialog. Returns the nickname string or null if cancelled.
/// If [currentNickname] is provided, pre-fills the field for editing.
Future<String?> showNicknameDialog(BuildContext context, {String? currentNickname}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: currentNickname != null, // first-time: must set
    builder: (ctx) => _NicknameDialog(currentNickname: currentNickname),
  );
}

class _NicknameDialog extends StatefulWidget {
  final String? currentNickname;
  const _NicknameDialog({this.currentNickname});

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  late TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentNickname ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    final l10n = AppLocalizations.fromSystemLocale();
    if (text.isEmpty) {
      setState(() => _error = l10n.nicknameEmpty);
      return;
    }
    if (text.length > maxNicknameLength) {
      setState(() => _error = l10n.nicknameTooLong);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final isFirstTime = widget.currentNickname == null;
    final l10n = AppLocalizations.fromSystemLocale();
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        isFirstTime ? l10n.setNickname : l10n.changeNickname,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFirstTime)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.enterNicknameHint,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: maxNicknameLength,
              inputFormatters: [
                LengthLimitingTextInputFormatter(maxNicknameLength),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                hintText: l10n.enterNicknamePlaceholder,
                hintStyle: const TextStyle(color: Colors.white38),
                errorText: _error,
                counterStyle: const TextStyle(color: Colors.white38),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.amber.shade400),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        if (!isFirstTime)
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
          ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade700,
            foregroundColor: Colors.white,
          ),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

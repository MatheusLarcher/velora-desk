import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart'
    show setPasswordDialog;
import 'package:flutter_hbb/models/platform_model.dart';

/// Unattended access button. Shows whether a password is already saved on this
/// device and lets the user of this device see it.
class VeloraPasswordButton extends StatefulWidget {
  const VeloraPasswordButton({Key? key}) : super(key: key);

  @override
  State<VeloraPasswordButton> createState() => _VeloraPasswordButtonState();
}

class _VeloraPasswordButtonState extends State<VeloraPasswordButton> {
  bool _isSet = false;
  String _saved = '';
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    // The password can also change from the session window or the settings page.
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final isSet =
        (await bind.mainGetCommon(key: 'local-permanent-password-set')) ==
            'true';
    final saved =
        isSet ? await bind.mainGetCommon(key: 'velora-saved-password') : '';
    if (!mounted || (isSet == _isSet && saved == _saved)) return;
    setState(() {
      _isSet = isSet;
      _saved = saved;
      if (!isSet) _visible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSet) {
      return OutlinedButton.icon(
        onPressed: () => setPasswordDialog(notEmptyCallback: _refresh),
        icon: const Icon(Icons.key_rounded, size: 18),
        label: const Text('Definir acesso não supervisionado (definir senha)'),
      );
    }
    const green = Color(0xFF2E9E5B);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: green.withOpacity(0.6)),
        color: green.withOpacity(0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.verified_user_rounded, size: 18, color: green),
            SizedBox(width: 8),
            Flexible(
              child: Text('Acesso não supervisionado ativo (senha salva)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.lock_rounded, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: _saved.isEmpty
                  ? const Text(
                      'Senha definida antes desta versão. Altere a senha para poder vê-la aqui.',
                      style: TextStyle(fontSize: 12))
                  : SelectableText(
                      _visible ? _saved : '•' * _saved.length,
                      style: const TextStyle(fontSize: 16, letterSpacing: 1),
                    ),
            ),
            if (_saved.isNotEmpty) ...[
              IconButton(
                tooltip: _visible ? 'Esconder senha' : 'Ver senha',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                    _visible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 18),
                onPressed: () => setState(() => _visible = !_visible),
              ),
              IconButton(
                tooltip: 'Copiar senha',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _saved));
                  showToast(translate('Copied'));
                },
              ),
            ],
            IconButton(
              tooltip: 'Alterar ou remover senha',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_rounded, size: 18),
              onPressed: () => setPasswordDialog(notEmptyCallback: _refresh),
            ),
          ]),
        ],
      ),
    );
  }
}

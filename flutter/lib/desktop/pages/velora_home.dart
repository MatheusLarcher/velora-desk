import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart'
    show setPasswordDialog;
import 'package:flutter_hbb/models/platform_model.dart';

const _kStartWithWindows = 'velora-start-with-windows';

/// Simplified Velora start screen. The full RustDesk screen stays one click
/// away behind "Avançado".
class VeloraHomePanel extends StatefulWidget {
  final VoidCallback onAdvanced;
  const VeloraHomePanel({Key? key, required this.onAdvanced}) : super(key: key);

  @override
  State<VeloraHomePanel> createState() => _VeloraHomePanelState();
}

class _VeloraHomePanelState extends State<VeloraHomePanel> {
  final _remoteId = TextEditingController();

  @override
  void dispose() {
    _remoteId.dispose();
    super.dispose();
  }

  void _connect() {
    final id = _remoteId.text.replaceAll(' ', '');
    if (id.isNotEmpty) connect(context, id);
  }

  Widget _section(String title, List<Widget> children) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final model = gFFI.serverModel;
    final installed = bind.mainIsInstalled();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            loadIcon(36),
            const SizedBox(width: 10),
            const Text('Velora',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(
                onPressed: widget.onAdvanced, child: const Text('Avançado')),
          ]),
          const SizedBox(height: 16),
          _section('Seu código de acesso', [
            Row(children: [
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: model.serverId,
                  builder: (_, v, __) => SelectableText(v.text,
                      style: const TextStyle(fontSize: 26, letterSpacing: 2)),
                ),
              ),
              IconButton(
                tooltip: 'Copiar',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: model.serverId.text));
                  showToast(translate('Copied'));
                },
              ),
            ]),
            const Text(
                'Passe este código para o suporte. Cada acesso precisa da sua confirmação, a menos que você defina uma senha.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setPasswordDialog(),
              child: const Text('Definir acesso não supervisionado (definir senha)'),
            ),
          ]),
          _section('Acessar outro PC', [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _remoteId,
                  decoration: const InputDecoration(
                      hintText: 'Código do outro PC', isDense: true),
                  onSubmitted: (_) => _connect(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _connect, child: const Text('Conectar')),
            ]),
          ]),
          if (!installed)
            _section('Inicialização', [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: bind.mainGetLocalOption(key: _kStartWithWindows) == 'Y',
                title: const Text('Abrir o Velora quando o Windows iniciar'),
                onChanged: (v) async {
                  await bind.mainSetLocalOption(
                      key: _kStartWithWindows, value: v == true ? 'Y' : 'N');
                  setState(() {});
                },
              ),
            ]),
          if (!installed)
            _section('Instalação', [
              const Text(
                  'Instalar deixa o Velora disponível depois de reiniciar o PC. Pede permissão de administrador uma vez.',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              ElevatedButton(
                  onPressed: () => bind.mainGotoInstall(),
                  child: const Text('Instalar')),
            ]),
        ],
      ),
    );
  }
}

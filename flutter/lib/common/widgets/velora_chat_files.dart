import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';

/// Folder where files sent through the session chat are saved on this device.
class VeloraChatFolderSetting extends StatefulWidget {
  const VeloraChatFolderSetting({Key? key}) : super(key: key);

  @override
  State<VeloraChatFolderSetting> createState() =>
      _VeloraChatFolderSettingState();
}

class _VeloraChatFolderSettingState extends State<VeloraChatFolderSetting> {
  String _folder = '';
  bool _custom = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final folder = await bind.mainGetCommon(key: kOptionVeloraChatFilesDir);
    final custom = await bind.mainGetOption(key: kOptionVeloraChatFilesDir);
    if (!mounted) return;
    setState(() {
      _folder = folder;
      _custom = custom.trim().isNotEmpty;
    });
  }

  Future<void> _change() async {
    final dir = await FilePicker.platform
        .getDirectoryPath(dialogTitle: 'Pasta para os arquivos recebidos');
    if (dir == null || dir.isEmpty) return;
    await bind.mainSetOption(key: kOptionVeloraChatFilesDir, value: dir);
    await _load();
  }

  Future<void> _reset() async {
    await bind.mainSetOption(key: kOptionVeloraChatFilesDir, value: '');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
            'Arquivos enviados pelo chat de uma sessão são salvos nesta pasta.',
            style: TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.folder_rounded, size: 18, color: MyTheme.accent),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(_folder.isEmpty ? '-' : _folder)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 4, children: [
          OutlinedButton.icon(
            onPressed: _change,
            icon: const Icon(Icons.drive_folder_upload_rounded, size: 18),
            label: const Text('Alterar pasta'),
          ),
          if (_custom)
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Voltar para Downloads'),
            ),
        ]),
      ],
    );
  }
}

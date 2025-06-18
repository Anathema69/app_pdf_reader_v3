// lib/main.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'pdf_qr_service.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF → QR → JSON',
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _json = '';

  Future<void> _pickAndProcess() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) {
      setState(() => _json = '{}');
      return;
    }

    final path = result.files.single.path!;
    final map = await extractQrJsonFromPdf(path);
    setState(() => _json = const JsonEncoder.withIndent('  ').convert(map));
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF → QR → JSON')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          ElevatedButton(
            onPressed: _pickAndProcess,
            child: const Text('Seleccionar PDF'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(_json, style: const TextStyle(fontFamily: 'Courier')),
            ),
          ),
        ]),
      ),
    );
  }
}

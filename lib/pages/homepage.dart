import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_langchain/services/langchain.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _responseController = TextEditingController();
  final AssistantRAG assistantRAG = AssistantRAG();
  String? _filePath;
  bool _isLoadingFile = false;
  bool _isLoadingQuery = false;
  List<String> _addedFiles = [];
  @override
  void initState() {
    super.initState();
    _loadAddedFiles();
  }

  Future<void> _loadAddedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _addedFiles = prefs.getStringList('addedFiles') ?? [];
    });
  }

  Future<void> _saveAddedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('addedFiles', _addedFiles);
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path;
      });
    }
  }

  void _addConversation() async {
    if (_filePath != null) {
      setState(() {
        _isLoadingFile = true;
      });

      final DateTime? selectedDateTime = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );

      if (selectedDateTime != null) {
        final TimeOfDay? selectedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );

        if (selectedTime != null) {
          final DateTime finalDateTime = DateTime(
            selectedDateTime.year,
            selectedDateTime.month,
            selectedDateTime.day,
            selectedTime.hour,
            selectedTime.minute,
          );

          final success = await assistantRAG.addConversation(
              _filePath!, finalDateTime.toString());

          if (success) {
            setState(() {
              _addedFiles.add(File(_filePath!).uri.pathSegments.last);
              _saveAddedFiles();
              _filePath = null;
              _isLoadingFile = false;
            });
          } else {
            setState(() {
              _isLoadingFile = false;
            });
          }
        } else {
          setState(() {
            _isLoadingFile = false;
          });
        }
      } else {
        setState(() {
          _isLoadingFile = false;
        });
      }
    }
  }

  void _askQuery() async {
    setState(() {
      _isLoadingQuery = true;
    });

    final response = await assistantRAG.askQuestion(_queryController.text);
    setState(() {
      _responseController.text = response;
      _isLoadingQuery = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: <Widget>[
            ElevatedButton(
              onPressed: _pickFile,
              child: const Text('Select .txt File'),
            ),
            if (_filePath != null)
              Text('Selected file: ${File(_filePath!).uri.pathSegments.last}'),
            ElevatedButton(
              onPressed: _isLoadingFile ? null : _addConversation,
              child: _isLoadingFile
                  ? const CircularProgressIndicator()
                  : const Text('Submit File'),
            ),
            if (_addedFiles.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Added files:'),
                  for (var file in _addedFiles) Text(file),
                ],
              ),
            TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                hintText: 'Ask AI...',
              ),
            ),
            ElevatedButton(
              onPressed: _isLoadingQuery ? null : _askQuery,
              child: _isLoadingQuery
                  ? const CircularProgressIndicator()
                  : const Text('Submit Query'),
            ),
            Expanded(
              child: TextField(
                controller: _responseController,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Response',
                ),
                readOnly: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

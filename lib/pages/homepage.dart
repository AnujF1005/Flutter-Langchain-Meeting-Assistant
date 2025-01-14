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
  List<Map<String, String>> _addedFiles = [];
  Map<String, bool> _isDeleting = {};

  @override
  void initState() {
    super.initState();
    _loadAddedFiles();
  }

  Future<void> _loadAddedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? addedFiles = prefs.getStringList('addedFiles');
    if (addedFiles != null) {
      setState(() {
        _addedFiles = addedFiles.map((file) {
          final parts = file.split('|');
          return {'id': parts[0], 'name': parts[1]};
        }).toList();
      });
    }
  }

  Future<void> _saveAddedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> addedFiles = _addedFiles.map((file) {
      return '${file['id']}|${file['name']}';
    }).toList();
    await prefs.setStringList('addedFiles', addedFiles);
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

          final result = await assistantRAG.addConversation(
              _filePath!, finalDateTime.toString());

          if (result['success']) {
            setState(() {
              _addedFiles.add({
                'id': result['id'],
                'name': File(_filePath!).uri.pathSegments.last,
              });
              _saveAddedFiles();
              _filePath = null;
              _isLoadingFile = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Conversation added successfully'),
              ),
            );
          } else {
            setState(() {
              _isLoadingFile = false;
            });
            final err = result['error'];
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $err'),
              ),
            );
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

  void _deleteFile(String id, String file) async {
    setState(() {
      _isDeleting[id] = true;
    });

    final result = await assistantRAG.deleteConversation(id);
    if (!result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${result['error']}'),
        ),
      );
      setState(() {
        _isDeleting.remove(id);
      });
      return;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversation deleted successfully'),
        ),
      );
    }
    setState(() {
      _addedFiles.removeWhere((file) => file['id'] == id);
      _isDeleting.remove(id);
    });
    await _saveAddedFiles();
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                'Added Files',
                style: TextStyle(
                  fontSize: 24,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
            for (var file in _addedFiles)
              ListTile(
                title: Text(file['name']!),
                trailing: _isDeleting[file['id']] == true
                    ? const CircularProgressIndicator()
                    : IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () =>
                            _deleteFile(file['id']!, file['name']!),
                      ),
              ),
          ],
        ),
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
            TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                hintText: 'Ask AI...',
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isLoadingQuery ? null : _askQuery,
                  child: _isLoadingQuery
                      ? const CircularProgressIndicator()
                      : const Text('Submit Query'),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: Icon(Icons.refresh),
                  color: Colors.red,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Refresh Chat History'),
                          content: const Text(
                              'Are you sure you want to refresh the chat history?'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                assistantRAG.clearMemory();
                                Navigator.of(context).pop();
                              },
                              child: const Text('Refresh'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
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

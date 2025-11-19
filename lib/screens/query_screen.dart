import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sembast_cli_gui/widgets/query_editor_widget.dart';
import 'package:sembast_cli_gui/widgets/results_grid_widget.dart';
import 'package:sembast_cli_gui/src/database_connector.dart';
import 'package:sembast_cli_gui/src/query_engine.dart';

class QueryScreen extends StatefulWidget {
  const QueryScreen({super.key});

  @override
  State<QueryScreen> createState() => _QueryScreenState();
}

class _QueryScreenState extends State<QueryScreen> {
  DatabaseConnector? _connector;
  String? _dbPath;
  String? _error;
  
  // Query state
  String _queryText = '';
  List<Map<String, dynamic>> _queryResults = [];
  String? _currentStore;
  bool _isExecutingQuery = false;

  @override
  void dispose() {
    _connector?.close();
    super.dispose();
  }

  Future<void> _openDatabase() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select Sembast Database File',
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        await _loadDatabase(path);
      }
    } catch (e) {
      setState(() {
        _error = 'Error opening database: $e';
      });
    }
  }

  Future<void> _loadDatabase(String path) async {
    setState(() {
      _error = null;
      _dbPath = path;
      _currentStore = null;
      _queryResults = [];
    });

    try {
      final connector = DatabaseConnector(path);
      await connector.open();
      
      setState(() {
        _connector = connector;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading database: $e';
      });
    }
  }

  Future<void> _executeQuery() async {
    if (_connector == null || _currentStore == null) {
      setState(() {
        _error = 'Please select a database and store first';
      });
      return;
    }

    if (_queryText.trim().isEmpty) {
      setState(() {
        _error = 'Please enter a query';
      });
      return;
    }

    setState(() {
      _isExecutingQuery = true;
      _error = null;
    });

    try {
      // Load all records from the store
      final allRecords = await _connector!.getStoreRecords(_currentStore!);
      
      // Execute query using query engine
      final engine = QueryEngine();
      final results = await engine.executeQuery(_queryText, allRecords);
      
      setState(() {
        _queryResults = results;
        _isExecutingQuery = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Query execution error: $e';
        _isExecutingQuery = false;
      });
    }
  }

  void _setStore(String storeName) {
    setState(() {
      _currentStore = storeName;
      _queryResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sembast Query Client'),
        actions: [
          if (_dbPath != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadDatabase(_dbPath!),
              tooltip: 'Reload database',
            ),
        ],
      ),
      body: Column(
        children: [
          // Database info and store selector
          _buildDatabaseBar(),
          
          // Error display
          if (_error != null) _buildErrorBar(),
          
          // Query editor section
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Column(
                children: [
                  _buildQueryToolbar(),
                  Expanded(
                    child: QueryEditorWidget(
                      queryText: _queryText,
                      onQueryChanged: (text) {
                        setState(() {
                          _queryText = text;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Results section
          Expanded(
            flex: 3,
            child: _isExecutingQuery
                ? const Center(child: CircularProgressIndicator())
                : _queryResults.isEmpty
                    ? _buildEmptyResults()
                    : ResultsGridWidget(
                        data: _queryResults,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_dbPath != null)
                  Row(
                    children: [
                      Icon(Icons.storage, size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _dbPath!.split(Platform.pathSeparator).last,
                          style: Theme.of(context).textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'No database loaded',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                if (_currentStore != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.table_chart, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Store: $_currentStore',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_connector != null) ...[
            _buildStoreSelector(),
            const SizedBox(width: 8),
          ],
          ElevatedButton.icon(
            onPressed: _openDatabase,
            icon: const Icon(Icons.folder_open),
            label: const Text('Open DB'),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSelector() {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Store name',
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            _setStore(value.trim());
          }
        },
        controller: TextEditingController(text: _currentStore ?? '')
          ..selection = TextSelection.collapsed(
            offset: _currentStore?.length ?? 0,
          ),
      ),
    );
  }

  Widget _buildQueryToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Query',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _queryText = "contains('')";
              });
            },
            icon: const Icon(Icons.help_outline, size: 18),
            label: const Text('Examples'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isExecutingQuery ? null : _executeQuery,
            icon: _isExecutingQuery
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: const Text('Execute'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.red.shade50,
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red.shade900),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _error = null),
            color: Colors.red.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_chart_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No results yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a query and click Execute to see results',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }
}


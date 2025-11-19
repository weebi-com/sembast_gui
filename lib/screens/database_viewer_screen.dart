import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sembast_cli_gui/widgets/data_grid_widget.dart';
import 'package:sembast_cli_gui/widgets/stores_sidebar_widget.dart';
import 'package:sembast_cli_gui/widgets/query_editor_widget.dart';
import 'package:sembast_cli_gui/widgets/results_grid_widget.dart';
import 'package:sembast_cli_gui/src/database_connector.dart';
import 'package:sembast_cli_gui/src/query_engine.dart';

class DatabaseViewerScreen extends StatefulWidget {
  const DatabaseViewerScreen({super.key});

  @override
  State<DatabaseViewerScreen> createState() => _DatabaseViewerScreenState();
}

class _DatabaseViewerScreenState extends State<DatabaseViewerScreen> {
  DatabaseConnector? _connector;
  String? _dbPath;
  String? _currentStore;
  List<String> _availableStores = [];
  bool _isLoading = false;
  String? _error;
  
  // Query state
  int _selectedTab = 0; // 0 = Browse, 1 = Query
  String _queryText = '';
  List<Map<String, dynamic>> _queryResults = [];
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
      _isLoading = true;
      _error = null;
      _dbPath = path;
      _currentStore = null;
      _availableStores = [];
    });

    try {
      final connector = DatabaseConnector(path);
      await connector.open();
      
      // Discover stores by scanning the database file
      final discoveredStores = await connector.discoverStores();
      
      setState(() {
        _connector = connector;
        _isLoading = false;
        _availableStores = discoveredStores;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading database: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStore(String storeName) async {
    if (_connector == null) return;

    setState(() {
      _isLoading = true;
      _currentStore = storeName;
      _error = null;
    });

    try {
      // Verify store exists
      final exists = await _connector!.storeExists(storeName);
      if (!exists) {
        setState(() {
          _error = 'Store "$storeName" not found or empty';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading store: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sembast Database Viewer'),
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
          // Database info bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_dbPath != null)
                        Text(
                          'Database: ${_dbPath!.split(Platform.pathSeparator).last}',
                          style: Theme.of(context).textTheme.titleSmall,
                        )
                      else
                        Text(
                          'No database loaded',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      if (_currentStore != null)
                        Text(
                          'Store: $_currentStore',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openDatabase,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open Database'),
                ),
              ],
            ),
          ),

          // Error display
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _error = null),
                  ),
                ],
              ),
            ),

          // Main content area with split view
          Expanded(
            child: _connector == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.storage,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Open a Sembast database to get started',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _openDatabase,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Open Database'),
                        ),
                      ],
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stores sidebar
                      StoresSidebarWidget(
                        connector: _connector,
                        stores: _availableStores,
                        selectedStore: _currentStore,
                        onStoreSelected: (store) => _loadStore(store),
                      ),
                      // Main content area with tabs
                      Expanded(
                        child: Column(
                          children: [
                            // Tabs
                            Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Theme.of(context).dividerColor,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildTab(0, 'Browse', Icons.table_chart),
                                  _buildTab(1, 'Query', Icons.code),
                                ],
                              ),
                            ),
                            // Tab content
                            Expanded(
                              child: _selectedTab == 0
                                  ? _buildBrowseView()
                                  : _buildQueryView(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrowseView() {
    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : _currentStore == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.table_chart_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _availableStores.isEmpty
                          ? 'No stores found in database'
                          : 'Select a store to view data',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              )
            : DataGridWidget(
                key: ValueKey(_currentStore), // Force rebuild when store changes
                connector: _connector!,
                storeName: _currentStore!,
              );
  }

  Widget _buildQueryView() {
    if (_currentStore == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.code_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a store to query',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a store from the sidebar to start querying',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Query toolbar
        Container(
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
              PopupMenuButton<String>(
                tooltip: 'Query Examples',
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'count',
                    child: Text('count()'),
                  ),
                  const PopupMenuItem(
                    value: 'contains',
                    child: Text("contains('text')"),
                  ),
                  const PopupMenuItem(
                    value: 'field_contains',
                    child: Text("field('value').contains('text')"),
                  ),
                  const PopupMenuItem(
                    value: 'field_equals',
                    child: Text("field('value').equals('exact')"),
                  ),
                  const PopupMenuItem(
                    value: 'and',
                    child: Text("and(contains('a'), contains('b'))"),
                  ),
                  const PopupMenuItem(
                    value: 'or',
                    child: Text("or(contains('a'), contains('b'))"),
                  ),
                ],
                onSelected: (value) {
                  final examples = {
                    'count': 'count()',
                    'contains': "contains('')",
                    'field_contains': "field('value').contains('')",
                    'field_equals': "field('value').equals('')",
                    'and': "and(contains(''), contains(''))",
                    'or': "or(contains(''), contains(''))",
                  };
                  setState(() {
                    _queryText = examples[value] ?? '';
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.help_outline, size: 18),
                    SizedBox(width: 4),
                    Text('Examples'),
                  ],
                ),
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
        ),
        // Query editor
        Expanded(
          flex: 2,
          child: QueryEditorWidget(
            queryText: _queryText,
            onQueryChanged: (text) {
              setState(() {
                _queryText = text;
              });
            },
          ),
        ),
        // Results
        Expanded(
          flex: 3,
          child: _isExecutingQuery
              ? const Center(child: CircularProgressIndicator())
              : _queryResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.table_chart_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
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
                    )
                  : ResultsGridWidget(data: _queryResults),
        ),
      ],
    );
  }

  Future<void> _executeQuery() async {
    if (_connector == null || _currentStore == null) {
      setState(() {
        _error = 'Please select a store first';
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

}


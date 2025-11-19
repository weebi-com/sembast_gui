import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:sembast_cli_gui/src/database_connector.dart';

class DataGridWidget extends StatefulWidget {
  final DatabaseConnector connector;
  final String storeName;

  const DataGridWidget({
    super.key,
    required this.connector,
    required this.storeName,
  });

  @override
  State<DataGridWidget> createState() => _DataGridWidgetState();
}

class _DataGridWidgetState extends State<DataGridWidget> {
  late PlutoGridStateManager _stateManager;
  bool _isLoading = true;
  String? _error;
  List<PlutoColumn> _columns = [];
  List<PlutoRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(DataGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data if store name changed
    if (oldWidget.storeName != widget.storeName) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load first 1000 records
      final records = await widget.connector.getStoreRecordsLimited(widget.storeName, limit: 1000);

      if (records.isEmpty) {
        setState(() {
          _error = 'Store is empty';
          _isLoading = false;
        });
        return;
      }

      // Extract columns from first record
      final firstRecord = records.first;
      // Exclude _key from displayed columns, but keep it in the data
      final columnKeys = firstRecord.keys.where((k) => k != '_key').toList();

      // Create PlutoGrid columns (excluding _key)
      _columns = columnKeys.map((key) {
        return PlutoColumn(
          title: key,
          field: key,
          type: PlutoColumnType.text(),
          width: 150,
        );
      }).toList();

      // Create PlutoGrid rows
      _rows = records.map((record) {
        return PlutoRow(
          cells: Map.fromEntries(
            columnKeys.map((key) => MapEntry(
                  key,
                  PlutoCell(value: record[key]?.toString() ?? ''),
                )),
          ),
        );
      }).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_columns.isEmpty || _rows.isEmpty) {
      return const Center(child: Text('No data to display'));
    }

    return PlutoGrid(
      columns: _columns,
      rows: _rows,
      onLoaded: (PlutoGridOnLoadedEvent event) {
        _stateManager = event.stateManager;
        
        // Frozen column is already set via column definition
        
        // Configure grid settings
        _stateManager.setShowColumnFilter(true);
        _stateManager.setShowColumnFilter(true);
      },
      configuration: PlutoGridConfiguration(
        columnSize: const PlutoGridColumnSizeConfig(
          autoSizeMode: PlutoAutoSizeMode.scale,
        ),
        style: PlutoGridStyleConfig(
          gridBorderColor: Colors.grey.shade300,
          rowColor: Colors.white,
          evenRowColor: Colors.grey.shade50,
          activatedColor: Colors.blue.shade100,
          activatedBorderColor: Colors.blue,
          inactivatedBorderColor: Colors.grey.shade300,
          checkedColor: Colors.blue.shade400,
          gridBackgroundColor: Colors.white,
          columnTextStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          cellTextStyle: const TextStyle(fontSize: 14),
        ),
        columnFilter: const PlutoGridColumnFilterConfig(
          filters: [
            ...FilterHelper.defaultFilters,
          ],
        ),
      ),
    );
  }
}


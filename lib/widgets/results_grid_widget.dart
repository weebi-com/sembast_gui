import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pluto_grid/pluto_grid.dart';

class ResultsGridWidget extends StatefulWidget {
  final List<Map<String, dynamic>> data;

  const ResultsGridWidget({
    super.key,
    required this.data,
  });

  @override
  State<ResultsGridWidget> createState() => _ResultsGridWidgetState();
}

class _ResultsGridWidgetState extends State<ResultsGridWidget> {
  PlutoGridStateManager? _stateManager;
  List<PlutoColumn> _columns = [];
  List<PlutoRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _buildGridData();
  }

  @override
  void didUpdateWidget(ResultsGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _buildGridData();
    }
  }

  void _buildGridData() {
    if (widget.data.isEmpty) {
      _columns = [];
      _rows = [];
      return;
    }

    // Extract columns from first record
    final firstRecord = widget.data.first;
    // Exclude _key from displayed columns
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
    _rows = widget.data.asMap().entries.map((entry) {
      return PlutoRow(
        cells: Map.fromEntries(
          columnKeys.map((key) => MapEntry(
                key,
                PlutoCell(value: entry.value[key]?.toString() ?? ''),
              )),
        ),
      );
    }).toList();

    // Update state manager if it exists
    if (mounted && _stateManager != null && _stateManager!.columns.isNotEmpty) {
      _stateManager!.removeAllRows();
      _stateManager!.appendRows(_rows);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_columns.isEmpty || _rows.isEmpty) {
      return const Center(child: Text('No data to display'));
    }

    return Column(
      children: [
        // Results header
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
                'Results',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              Text(
                '${widget.data.length} row${widget.data.length != 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  // Copy results as CSV
                  _copyResultsAsCSV();
                },
                tooltip: 'Copy as CSV',
              ),
            ],
          ),
        ),
        // Grid
        Expanded(
          child: PlutoGrid(
            columns: _columns,
            rows: _rows,
            onLoaded: (PlutoGridOnLoadedEvent event) {
              _stateManager = event.stateManager;
              
              // Configure grid settings
              _stateManager?.setShowColumnFilter(true);
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
          ),
        ),
      ],
    );
  }

  void _copyResultsAsCSV() {
    if (_columns.isEmpty || _rows.isEmpty) return;

    final buffer = StringBuffer();
    
    // Header
    buffer.writeln(_columns.map((c) => c.title).join(','));
    
    // Rows
    for (final row in _rows) {
      final values = _columns.map((col) {
        final value = row.cells[col.field]?.value?.toString() ?? '';
        // Escape commas and quotes
        if (value.contains(',') || value.contains('"')) {
          return '"${value.replaceAll('"', '""')}"';
        }
        return value;
      });
      buffer.writeln(values.join(','));
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Results copied to clipboard')),
    );
  }
}


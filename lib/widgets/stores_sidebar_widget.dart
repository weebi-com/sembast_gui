import 'package:flutter/material.dart';
import 'package:sembast_cli_gui/src/database_connector.dart';

class StoresSidebarWidget extends StatefulWidget {
  final DatabaseConnector? connector;
  final List<String> stores;
  final String? selectedStore;
  final Function(String) onStoreSelected;

  const StoresSidebarWidget({
    super.key,
    required this.connector,
    required this.stores,
    this.selectedStore,
    required this.onStoreSelected,
  });

  @override
  State<StoresSidebarWidget> createState() => _StoresSidebarWidgetState();
}

class _StoresSidebarWidgetState extends State<StoresSidebarWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
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
                const Icon(Icons.storage, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Stores',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
          ),

          // Stores list
          Expanded(
            child: widget.stores.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No stores found',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Open a database to see stores',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.stores.length,
                    itemBuilder: (context, index) {
                      final store = widget.stores[index];
                      final isSelected = store == widget.selectedStore;

                      return InkWell(
                        onTap: () => widget.onStoreSelected(store),
                        onDoubleTap: () => widget.onStoreSelected(store),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.transparent,
                            border: Border(
                              left: BorderSide(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.table_chart,
                                size: 18,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  store,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.onPrimaryContainer
                                            : null,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


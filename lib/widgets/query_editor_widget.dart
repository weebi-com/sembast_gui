import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QueryEditorWidget extends StatefulWidget {
  final String queryText;
  final ValueChanged<String> onQueryChanged;

  const QueryEditorWidget({
    super.key,
    required this.queryText,
    required this.onQueryChanged,
  });

  @override
  State<QueryEditorWidget> createState() => _QueryEditorWidgetState();
}

class _QueryEditorWidgetState extends State<QueryEditorWidget> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.queryText);
  }

  @override
  void didUpdateWidget(QueryEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.queryText != _controller.text) {
      _controller.text = widget.queryText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: null,
        expands: true,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
          hintText: 'Enter query...\n\nExamples:\n  count()\n  contains(\'text\')\n  field(\'value\').contains(\'search\')\n  field(\'value\').equals(\'exact\')\n  and(contains(\'a\'), contains(\'b\'))\n  or(contains(\'a\'), contains(\'b\'))',
        ),
        onChanged: widget.onQueryChanged,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
      ),
    );
  }
}


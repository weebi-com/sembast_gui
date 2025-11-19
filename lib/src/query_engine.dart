/// Query engine for filtering records
/// Supports various query patterns for filtering and aggregating data
class QueryEngine {
  /// Execute a query expression
  /// Supports:
  /// - count() - returns count of all records
  /// - contains('text') - filters records containing text in any field
  /// - field('fieldName').contains('text') - filters by specific field
  /// - field('fieldName').equals('value') - exact match on field
  /// - and(contains('a'), contains('b')) - multiple conditions with AND
  /// - or(contains('a'), contains('b')) - multiple conditions with OR
  /// - Empty query returns all records
  Future<List<Map<String, dynamic>>> executeQuery(
    String query,
    List<Map<String, dynamic>> records,
  ) async {
    try {
      final trimmedQuery = query.trim();
      
      // Handle count query
      if (trimmedQuery.toLowerCase() == 'count()' || trimmedQuery.toLowerCase() == 'count') {
        return [
          {'_count': records.length}
        ];
      }
      
      // Handle empty query - return all records
      if (trimmedQuery.isEmpty) {
        return records;
      }
      
      // Apply filters
      return _executeFilter(trimmedQuery, records);
    } catch (e) {
      throw Exception('Query execution error: $e');
    }
  }

  /// Execute filter query
  List<Map<String, dynamic>> _executeFilter(
    String query,
    List<Map<String, dynamic>> records,
  ) {
    // Handle AND conditions: and(condition1, condition2)
    if (query.toLowerCase().startsWith('and(')) {
      return _handleAnd(query, records);
    }
    
    // Handle OR conditions: or(condition1, condition2)
    if (query.toLowerCase().startsWith('or(')) {
      return _handleOr(query, records);
    }
    
    // Handle field-specific queries: field('fieldName').contains('text')
    if (query.contains('field(')) {
      return _handleFieldQuery(query, records);
    }
    
    // Handle simple contains: contains('text')
    if (query.contains('contains(')) {
      return _handleContains(query, records);
    }
    
    // If no recognized pattern, return all records
    return records;
  }

  /// Handle contains() queries
  List<Map<String, dynamic>> _handleContains(
    String query,
    List<Map<String, dynamic>> records,
  ) {
    // Try single quotes first
    RegExp? pattern = RegExp(r"contains\s*\(\s*'(.*?)'\s*\)", caseSensitive: false);
    var match = pattern.firstMatch(query);
    
    // If no match, try double quotes
    if (match == null) {
      pattern = RegExp(r'contains\s*\(\s*"(.*?)"\s*\)', caseSensitive: false);
      match = pattern.firstMatch(query);
    }
    
    if (match != null && match.groupCount >= 1) {
      final searchTerm = match.group(1);
      if (searchTerm != null) {
        final lowerSearchTerm = searchTerm.toLowerCase();
        return records.where((r) {
          return r.values.any((v) => 
            v.toString().toLowerCase().contains(lowerSearchTerm));
        }).toList();
      }
    }
    
    return records;
  }

  /// Handle field-specific queries: field('fieldName').contains('text')
  List<Map<String, dynamic>> _handleFieldQuery(
    String query,
    List<Map<String, dynamic>> records,
  ) {
    // Extract field name: field('fieldName') - try single quotes first
    RegExp? fieldPattern = RegExp(r"field\s*\(\s*'(.*?)'\s*\)", caseSensitive: false);
    var fieldMatch = fieldPattern.firstMatch(query);
    
    // If no match, try double quotes
    if (fieldMatch == null) {
      fieldPattern = RegExp(r'field\s*\(\s*"(.*?)"\s*\)', caseSensitive: false);
      fieldMatch = fieldPattern.firstMatch(query);
    }
    
    if (fieldMatch == null || fieldMatch.groupCount < 1) {
      return records;
    }
    
    final fieldName = fieldMatch.group(1);
    if (fieldName == null) {
      return records;
    }
    
    // Handle field().contains()
    if (query.contains('.contains(')) {
      // Try single quotes first
      RegExp? containsPattern = RegExp(r"\.contains\s*\(\s*'(.*?)'\s*\)", caseSensitive: false);
      var containsMatch = containsPattern.firstMatch(query);
      
      // If no match, try double quotes
      if (containsMatch == null) {
        containsPattern = RegExp(r'\.contains\s*\(\s*"(.*?)"\s*\)', caseSensitive: false);
        containsMatch = containsPattern.firstMatch(query);
      }
      
      if (containsMatch != null && containsMatch.groupCount >= 1) {
        final searchTerm = containsMatch.group(1);
        if (searchTerm != null) {
          final lowerSearchTerm = searchTerm.toLowerCase();
          return records.where((r) {
            final fieldValue = r[fieldName]?.toString().toLowerCase() ?? '';
            return fieldValue.contains(lowerSearchTerm);
          }).toList();
        }
      }
    }
    
    // Handle field().equals()
    if (query.contains('.equals(')) {
      // Try single quotes first
      RegExp? equalsPattern = RegExp(r"\.equals\s*\(\s*'(.*?)'\s*\)", caseSensitive: false);
      var equalsMatch = equalsPattern.firstMatch(query);
      
      // If no match, try double quotes
      if (equalsMatch == null) {
        equalsPattern = RegExp(r'\.equals\s*\(\s*"(.*?)"\s*\)', caseSensitive: false);
        equalsMatch = equalsPattern.firstMatch(query);
      }
      
      if (equalsMatch != null && equalsMatch.groupCount >= 1) {
        final searchTerm = equalsMatch.group(1);
        if (searchTerm != null) {
          return records.where((r) {
            return r[fieldName]?.toString() == searchTerm;
          }).toList();
        }
      }
    }
    
    return records;
  }

  /// Handle AND conditions: and(condition1, condition2)
  List<Map<String, dynamic>> _handleAnd(
    String query,
    List<Map<String, dynamic>> records,
  ) {
    // Extract conditions from and(condition1, condition2)
    final conditions = _extractConditions(query.substring(4)); // Skip "and("
    
    if (conditions.isEmpty) {
      return records;
    }
    
    // Apply all conditions - record must match all
    var result = records;
    for (final condition in conditions) {
      result = _executeFilter(condition.trim(), result);
    }
    
    return result;
  }

  /// Handle OR conditions: or(condition1, condition2)
  List<Map<String, dynamic>> _handleOr(
    String query,
    List<Map<String, dynamic>> records,
  ) {
    // Extract conditions from or(condition1, condition2)
    final conditions = _extractConditions(query.substring(3)); // Skip "or("
    
    if (conditions.isEmpty) {
      return records;
    }
    
    // Apply conditions - record must match at least one
    final Set<Map<String, dynamic>> resultSet = {};
    for (final condition in conditions) {
      final filtered = _executeFilter(condition.trim(), records);
      resultSet.addAll(filtered);
    }
    
    // Preserve order by converting back to list
    return resultSet.toList();
  }

  /// Extract conditions from nested parentheses
  List<String> _extractConditions(String query) {
    final conditions = <String>[];
    int depth = 0;
    int start = 0;
    
    for (int i = 0; i < query.length; i++) {
      if (query[i] == '(') {
        depth++;
      } else if (query[i] == ')') {
        depth--;
        if (depth == 0 && i < query.length - 1) {
          // End of first condition
          conditions.add(query.substring(start, i + 1));
          // Skip comma and whitespace
          start = i + 1;
          while (start < query.length && (query[start] == ',' || query[start].trim().isEmpty)) {
            start++;
          }
        }
      } else if (query[i] == ',' && depth == 0) {
        // Top-level comma - separate condition
        conditions.add(query.substring(start, i));
        start = i + 1;
        while (start < query.length && query[start].trim().isEmpty) {
          start++;
        }
      }
    }
    
    // Add remaining condition
    if (start < query.length) {
      final remaining = query.substring(start).trim();
      if (remaining.isNotEmpty && remaining != ')') {
        conditions.add(remaining.replaceAll(RegExp(r'\)+$'), ''));
      }
    }
    
    return conditions;
  }
}


import 'package:flutter/material.dart';
import 'package:receipto/models/transaction.dart' as model;

/// Screen for manually adding or editing a transaction.
///
/// Stub implementation — fully built in Step 4.
class AddEditTransactionScreen extends StatelessWidget {
  final model.Transaction? transaction;

  const AddEditTransactionScreen({super.key, this.transaction});

  @override
  Widget build(BuildContext context) {
    final isEditing = transaction != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: const Center(
        child: Text('Transaction form — coming in Step 4'),
      ),
    );
  }
}

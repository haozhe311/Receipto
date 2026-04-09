import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/providers/payment_method_provider.dart';

/// Full-page screen for adding and deleting payment methods.
///
/// Navigated to from the Settings screen via a nav tile.
class ManagePaymentMethodsScreen extends StatelessWidget {
  const ManagePaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Payment Methods')),
      body: Consumer<PaymentMethodProvider>(
        builder: (context, provider, _) {
          final methods = provider.methods;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Payment method list
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < methods.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 0,
                          color: AppTheme.border,
                        ),
                      _PaymentMethodRow(
                        method: methods[i],
                        onDelete:
                            (methods[i] == 'Cash' || methods[i] == 'Others')
                                ? null
                                : () => provider.deleteMethod(methods[i]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Add payment method button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddDialog(context, provider),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Payment Method'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context, PaymentMethodProvider provider) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Payment Method'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Payment method name',
              hintText: 'e.g. Boost, Wise, Debit Card',
            ),
            textCapitalization: TextCapitalization.words,
            maxLength: 30,
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) { return 'Name cannot be empty'; }
              if (provider.methods.any(
                (m) => m.toLowerCase() == trimmed.toLowerCase(),
              )) {
                return 'Payment method already exists';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) { return; }
              await provider.addMethod(controller.text.trim());
              if (ctx.mounted) { Navigator.of(ctx).pop(); }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }
}

class _PaymentMethodRow extends StatelessWidget {
  final String method;
  final VoidCallback? onDelete;

  const _PaymentMethodRow({required this.method, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.credit_card, size: 20, color: AppTheme.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              method,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            ),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: const Color(0xFFFF6B6B),
              tooltip: 'Delete payment method',
            )
          else
            const Icon(Icons.lock_outline, size: 16, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

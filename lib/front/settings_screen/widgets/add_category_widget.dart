import 'package:flutter/material.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/utils/enums.dart';

class AddCategoryWidget extends StatefulWidget {
  @override
  _AddCategoryWidgetState createState() => _AddCategoryWidgetState();
}

class _AddCategoryWidgetState extends State<AddCategoryWidget> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';
  Color _color = Colors.blue;
  IconData _icon = Icons.category;
  TransactionType _type = TransactionType.expense;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Category'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Title is required' : null,
                onSaved: (value) => _title = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                onSaved: (value) => _description = value ?? '',
              ),
              DropdownButtonFormField<Color>(
                value: _color,
                decoration: const InputDecoration(labelText: 'Color'),
                items: [
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.orange,
                  Colors.purple,
                  Colors.yellow,
                ]
                    .map((color) => DropdownMenuItem(
                          value: color,
                          child: Container(
                            width: 24,
                            height: 24,
                            color: color,
                          ),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _color = value!),
              ),
              DropdownButtonFormField<IconData>(
                value: _icon,
                decoration: const InputDecoration(labelText: 'Icon'),
                items: [
                  Icons.category, // Add the default value to the list
                  Icons.fastfood,
                  Icons.directions_car,
                  Icons.movie,
                  Icons.attach_money,
                  Icons.local_hospital,
                  Icons.lightbulb,
                ]
                    .map((icon) => DropdownMenuItem(
                          value: icon,
                          child: Icon(icon),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _icon = value!),
              ),
              DropdownButtonFormField<TransactionType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: TransactionType.values
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.toString().split('.').last),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _type = value!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              final newCategory = Category(
                title: _title,
                descriptionForAI: _description,
                colorValue: _color.value,
                iconCodePoint: _icon.codePoint,
                typeValue: _type.index,
              );
              Navigator.of(context).pop(newCategory);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

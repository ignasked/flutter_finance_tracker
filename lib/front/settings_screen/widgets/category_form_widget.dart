import 'package:flutter/material.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:money_owl/backend/utils/app_style.dart';

class CategoryFormWidget extends StatefulWidget {
  final Category? initialCategory;

  const CategoryFormWidget({this.initialCategory, super.key});

  @override
  _CategoryFormWidgetState createState() => _CategoryFormWidgetState();
}

class _CategoryFormWidgetState extends State<CategoryFormWidget> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late Category _categoryState;

  @override
  void initState() {
    super.initState();
    // Initialize the state with a copy of the initial category or a new category
    _categoryState = widget.initialCategory?.copyWith() ??
        Category(
          title: '',
          descriptionForAI: '',
          colorValue: AppStyle.predefinedColors.first.value,
          iconCodePoint: AppStyle.predefinedIcons.first.codePoint,
          typeValue: TransactionType.expense.index,
        );

    _titleController = TextEditingController(text: _categoryState.title);
    _descriptionController =
        TextEditingController(text: _categoryState.descriptionForAI);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.initialCategory == null ? 'Add Category' : 'Edit Category'),
      content: Form(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                onChanged: (value) => setState(() {
                  _categoryState = _categoryState.copyWith(title: value);
                }),
              ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                onChanged: (value) => setState(() {
                  _categoryState =
                      _categoryState.copyWith(descriptionForAI: value);
                }),
              ),
              DropdownButtonFormField<Color>(
                value: AppStyle.predefinedColors
                        .contains(Color(_categoryState.colorValue))
                    ? Color(_categoryState.colorValue)
                    : AppStyle.predefinedColors.first,
                decoration: const InputDecoration(labelText: 'Color'),
                items: AppStyle.predefinedColors
                    .map((color) => DropdownMenuItem(
                          value: color,
                          child: Container(
                            width: 24,
                            height: 24,
                            color: color,
                          ),
                        ))
                    .toList(),
                onChanged: (value) => setState(() {
                  _categoryState =
                      _categoryState.copyWith(colorValue: value?.value);
                }),
              ),
              DropdownButtonFormField<IconData>(
                value: IconData(_categoryState.iconCodePoint,
                    fontFamily: 'MaterialIcons'),
                decoration: const InputDecoration(labelText: 'Icon'),
                items: AppStyle.predefinedIcons
                    .map((icon) => DropdownMenuItem(
                          value: icon,
                          child: Icon(icon),
                        ))
                    .toList(),
                onChanged: (value) => setState(() {
                  _categoryState =
                      _categoryState.copyWith(iconCodePoint: value!.codePoint);
                }),
              ),
              DropdownButtonFormField<TransactionType>(
                value: TransactionType.values[_categoryState.typeValue],
                decoration: const InputDecoration(labelText: 'Type'),
                items: TransactionType.values
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.toString().split('.').last),
                        ))
                    .toList(),
                onChanged: (value) => setState(() {
                  _categoryState =
                      _categoryState.copyWith(typeValue: value!.index);
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, _categoryState);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

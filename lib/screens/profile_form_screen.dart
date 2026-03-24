import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safemed/data/substance_risk_tables.dart';
import 'package:safemed/models/profile.dart';
import 'package:safemed/services/profile_store.dart';

class ProfileFormScreen extends StatefulWidget {
  final Profile? profile;

  const ProfileFormScreen({super.key, this.profile});

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _healthController = TextEditingController();
  final _picker = ImagePicker();

  String? _photoPath;
  BiologicalSex _sex = BiologicalSex.male;
  bool _isPregnant = false;
  bool _renalDisease = false;
  bool _hepaticDisease = false;
  bool _diabetes = false;
  bool _hypertension = false;
  List<String> _allergies = [];
  List<String> _medicalRestrictions = [];
  ProfileType _category = ProfileType.adult;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    if (profile != null) {
      _nameController.text = profile.name;
      _ageController.text = profile.age.toString();
      _healthController.text = profile.healthIssues;
      _photoPath = profile.photoPath;
      _sex = profile.sex;
      _isPregnant = profile.isPregnant;
      _renalDisease = profile.renalDisease;
      _hepaticDisease = profile.hepaticDisease;
      _diabetes = profile.diabetes;
      _hypertension = profile.hypertension;
      _allergies = List.from(profile.allergies);
      _medicalRestrictions = List.from(profile.medicalRestrictions);
      _category = profile.category;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _healthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.profile != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit profile' : 'New profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundImage: _photoProvider(),
              child: _photoProvider() == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Add photo'),
              ),
              if (_photoPath != null && _photoPath!.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _photoPath = null),
                  child: const Text('Remove'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ageController,
            decoration: const InputDecoration(
              labelText: 'Age',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              // Auto-suggest category based on age
              final age = int.tryParse(value);
              if (age != null && widget.profile == null) {
                setState(() {
                  _category = ProfileType.fromAge(age);
                });
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<BiologicalSex>(
            value: _sex,
            decoration: const InputDecoration(
              labelText: 'Sexo',
              border: OutlineInputBorder(),
            ),
            items: BiologicalSex.values
                .map(
                  (sex) => DropdownMenuItem(
                    value: sex,
                    child: Text(sex.displayName),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _sex = value;
                if (_sex == BiologicalSex.male) {
                  _isPregnant = false;
                }
              });
            },
          ),
          if (_sex == BiologicalSex.female)
            CheckboxListTile(
              title: const Text('Gravida'),
              value: _isPregnant,
              onChanged: (v) => setState(() => _isPregnant = v ?? false),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ProfileType>(
            value: _category,
            decoration: const InputDecoration(
              labelText: 'Profile Category',
              border: OutlineInputBorder(),
            ),
            items: ProfileType.values
                .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _category = value);
              }
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Conditions',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          CheckboxListTile(
            title: const Text('Renal disease'),
            value: _renalDisease,
            onChanged: (v) => setState(() => _renalDisease = v ?? false),
          ),
          CheckboxListTile(
            title: const Text('Hepatic disease'),
            value: _hepaticDisease,
            onChanged: (v) => setState(() => _hepaticDisease = v ?? false),
          ),
          CheckboxListTile(
            title: const Text('Diabetes'),
            value: _diabetes,
            onChanged: (v) => setState(() => _diabetes = v ?? false),
          ),
          CheckboxListTile(
            title: const Text('Hypertension'),
            value: _hypertension,
            onChanged: (v) => setState(() => _hypertension = v ?? false),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _healthController,
            decoration: const InputDecoration(
              labelText: 'Other issues',
              hintText: 'e.g. asthma, allergies',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Allergies',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: _addAllergy,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_allergies.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No allergies recorded',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._allergies.asMap().entries.map((entry) {
              final index = entry.key;
              final allergy = entry.value;
              return Card(
                key: ValueKey('allergy_$index'),
                child: ListTile(
                  title: Text(allergy),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeAllergy(allergy),
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Medical Restrictions',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: _addMedicalRestriction,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_medicalRestrictions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No restrictions recorded',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._medicalRestrictions.asMap().entries.map((entry) {
              final index = entry.key;
              final restriction = entry.value;
              return Card(
                key: ValueKey('restriction_$index'),
                child: ListTile(
                  title: Text(restriction),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeMedicalRestriction(restriction),
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saveProfile,
            child: Text(isEditing ? 'Save changes' : 'Create profile'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      return;
    }
    setState(() {
      _photoPath = image.path;
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final ageValue = int.tryParse(_ageController.text.trim());

    if (name.isEmpty || ageValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name and valid age.')),
      );
      return;
    }

    final healthIssues = _healthController.text.trim();
    final store = ProfileStore.instance;

    if (widget.profile == null) {
      final newProfile = Profile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        age: ageValue,
        sex: _sex,
        isPregnant: _sex == BiologicalSex.female ? _isPregnant : false,
        photoPath: _photoPath,
        renalDisease: _renalDisease,
        hepaticDisease: _hepaticDisease,
        diabetes: _diabetes,
        hypertension: _hypertension,
        healthIssues: healthIssues,
        allergies: _allergies,
        medicalRestrictions: _medicalRestrictions,
        category: _category,
      );
      await store.add(newProfile);
    } else {
      final updated = widget.profile!.copyWith(
        name: name,
        age: ageValue,
        sex: _sex,
        isPregnant: _sex == BiologicalSex.female ? _isPregnant : false,
        photoPath: _photoPath,
        renalDisease: _renalDisease,
        hepaticDisease: _hepaticDisease,
        diabetes: _diabetes,
        hypertension: _hypertension,
        healthIssues: healthIssues,
        allergies: _allergies,
        medicalRestrictions: _medicalRestrictions,
        category: _category,
      );
      await store.update(updated);
    }

    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _addAllergy() async {
    final options = allergySubstanceRules
        .map((rule) => rule.allergyKeyword)
        .toSet()
        .toList()
      ..sort();

    final allergy = await showDialog<String>(
      context: context,
      builder: (_) => _AllergyPickerDialog(
        options: options,
        selected: _allergies,
      ),
    );

    if (allergy != null && allergy.isNotEmpty && !_allergies.contains(allergy)) {
      setState(() => _allergies.add(allergy));
    }
  }

  void _removeAllergy(String allergy) {
    setState(() => _allergies.remove(allergy));
  }

  Future<void> _addMedicalRestriction() async {
    final controller = TextEditingController();
    final restriction = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Medical Restriction'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'e.g., Cannot swallow pills, Lactose intolerant',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            maxLines: 2,
            onChanged: (_) => setDialogState(() {}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (restriction != null && restriction.isNotEmpty && !_medicalRestrictions.contains(restriction)) {
      setState(() => _medicalRestrictions.add(restriction));
    }
  }

  void _removeMedicalRestriction(String restriction) {
    setState(() => _medicalRestrictions.remove(restriction));
  }

  ImageProvider? _photoProvider() {
    final path = _photoPath;
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    return FileImage(file);
  }
}

class _AllergyPickerDialog extends StatefulWidget {
  final List<String> options;
  final List<String> selected;

  const _AllergyPickerDialog({
    required this.options,
    required this.selected,
  });

  @override
  State<_AllergyPickerDialog> createState() => _AllergyPickerDialogState();
}

class _AllergyPickerDialogState extends State<_AllergyPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.of(widget.options);
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = List.of(widget.options);
      } else {
        _filtered = widget.options
            .where((item) => item.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 520,
        height: 500,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Escolher alergia',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Pesquisar alergia...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(child: Text('Sem resultados'))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
                          final alreadySelected = widget.selected.contains(item);
                          return ListTile(
                            title: Text(item),
                            trailing: alreadySelected
                                ? const Icon(Icons.check, color: Colors.green)
                                : null,
                            enabled: !alreadySelected,
                            onTap: alreadySelected
                                ? null
                                : () => Navigator.pop(context, item),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

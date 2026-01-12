import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  bool _renalDisease = false;
  bool _hepaticDisease = false;
  bool _diabetes = false;
  bool _hypertension = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    if (profile != null) {
      _nameController.text = profile.name;
      _ageController.text = profile.age.toString();
      _healthController.text = profile.healthIssues;
      _photoPath = profile.photoPath;
      _renalDisease = profile.renalDisease;
      _hepaticDisease = profile.hepaticDisease;
      _diabetes = profile.diabetes;
      _hypertension = profile.hypertension;
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
        photoPath: _photoPath,
        renalDisease: _renalDisease,
        hepaticDisease: _hepaticDisease,
        diabetes: _diabetes,
        hypertension: _hypertension,
        healthIssues: healthIssues,
      );
      await store.add(newProfile);
    } else {
      final updated = widget.profile!.copyWith(
        name: name,
        age: ageValue,
        photoPath: _photoPath,
        renalDisease: _renalDisease,
        hepaticDisease: _hepaticDisease,
        diabetes: _diabetes,
        hypertension: _hypertension,
        healthIssues: healthIssues,
      );
      await store.update(updated);
    }

    if (!mounted) {
      return;
    }
    Navigator.pop(context);
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

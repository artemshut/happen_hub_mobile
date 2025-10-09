import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';

import '../models/event.dart';
import '../models/event_category.dart';
import '../repositories/event_repository.dart';
import '../repositories/event_category_repository.dart';
import '../services/secrets.dart';
import 'event.dart'; // EventScreen

class EditEventScreen extends StatefulWidget {
  final Event event;
  final String currentUserId;

  const EditEventScreen({
    super.key,
    required this.event,
    required this.currentUserId,
  });

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = EventRepository();
  final EventCategoryRepository _categoryRepository =
      EventCategoryRepository();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;

  DateTime? _startTime;
  DateTime? _endTime;
  File? _newCoverImage;
  List<File> _newFiles = [];
  List<String> _removedFiles = []; // signed_ids

  String? _googleApiKey;
  bool _loadingKey = true;
  String? _selectedAddress;
  double? _lat;
  double? _lng;
  bool _isSaving = false;

  // 👁️ Visibility dropdown
  late String _visibility;
  List<EventCategory> _categories = [];
  bool _loadingCategories = true;
  String? _selectedCategoryId;
  String? _categoriesError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController =
        TextEditingController(text: widget.event.description);
    _locationController =
        TextEditingController(text: widget.event.location ?? '');
    _startTime = widget.event.startTime;
    _endTime = widget.event.endTime;
    _visibility = widget.event.visibility ?? 'public';
    _selectedCategoryId = widget.event.category?.id;
    _loadSecrets();
    _fetchCategories();
  }

  Future<void> _loadSecrets() async {
    final key = await SecretsService.getGoogleApiKey();
    setState(() {
      _googleApiKey = key;
      _loadingKey = false;
    });
  }

  Future<void> _fetchCategories() async {
    try {
      final fetched = await _categoryRepository.fetchCategories();
      if (!mounted) return;

      final categories = List<EventCategory>.from(fetched);
      final current = widget.event.category;
      if (current != null &&
          categories.every((cat) => cat.id != current.id)) {
        categories.add(current);
      }

      setState(() {
        _categories = categories;
        _loadingCategories = false;
        _categoriesError = null;
        _selectedCategoryId ??= current?.id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categoriesError = e.toString();
        _loadingCategories = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime ?? _startTime;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
    );
    if (pickedTime == null) return;

    final fullDate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isStart) {
        _startTime = fullDate;
      } else {
        _endTime = fullDate;
      }
    });
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _newCoverImage = File(picked.path);
      });
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        _newFiles.addAll(result.paths.map((p) => File(p!)).toList());
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final saved = await _repo.updateEvent(
        eventId: widget.event.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        startTime: _startTime ?? widget.event.startTime,
        endTime: _endTime,
        location: _selectedAddress ?? _locationController.text.trim(),
        latitude: _lat,
        longitude: _lng,
        visibility: _visibility,
        categoryId: _selectedCategoryId,
        coverImage: _newCoverImage,
        files: _newFiles.isNotEmpty ? _newFiles : null,
        removedFiles: _removedFiles,
      );

      saved.visibility = _visibility;

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EventScreen(
            event: saved,
            currentUserId: widget.currentUserId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ Failed to update: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loadingKey) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Event"),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? "Title is required" : null,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 👁️ Visibility dropdown
              DropdownButtonFormField<String>(
                value: _visibility,
                decoration: const InputDecoration(
                  labelText: "Visibility",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: "public", child: Text("Public")),
                  DropdownMenuItem(value: "friends", child: Text("Friends")),
                  DropdownMenuItem(value: "private", child: Text("Private")),
                ],
                onChanged: (v) => setState(() => _visibility = v!),
              ),
              const SizedBox(height: 16),

              if (_loadingCategories)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_categoriesError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    "Failed to load categories: $_categoriesError",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                )
              else if (_categories.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    "No categories available",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "Category",
                    border: OutlineInputBorder(),
                  ),
                  items: _categories
                      .map(
                        (cat) => DropdownMenuItem(
                          value: cat.id,
                          child: Text(
                            cat.emoji != null && cat.emoji!.isNotEmpty
                                ? "${cat.emoji} ${cat.name}"
                                : cat.name,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _categories.isEmpty
                      ? null
                      : (value) => setState(() => _selectedCategoryId = value),
                  hint: const Text("Select category"),
                ),
              const SizedBox(height: 16),

              // ✅ Location autocomplete
              GooglePlaceAutoCompleteTextField(
                textEditingController: _locationController,
                googleAPIKey: _googleApiKey!,
                inputDecoration: const InputDecoration(
                  labelText: "Location",
                  border: OutlineInputBorder(),
                ),
                debounceTime: 600,
                isLatLngRequired: true,
                getPlaceDetailWithLatLng: (Prediction prediction) {
                  setState(() {
                    _selectedAddress = prediction.description;
                    _lat = double.tryParse(prediction.lat ?? "");
                    _lng = double.tryParse(prediction.lng ?? "");
                  });
                },
                itemClick: (Prediction prediction) {
                  _locationController.text = prediction.description ?? "";
                  _locationController.selection = TextSelection.fromPosition(
                    TextPosition(offset: prediction.description?.length ?? 0),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Dates
              ListTile(
                title: Text(
                  "Start: ${DateFormat('dd/MM/yyyy HH:mm').format(_startTime ?? DateTime.now())}",
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDateTime(true),
              ),
              ListTile(
                title: Text(
                  "End: ${_endTime != null ? DateFormat('dd/MM/yyyy HH:mm').format(_endTime!) : 'Not set'}",
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDateTime(false),
              ),
              const SizedBox(height: 24),

              // Cover Image
              Text("Cover Image", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),

              if (_newCoverImage != null)
                Stack(
                  children: [
                    Image.file(_newCoverImage!, height: 150, fit: BoxFit.cover),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => _newCoverImage = null),
                      ),
                    ),
                  ],
                )
              else if (widget.event.coverImageUrl != null)
                Stack(
                  children: [
                    Image.network(widget.event.coverImageUrl!,
                        height: 150, fit: BoxFit.cover),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() {
                          _newCoverImage = null;
                        }),
                      ),
                    ),
                  ],
                )
              else
                const Text("No cover image"),
              TextButton.icon(
                onPressed: _pickCoverImage,
                icon: const Icon(Icons.image),
                label: const Text("Change Cover"),
              ),
              const SizedBox(height: 16),

              // Files
              Text("Files", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.event.files != null)
                    ...widget.event.files!
                        .where((f) => !_removedFiles.contains(f.signedId))
                        .map(
                          (f) => Chip(
                            label: Text(f.filename),
                            onDeleted: () => setState(() {
                              _removedFiles.add(f.signedId);
                            }),
                          ),
                        ),
                  ..._newFiles.map(
                    (f) => Chip(
                      label: Text(f.path.split("/").last),
                      onDeleted: () => setState(() {
                        _newFiles.remove(f);
                      }),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.attach_file),
                label: const Text("Add Files"),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.save),
                label: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Changes"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

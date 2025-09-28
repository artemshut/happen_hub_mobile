// lib/screens/create_event.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../repositories/event_repository.dart';
import '../models/event.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime? _startTime;
  DateTime? _endTime;
  File? _coverImage;
  List<File> _files = [];

  bool _loading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickCoverImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _coverImage = File(picked.path));
    }
  }

  Future<void> _pickFiles() async {
    final picked = await _picker.pickMultiImage(); // Images only
    if (picked.isNotEmpty) {
      setState(() {
        _files = picked.map((x) => File(x.path)).toList();
      });
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startTime = dt;
      } else {
        _endTime = dt;
      }
    });
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _startTime == null) return;

    setState(() => _loading = true);

    try {
      final repo = EventRepository();
      final newEvent = await repo.createEvent(
        title: _titleController.text,
        description: _descController.text,
        startTime: _startTime!,
        endTime: _endTime,
        location: _locationController.text,
        coverImage: _coverImage,
        files: _files,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Event created successfully")),
        );
        Navigator.pop(context, newEvent);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Create Event")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Location
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: "Location",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Start / End Time
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(true),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_startTime == null
                        ? "Start Time"
                        : _startTime.toString()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(false),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_endTime == null
                        ? "End Time"
                        : _endTime.toString()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cover image picker
            if (_coverImage != null)
              Column(
                children: [
                  Image.file(_coverImage!, height: 150, fit: BoxFit.cover),
                  const SizedBox(height: 8),
                ],
              ),
            ElevatedButton.icon(
              onPressed: _pickCoverImage,
              icon: const Icon(Icons.image),
              label: const Text("Pick Cover Image"),
            ),
            const SizedBox(height: 16),

            // Files picker
            if (_files.isNotEmpty)
              Column(
                children: _files
                    .map((f) => ListTile(
                          leading: const Icon(Icons.attach_file),
                          title: Text(f.path.split("/").last),
                        ))
                    .toList(),
              ),
            ElevatedButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.attach_file),
              label: const Text("Pick Files"),
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )
                    : const Text("Create Event"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
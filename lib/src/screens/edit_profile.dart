import 'package:flutter/material.dart';

class EditProfileScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: TextEditingController(text: userData['first_name']),
              decoration: const InputDecoration(labelText: "First Name"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: userData['last_name']),
              decoration: const InputDecoration(labelText: "Last Name"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: userData['username']),
              decoration: const InputDecoration(labelText: "Username"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: userData['email']),
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () {
                // 🔥 Later: send PUT /users/:id
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Profile update not yet implemented"),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
              icon: const Icon(Icons.save),
              label: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}
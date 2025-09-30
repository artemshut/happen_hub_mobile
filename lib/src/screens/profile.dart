import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/user.dart';
import 'login.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getCurrentUser();
    setState(() {
      _user = user;
    });
  }

  Future<void> _signOut(BuildContext context) async {
    await _authService.logout(); // ✅ clear "token" & "refresh_token"

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = _user!;

    return Scaffold(
      body: Column(
        children: [
          // 🔹 Gradient header
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: -50,
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? Text(
                              user.firstName?[0] ?? "U",
                              style: const TextStyle(fontSize: 28),
                            )
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () => _signOut(context),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 60),

          // 🔹 Username & tag
          Text(
            "@${user.username}",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          Text(
            user.tag ?? "",
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 12),

          // 🔹 Full name & email
          Text(
            "${user.firstName ?? ''} ${user.lastName ?? ''}".trim(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          if (user.email != null)
            Text(
              user.email!,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),

          const SizedBox(height: 24),

          // 🔹 Share profile button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ShareProfileScreen(user: user),
                ));
              },
              icon: const Icon(Icons.share),
              label: const Text("Share Profile"),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShareProfileScreen extends StatelessWidget {
  final User user;

  const ShareProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final profileUrl = "https://happenhub.co/u/${user.username}";

    return Scaffold(
      appBar: AppBar(title: const Text("Share Profile")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage:
                  user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null
                  ? Text(user.firstName?[0] ?? "U")
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              "@${user.username}",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            Text(
              "${user.firstName ?? ''} ${user.lastName ?? ''}".trim(),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            QrImageView(
              data: profileUrl,
              version: QrVersions.auto,
              size: 200.0,
            ),
            const SizedBox(height: 12),
            Text(
              profileUrl,
              style: TextStyle(
                color: cs.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
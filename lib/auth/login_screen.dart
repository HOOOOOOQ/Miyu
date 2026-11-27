import 'package:flutter/material.dart';
import 'package:miyu/auth/auth_service.dart';
import 'package:miyu/features/home/home_page.dart';
import 'package:miyu/theme/theme.dart';
import 'package:miyu/widgets/miyu_logo.dart';

/// Login using the original supported provider (YouTube Music).
/// No invented login providers — see AUDIT_REPORT.md.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _tokenController = TextEditingController();
  bool _loading = false;

  void _login() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token YouTube Music tidak boleh kosong')));
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.signInYt(token);
      if (mounted) {
        await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiyuColors.bgDark,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: MiyuColors.textDark),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MiyuLogo(size: 64),
              const SizedBox(height: 16),
              const Text('Sign in to Miyu',
                  style: TextStyle(fontFamily: 'Figtree', fontSize: 24, fontWeight: FontWeight.w600, color: MiyuColors.textDark)),
              const SizedBox(height: 20),
              TextField(
                controller: _tokenController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'YouTube Music Token',
                  prefixIcon: const Icon(Icons.key_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  suffixIcon: const Icon(Icons.manage_search_outlined),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MiyuColors.accentDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../services/sync_provider.dart';
import 'manager_screen.dart';
import 'customer_screen.dart';

class LoginScreen extends StatefulWidget {
  final SyncProvider syncProvider;
  final String role; // 'customer' or 'provider'

  const LoginScreen({super.key, required this.syncProvider, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool isSignUpMode = false;
  bool isLoading = false;

  void _submit() async {
    final username = _userController.text.trim();
    final password = _passController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => isLoading = true);

    final result = await widget.syncProvider.authenticate(username, password, widget.role, isSignUpMode);

    setState(() => isLoading = false);

    if (!mounted) return;

    if (result == "success") {
      if (isSignUpMode) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created successfully! You can now login.')));
        setState(() => isSignUpMode = false);
      } else {
        if (widget.role == 'provider') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ManagerScreen(syncProvider: widget.syncProvider)));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CustomerScreen(syncProvider: widget.syncProvider)));
        }
      }
    } else if (result == "exists") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username already exists for this role.')));
    } else if (result == "not_found") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not available. Please register first!')));
    } else if (result == "wrong_password") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect password. Please try again.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication failed. Check your connection.')));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.role.toUpperCase()} ${isSignUpMode ? "Sign Up" : "Login"}')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _userController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Username', labelStyle: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Password', labelStyle: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isSignUpMode ? 'Register Account' : 'Login', style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => isSignUpMode = !isSignUpMode),
              child: Text(isSignUpMode ? 'Already have an account? Login' : "Don't have an account? Sign Up", style: const TextStyle(color: DesignTokens.accent)),
            )
          ],
        ),
      ),
    );
  }
}
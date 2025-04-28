import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _appController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _secretController = TextEditingController();
  bool _isSaving = false;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  void _submitForm() {
    print('🟡 Form submit button pressed');

    if (_formKey.currentState!.validate()) {
      print('✅ Form validated successfully');

      final uid = FirebaseAuth.instance.currentUser?.uid;
      print('🔑 Current UID: $uid');

      if (uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to save accounts.')),
        );
        return;
      }

      setState(() => _isSaving = true);
      print('📤 Attempting to save account...');
      FirebaseFirestore.instance.collection('accounts').add({
        'uid': uid,
        'app': _appController.text,
        'email': _emailController.text,
        'createdAt': FieldValue.serverTimestamp(),
      }).then((value) async {
        print('✅ Account saved successfully');

        // Save the secret encrypted locally
        await _secureStorage.write(
          key: 'secret_${value.id}',
          value: _secretController.text,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account saved to Firestore.')),
        );
        _formKey.currentState!.reset();
        setState(() => _isSaving = false);
        Future.microtask(() {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/codes');
          }
        });
      }).catchError((error) {
        print('❌ Error saving account: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add account: $error')),
        );
        setState(() => _isSaving = false);
      });
    } else {
      print('❗ Form validation failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Account')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _appController,
                decoration: const InputDecoration(labelText: 'App Name'),
                validator: (value) => value!.isEmpty ? 'Enter app name' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) => value!.isEmpty ? 'Enter email' : null,
              ),
              TextFormField(
                controller: _secretController,
                decoration: const InputDecoration(labelText: 'Secret Key'),
                validator: (value) => value!.isEmpty ? 'Enter TOTP secret key' : null,
              ),
              const SizedBox(height: 20),
              _isSaving
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _submitForm,
                      child: const Text('Save Account'),
                    ),
              // QR code scanner button removed for now; can be added back if needed later.
            ],
          ),
        ),
      ),
    );
  }
}
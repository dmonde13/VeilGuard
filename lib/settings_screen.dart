import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'login_screen.dart';  // Import the LoginScreen


class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Delete Account Button
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text('Delete Account', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                final shouldDelete = await _showDeleteConfirmationDialog(context);
                if (shouldDelete) {
                  await _deleteAccount(context);
                }
              },
            ),
            const SizedBox(height: 12),
            const Spacer(),
            // Logout Button
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'VeilGuard v1.0.0',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Confirmation Dialog for Deleting Account
  Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context, false); // User pressed "No"
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true); // User pressed "Yes"
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    ) ??
        false; // Default to false if the dialog is dismissed
  }

  // Handle Account Deletion
  Future<void> _deleteAccount(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Re-authenticate if necessary (for providers like Google/Facebook)
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email ?? '',
          password: 'TestPassword123', // Use the current user's password here if needed
        );

        // Reauthenticate the user
        await user.reauthenticateWithCredential(credential);

        // Delete the user's document from Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();

        // Delete the account from Firebase Auth
        await user.delete();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account successfully deleted')),
        );

        // Delay the navigation to login screen to ensure Snackbar is visible
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),  // Ensure LoginScreen is imported
          );
        });
      }
    } catch (e) {
      // Handle errors (e.g., account deletion failed)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete account. Please try again.')),
      );
    }
  }
}
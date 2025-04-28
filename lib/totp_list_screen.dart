import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:totp/totp.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TOTPListScreen extends StatefulWidget {
  const TOTPListScreen({super.key});

  @override
  State<TOTPListScreen> createState() => _TOTPListScreenState();
}

class _TOTPListScreenState extends State<TOTPListScreen> {
  late Timer _timer;
  late final ValueNotifier<int> _secondsRemainingNotifier;

  @override
  void initState() {
    super.initState();
    _secondsRemainingNotifier = ValueNotifier<int>(_calculateSecondsRemaining());
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsRemainingNotifier.value = _calculateSecondsRemaining();
    });
  }

  int _calculateSecondsRemaining() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return 30 - (now % 30);
  }

  @override
  void dispose() {
    _timer.cancel();
    _secondsRemainingNotifier.dispose();
    super.dispose();
  }

  String _generateTOTP({required String secret}) {
    try {
      final totp = Totp(secret: secret.codeUnits, digits: 6);
      return totp.now();
    } catch (e) {
      return '⚠️ Invalid';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('accounts')
            .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No accounts found'));
          }

          final accounts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      accounts[index].reference.delete().catchError((error) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to delete entry. Please try again.')),
                          );
                        }
                      });
                    },
                  ),
                  title: Text(
                    account['app'] ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ValueListenableBuilder<int>(
                      valueListenable: _secondsRemainingNotifier,
                      builder: (context, secondsRemaining, _) {
                        final progress = (30 - secondsRemaining) / 30;
                        return LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade800,
                          color: Colors.greenAccent,
                          minHeight: 6,
                        );
                      },
                    ),
                  ),
                  trailing: ValueListenableBuilder<int>(
                    valueListenable: _secondsRemainingNotifier,
                    builder: (context, secondsRemaining, _) {
                      return Text(
                        _generateTOTP(secret: account['secret'] ?? ''),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      // FloatingActionButton removed as per instructions.
    );
  }
}
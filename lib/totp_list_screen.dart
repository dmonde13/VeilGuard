import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:totp/totp.dart';
import 'package:base32/base32.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class TOTPListScreen extends StatefulWidget {
  const TOTPListScreen({super.key});

  @override
  State<TOTPListScreen> createState() => _TOTPListScreenState();
}

class _TOTPListScreenState extends State<TOTPListScreen> {
  late Timer _timer;
  late final ValueNotifier<int> _secondsRemainingNotifier;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _secondsRemainingNotifier = ValueNotifier<int>(_calculateSecondsRemaining());
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsRemainingNotifier.value = _calculateSecondsRemaining();
    });
    _searchController.addListener(_onSearchChanged);
    // No need to add listener for search, handled by onChanged
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
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
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _generateTOTP({required String secret}) {
    try {
      final cleanedSecret = secret.replaceAll(' ', '').toUpperCase();
      print('Generating TOTP with secret: $cleanedSecret'); // Debug print
      final decodedSecret = base32.decode(cleanedSecret);
      final totp = Totp(secret: decodedSecret, digits: 6);
      return totp.now();
    } catch (e) {
      print('Error generating TOTP: $e'); // Debug print
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
          final filteredAccounts = accounts.where((doc) {
            final account = doc.data() as Map<String, dynamic>;
            final appName = (account['app'] ?? '').toString().toLowerCase();
            return appName.contains(_searchQuery.toLowerCase());
          }).toList();

          // Pluralization logic for Entry/Entries
          final int count = filteredAccounts.length;
          final String entryText = '$count ${count == 1 ? "Entry" : "Entries"}';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _searchQuery = value;
                    // If there was a _filterAccounts method, call it here.
                    // _filterAccounts();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    entryText,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredAccounts.length,
                  itemBuilder: (context, index) {
                    final account = filteredAccounts[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        leading: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () {
                            filteredAccounts[index].reference.delete().catchError((error) {
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
                            fontWeight: FontWeight.bold,
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
                            final code = _generateTOTP(secret: account['secret'] ?? '');
                            return InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Code copied to clipboard ✔')),
                                );
                              },
                              child: Text(
                                code,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      // FloatingActionButton removed as per instructions.
    );
  }
}
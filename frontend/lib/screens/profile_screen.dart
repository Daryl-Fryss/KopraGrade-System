import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/validators.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _contact;
  bool _busy = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _name = TextEditingController(text: user?.name ?? '');
    _contact = TextEditingController(text: user?.contact ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await ref.read(authProvider.notifier).updateProfile(name: _name.text, contact: _contact.text);
      if (mounted) setState(() => _message = 'Profile updated.');
    } catch (e) {
      if (mounted) setState(() => _error = ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (sure == true) await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    return ResponsiveBody(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(user.email),
                ),
                ListTile(
                  leading: Icon(user.isFarmer ? Icons.agriculture : Icons.storefront),
                  title: const Text('Account type'),
                  subtitle: Text(user.isFarmer ? 'Farmer' : 'Buyer'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 12)],
                if (_message != null) ...[
                  Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                  validator: validateName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contact,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Contact info (optional)', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: validateContact,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save changes'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(onPressed: _logout, icon: const Icon(Icons.logout), label: const Text('Log out')),
        ],
      ),
    );
  }
}

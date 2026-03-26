import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/team_repository.dart';

const _currencies = ['COP', 'USD', 'EUR', 'MXN', 'PEN', 'ARS', 'CLP', 'BRL'];

class TeamSettingsScreen extends ConsumerStatefulWidget {
  const TeamSettingsScreen({super.key});

  @override
  ConsumerState<TeamSettingsScreen> createState() => _TeamSettingsScreenState();
}

class _TeamSettingsScreenState extends ConsumerState<TeamSettingsScreen> {
  late TextEditingController _nameController;
  late String _selectedCurrency;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final team = ref.read(authProvider).activeTeam;
    _nameController = TextEditingController(text: team?.name ?? '');
    _selectedCurrency = team?.currency ?? 'COP';
    _nameController.addListener(_onChanged);
  }

  void _onChanged() {
    final team = ref.read(authProvider).activeTeam;
    final nameChanged = _nameController.text.trim() != (team?.name ?? '');
    final currencyChanged = _selectedCurrency != (team?.currency ?? 'COP');
    setState(() => _hasChanges = nameChanged || currencyChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final teamId = ref.read(authProvider).teamId;
    if (teamId.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final updated = await ref.read(teamRepositoryProvider).updateTeamSettings(
        teamId,
        {
          'name': name,
          'currency': _selectedCurrency,
        },
      );
      // Update auth state with new team data
      ref.read(authProvider.notifier).switchTeam(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada')),
        );
        setState(() {
          _hasChanges = false;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración del equipo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Team name
          Text(
            'Nombre del equipo',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              prefixIcon: Icon(Icons.store_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Currency
          Text(
            'Moneda',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _selectedCurrency,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.attach_money_rounded),
            ),
            items: _currencies
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedCurrency = value);
                _onChanged();
              }
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // Save button
          FilledButton.icon(
            onPressed: _hasChanges && !_isSaving ? _save : null,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Guardando...' : 'Guardar cambios'),
          ),
        ],
      ),
    );
  }
}

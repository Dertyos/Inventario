import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/permission_model.dart';
import '../../../../shared/providers/auth_provider.dart';

const _roleLabels = {
  'owner': 'Dueno',
  'admin': 'Administrador',
  'manager': 'Gerente',
  'staff': 'Personal',
};

class RolePermissionsScreen extends ConsumerStatefulWidget {
  final String role;

  const RolePermissionsScreen({super.key, required this.role});

  @override
  ConsumerState<RolePermissionsScreen> createState() =>
      _RolePermissionsScreenState();
}

class _RolePermissionsScreenState
    extends ConsumerState<RolePermissionsScreen> {
  List<String> _enabledPermissions = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPermissions();
  }

  Future<void> _fetchPermissions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final teamId = ref.read(authProvider).teamId;
      final dio = ref.read(dioProvider);
      final response =
          await dio.get('/teams/$teamId/permissions/${widget.role}');
      final data = response.data;
      final List<dynamic> perms =
          data is Map ? (data['permissions'] as List<dynamic>? ?? []) : (data as List<dynamic>? ?? []);
      _enabledPermissions = perms.cast<String>().toList();
    } on DioException catch (e) {
      _error = ApiException.fromDioError(e).toString();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final teamId = ref.read(authProvider).teamId;
      final dio = ref.read(dioProvider);
      await dio.patch(
        '/teams/$teamId/permissions/${widget.role}',
        data: {'permissions': _enabledPermissions},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permisos guardados')),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${ApiException.fromDioError(e)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  void _toggle(String key, bool value) {
    setState(() {
      if (value) {
        _enabledPermissions.add(key);
      } else {
        _enabledPermissions.remove(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final roleLabel = _roleLabels[widget.role] ?? widget.role;

    return Scaffold(
      appBar: AppBar(
        title: Text('Permisos: $roleLabel'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: colorScheme.error),
                        const SizedBox(height: AppSpacing.md),
                        Text('Error: $_error', textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton(
                          onPressed: _fetchPermissions,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final groups = allPermissionGroups(_enabledPermissions);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0) const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          group.icon,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          group.label.toUpperCase(),
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: colorScheme.primary,
                                    letterSpacing: 1.2,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < group.items.length; i++) ...[
                          SwitchListTile(
                            title: Text(group.items[i].label),
                            subtitle: group.items[i].description != null
                                ? Text(
                                    group.items[i].description!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  )
                                : null,
                            value: group.items[i].enabled,
                            onChanged: (val) =>
                                _toggle(group.items[i].key, val),
                          ),
                          if (i < group.items.length - 1)
                            Divider(
                              height: 1,
                              indent: AppSpacing.md,
                              endIndent: AppSpacing.md,
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SafeArea(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar cambios'),
            ),
          ),
        ),
      ],
    );
  }
}

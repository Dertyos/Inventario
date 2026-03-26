import 'package:flutter/material.dart';

class PermissionGroup {
  final String key;
  final String label;
  final IconData icon;
  final List<PermissionItem> items;

  const PermissionGroup({
    required this.key,
    required this.label,
    required this.icon,
    required this.items,
  });
}

class PermissionItem {
  final String key;
  final String label;
  final String? description;
  final bool enabled;

  const PermissionItem({
    required this.key,
    required this.label,
    this.description,
    required this.enabled,
  });

  PermissionItem copyWith({bool? enabled}) => PermissionItem(
        key: key,
        label: label,
        description: description,
        enabled: enabled ?? this.enabled,
      );
}

List<PermissionGroup> allPermissionGroups(List<String> enabledPermissions) {
  return [
    PermissionGroup(
      key: 'sales',
      label: 'Ventas',
      icon: Icons.sell_rounded,
      items: [
        PermissionItem(
          key: 'sales.create',
          label: 'Crear ventas',
          enabled: enabledPermissions.contains('sales.create'),
        ),
        PermissionItem(
          key: 'sales.edit',
          label: 'Editar ventas',
          description: 'Permite modificar notas, cliente y datos de crédito',
          enabled: enabledPermissions.contains('sales.edit'),
        ),
        PermissionItem(
          key: 'sales.delete',
          label: 'Eliminar ventas',
          description: 'Solo ventas canceladas pueden eliminarse',
          enabled: enabledPermissions.contains('sales.delete'),
        ),
        PermissionItem(
          key: 'sales.cancel',
          label: 'Cancelar ventas',
          enabled: enabledPermissions.contains('sales.cancel'),
        ),
        PermissionItem(
          key: 'sales.view_all',
          label: 'Ver todas las ventas',
          description: 'Si no, solo ve las propias',
          enabled: enabledPermissions.contains('sales.view_all'),
        ),
        PermissionItem(
          key: 'sales.override_price',
          label: 'Modificar precios en venta',
          description: 'Permite cambiar el precio de un producto solo para esa venta',
          enabled: enabledPermissions.contains('sales.override_price'),
        ),
      ],
    ),
    PermissionGroup(
      key: 'inventory',
      label: 'Inventario',
      icon: Icons.inventory_2_rounded,
      items: [
        PermissionItem(
          key: 'inventory.view',
          label: 'Ver productos',
          enabled: enabledPermissions.contains('inventory.view'),
        ),
        PermissionItem(
          key: 'inventory.create_product',
          label: 'Crear/editar productos',
          enabled: enabledPermissions.contains('inventory.create_product'),
        ),
        PermissionItem(
          key: 'inventory.delete_product',
          label: 'Eliminar productos',
          enabled: enabledPermissions.contains('inventory.delete_product'),
        ),
        PermissionItem(
          key: 'inventory.movements',
          label: 'Movimientos de stock',
          enabled: enabledPermissions.contains('inventory.movements'),
        ),
      ],
    ),
    PermissionGroup(
      key: 'customers',
      label: 'Clientes',
      icon: Icons.people_rounded,
      items: [
        PermissionItem(
          key: 'customers.create',
          label: 'Crear clientes',
          enabled: enabledPermissions.contains('customers.create'),
        ),
        PermissionItem(
          key: 'customers.edit',
          label: 'Editar clientes',
          enabled: enabledPermissions.contains('customers.edit'),
        ),
      ],
    ),
    PermissionGroup(
      key: 'reports',
      label: 'Reportes',
      icon: Icons.bar_chart_rounded,
      items: [
        PermissionItem(
          key: 'reports.view',
          label: 'Ver reportes',
          enabled: enabledPermissions.contains('reports.view'),
        ),
        PermissionItem(
          key: 'reports.export',
          label: 'Exportar datos',
          enabled: enabledPermissions.contains('reports.export'),
        ),
      ],
    ),
    PermissionGroup(
      key: 'admin',
      label: 'Administracion',
      icon: Icons.admin_panel_settings_rounded,
      items: [
        PermissionItem(
          key: 'admin.team_settings',
          label: 'Configuracion del equipo',
          enabled: enabledPermissions.contains('admin.team_settings'),
        ),
        PermissionItem(
          key: 'admin.members',
          label: 'Gestionar miembros',
          enabled: enabledPermissions.contains('admin.members'),
        ),
        PermissionItem(
          key: 'admin.audit',
          label: 'Ver auditoria',
          enabled: enabledPermissions.contains('admin.audit'),
        ),
        PermissionItem(
          key: 'admin.ai',
          label: 'Asistente IA',
          enabled: enabledPermissions.contains('admin.ai'),
        ),
      ],
    ),
  ];
}

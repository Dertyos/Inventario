export enum Permission {
  // VENTAS
  SALES_CREATE = 'sales.create',
  SALES_CANCEL = 'sales.cancel',
  SALES_VIEW_ALL = 'sales.view_all',

  // INVENTARIO
  INVENTORY_VIEW = 'inventory.view',
  INVENTORY_CREATE_PRODUCT = 'inventory.create_product',
  INVENTORY_DELETE_PRODUCT = 'inventory.delete_product',
  INVENTORY_MOVEMENTS = 'inventory.movements',

  // CLIENTES
  CUSTOMERS_CREATE = 'customers.create',
  CUSTOMERS_EDIT = 'customers.edit',

  // REPORTES
  REPORTS_VIEW = 'reports.view',
  REPORTS_EXPORT = 'reports.export',

  // ADMINISTRACION
  ADMIN_TEAM_SETTINGS = 'admin.team_settings',
  ADMIN_MEMBERS = 'admin.members',
  ADMIN_AUDIT = 'admin.audit',
  ADMIN_AI = 'admin.ai',
}

export const ALL_PERMISSIONS = Object.values(Permission);

export const DEFAULT_PERMISSIONS: Record<string, string[]> = {
  owner: ['*'],
  admin: ['*'],
  manager: [
    Permission.SALES_CREATE,
    Permission.SALES_CANCEL,
    Permission.SALES_VIEW_ALL,
    Permission.INVENTORY_VIEW,
    Permission.INVENTORY_CREATE_PRODUCT,
    Permission.INVENTORY_MOVEMENTS,
    Permission.CUSTOMERS_CREATE,
    Permission.CUSTOMERS_EDIT,
    Permission.REPORTS_VIEW,
    Permission.REPORTS_EXPORT,
    Permission.ADMIN_AI,
  ],
  staff: [
    Permission.SALES_CREATE,
    Permission.INVENTORY_VIEW,
    Permission.CUSTOMERS_CREATE,
    Permission.ADMIN_AI,
  ],
};

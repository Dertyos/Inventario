import { IsBoolean, IsNumber, IsOptional, Min, Max } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateSettingsDto {
  @ApiPropertyOptional({
    example: true,
    description: 'Habilitar manejo de lotes',
  })
  @IsBoolean()
  @IsOptional()
  enableLots?: boolean;

  @ApiPropertyOptional({ example: true, description: 'Habilitar créditos' })
  @IsBoolean()
  @IsOptional()
  enableCredit?: boolean;

  @ApiPropertyOptional({ example: true, description: 'Habilitar proveedores' })
  @IsBoolean()
  @IsOptional()
  enableSuppliers?: boolean;

  @ApiPropertyOptional({
    example: true,
    description: 'Habilitar recordatorios de pago',
  })
  @IsBoolean()
  @IsOptional()
  enableReminders?: boolean;

  @ApiPropertyOptional({ example: false, description: 'Habilitar impuestos' })
  @IsBoolean()
  @IsOptional()
  enableTax?: boolean;

  @ApiPropertyOptional({
    example: true,
    description: 'Habilitar código de barras',
  })
  @IsBoolean()
  @IsOptional()
  enableBarcode?: boolean;

  @ApiPropertyOptional({
    example: 19,
    description: 'Tasa de impuesto por defecto (%)',
    minimum: 0,
    maximum: 100,
  })
  @IsNumber()
  @Min(0)
  @Max(100)
  @IsOptional()
  defaultTaxRate?: number;
}

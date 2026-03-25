import { IsBoolean, IsNumber, IsOptional, Min, Max } from 'class-validator';

export class UpdateSettingsDto {
  @IsBoolean()
  @IsOptional()
  enableLots?: boolean;

  @IsBoolean()
  @IsOptional()
  enableCredit?: boolean;

  @IsBoolean()
  @IsOptional()
  enableSuppliers?: boolean;

  @IsBoolean()
  @IsOptional()
  enableReminders?: boolean;

  @IsBoolean()
  @IsOptional()
  enableTax?: boolean;

  @IsBoolean()
  @IsOptional()
  enableBarcode?: boolean;

  @IsNumber()
  @Min(0)
  @Max(100)
  @IsOptional()
  defaultTaxRate?: number;
}

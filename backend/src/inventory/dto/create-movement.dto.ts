import {
  IsEnum,
  IsInt,
  IsNumber,
  IsString,
  IsOptional,
  IsUUID,
  IsBoolean,
  Min,
  Max,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MovementType } from '../entities/inventory-movement.entity';

export class CreateMovementDto {
  @ApiProperty({
    enum: MovementType,
    example: 'in',
    description: 'Tipo de movimiento (entrada/salida/ajuste)',
  })
  @IsEnum(MovementType)
  type: MovementType;

  @ApiProperty({ example: 24, description: 'Cantidad de unidades', minimum: 1 })
  @IsInt()
  @Min(1)
  quantity: number;

  @ApiPropertyOptional({
    example: 2000,
    description: 'Costo unitario de compra (COP)',
  })
  @IsNumber()
  @Min(0)
  @IsOptional()
  unitCost?: number;

  @ApiPropertyOptional({
    example: 'Reposición semanal',
    description: 'Razón del movimiento',
  })
  @IsString()
  @IsOptional()
  reason?: string;

  @ApiProperty({
    example: '550e8400-e29b-41d4-a716-446655440000',
    description: 'UUID del producto',
  })
  @IsUUID()
  productId: string;

  @ApiPropertyOptional({
    example: '550e8400-e29b-41d4-a716-446655440000',
    description: 'UUID del proveedor (para entradas)',
  })
  @IsUUID()
  @IsOptional()
  supplierId?: string;

  @ApiPropertyOptional({
    example: '550e8400-e29b-41d4-a716-446655440000',
    description: 'UUID del lote (obligatorio si producto tiene trackLots y enableLots activo)',
  })
  @IsUUID()
  @IsOptional()
  lotId?: string;

  @ApiPropertyOptional({ description: 'Compra a crédito' })
  @IsBoolean()
  @IsOptional()
  isCredit?: boolean;

  @ApiPropertyOptional({ description: 'Número de cuotas (1-60)' })
  @IsInt()
  @Min(1)
  @Max(60)
  @IsOptional()
  creditInstallments?: number;

  @ApiPropertyOptional({ description: 'Frecuencia de pago: daily/weekly/monthly' })
  @IsString()
  @IsOptional()
  creditFrequency?: string;
}

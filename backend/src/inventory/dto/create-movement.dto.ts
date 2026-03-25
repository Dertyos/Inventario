import {
  IsEnum,
  IsInt,
  IsString,
  IsOptional,
  IsUUID,
  Min,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MovementType } from '../entities/inventory-movement.entity';

export class CreateMovementDto {
  @ApiProperty({ enum: MovementType, example: 'in', description: 'Tipo de movimiento (entrada/salida/ajuste)' })
  @IsEnum(MovementType)
  type: MovementType;

  @ApiProperty({ example: 24, description: 'Cantidad de unidades', minimum: 1 })
  @IsInt()
  @Min(1)
  quantity: number;

  @ApiPropertyOptional({ example: 'Reposición semanal', description: 'Razón del movimiento' })
  @IsString()
  @IsOptional()
  reason?: string;

  @ApiProperty({ example: '550e8400-e29b-41d4-a716-446655440000', description: 'UUID del producto' })
  @IsUUID()
  productId: string;
}

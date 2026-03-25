import {
  IsString,
  IsInt,
  IsDateString,
  IsOptional,
  IsUUID,
  Min,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateLotDto {
  @ApiProperty({ example: '550e8400-e29b-41d4-a716-446655440000', description: 'UUID del producto' })
  @IsUUID()
  productId: string;

  @ApiProperty({ example: 'LOTE-2026-03-001', description: 'Número de lote' })
  @IsString()
  lotNumber: string;

  @ApiProperty({ example: 48, description: 'Cantidad de unidades en el lote', minimum: 1 })
  @IsInt()
  @Min(1)
  quantity: number;

  @ApiPropertyOptional({ example: '2026-12-31', description: 'Fecha de vencimiento (ISO 8601)' })
  @IsDateString()
  @IsOptional()
  expirationDate?: string;

  @ApiPropertyOptional({ example: '2026-01-15', description: 'Fecha de fabricación (ISO 8601)' })
  @IsDateString()
  @IsOptional()
  manufacturingDate?: string;

  @ApiPropertyOptional({ example: 'Lote recibido en buen estado', description: 'Notas sobre el lote' })
  @IsString()
  @IsOptional()
  notes?: string;
}

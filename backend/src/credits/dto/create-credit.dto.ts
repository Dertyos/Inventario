import {
  IsUUID,
  IsEnum,
  IsNumber,
  IsInt,
  IsDateString,
  IsOptional,
  Min,
  Max,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { InterestType } from '../entities/credit-account.entity';

export class CreateCreditDto {
  @ApiProperty({
    example: '550e8400-e29b-41d4-a716-446655440000',
    description: 'UUID de la venta asociada',
  })
  @IsUUID()
  saleId: string;

  @ApiPropertyOptional({
    example: '550e8400-e29b-41d4-a716-446655440001',
    description: 'UUID del cliente (opcional para ventas directas)',
  })
  @IsUUID()
  @IsOptional()
  customerId?: string;

  @ApiProperty({
    example: 150000,
    description: 'Monto total del crédito',
    minimum: 0,
  })
  @IsNumber()
  @Min(0)
  totalAmount: number;

  @ApiPropertyOptional({
    example: 5,
    description: 'Tasa de interés (%)',
    minimum: 0,
    maximum: 100,
  })
  @IsNumber()
  @Min(0)
  @Max(100)
  @IsOptional()
  interestRate?: number;

  @ApiPropertyOptional({
    enum: InterestType,
    example: 'simple',
    description: 'Tipo de interés (simple/compuesto)',
  })
  @IsEnum(InterestType)
  @IsOptional()
  interestType?: InterestType;

  @ApiProperty({
    example: 4,
    description: 'Número de cuotas (1-60)',
    minimum: 1,
    maximum: 60,
  })
  @IsInt()
  @Min(1)
  @Max(60)
  installments: number;

  @ApiPropertyOptional({
    example: '2026-04-01',
    description: 'Fecha de inicio del crédito (ISO 8601)',
  })
  @IsDateString()
  @IsOptional()
  startDate?: string;
}

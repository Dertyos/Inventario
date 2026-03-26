import {
  IsUUID,
  IsEnum,
  IsOptional,
  IsString,
  IsInt,
  IsNumber,
  Min,
} from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { PaymentMethod } from '../entities/sale.entity';

export class UpdateSaleDto {
  @ApiPropertyOptional({
    example: '550e8400-e29b-41d4-a716-446655440000',
    description: 'UUID del cliente',
  })
  @IsUUID()
  @IsOptional()
  customerId?: string;

  @ApiPropertyOptional({
    enum: PaymentMethod,
    example: 'cash',
    description: 'Método de pago',
  })
  @IsEnum(PaymentMethod)
  @IsOptional()
  paymentMethod?: PaymentMethod;

  @ApiPropertyOptional({
    example: 3,
    description: 'Número de cuotas (solo para crédito)',
  })
  @IsInt()
  @Min(1)
  @IsOptional()
  creditInstallments?: number;

  @ApiPropertyOptional({
    example: 10000,
    description: 'Monto abonado al momento (solo para crédito)',
  })
  @IsNumber()
  @Min(0)
  @IsOptional()
  creditPaidAmount?: number;

  @ApiPropertyOptional({
    example: 5.0,
    description: 'Porcentaje de interés (solo para crédito)',
  })
  @IsNumber()
  @Min(0)
  @IsOptional()
  creditInterestRate?: number;

  @ApiPropertyOptional({
    example: 'monthly',
    description: 'Frecuencia de cuotas: monthly, weekly, daily',
  })
  @IsString()
  @IsOptional()
  creditFrequency?: string;

  @ApiPropertyOptional({
    example: '2026-04-25',
    description: 'Fecha de la próxima cuota (ISO date)',
  })
  @IsString()
  @IsOptional()
  creditNextPayment?: string;

  @ApiPropertyOptional({
    example: 'Venta de mostrador',
    description: 'Notas de la venta',
  })
  @IsString()
  @IsOptional()
  notes?: string;
}

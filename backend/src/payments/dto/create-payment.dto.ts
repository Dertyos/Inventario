import {
  IsUUID,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { PaymentMethodType } from '../entities/payment.entity';

export class CreatePaymentDto {
  @ApiPropertyOptional({
    example: '550e8400-e29b-41d4-a716-446655440000',
    description: 'UUID de la venta asociada',
  })
  @IsUUID()
  @IsOptional()
  saleId?: string;

  @ApiProperty({ example: 15000, description: 'Monto del pago', minimum: 0.01 })
  @IsNumber()
  @Min(0.01)
  amount: number;

  @ApiPropertyOptional({
    enum: PaymentMethodType,
    example: 'cash',
    description: 'Método de pago',
  })
  @IsEnum(PaymentMethodType)
  @IsOptional()
  method?: PaymentMethodType;

  @ApiPropertyOptional({
    example: 'TRX-2024-001',
    description: 'Referencia de la transacción',
  })
  @IsString()
  @IsOptional()
  reference?: string;

  @ApiPropertyOptional({
    example: 'Pago parcial en efectivo',
    description: 'Notas del pago',
  })
  @IsString()
  @IsOptional()
  notes?: string;

  @ApiPropertyOptional({
    example: '550e8400-e29b-41d4-a716-446655440000',
    description: 'UUID de la cuenta de crédito asociada',
  })
  @IsUUID()
  @IsOptional()
  creditAccountId?: string;

  @ApiPropertyOptional({
    example: '550e8400-e29b-41d4-a716-446655440000',
    description: 'UUID de la cuota asociada',
  })
  @IsUUID()
  @IsOptional()
  installmentId?: string;
}

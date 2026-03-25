import {
  IsUUID,
  IsEnum,
  IsOptional,
  IsString,
  IsArray,
  ValidateNested,
  IsInt,
  IsNumber,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { PaymentMethod } from '../entities/sale.entity';

export class CreateSaleItemDto {
  @ApiProperty({
    example: '550e8400-e29b-41d4-a716-446655440000',
    description: 'UUID del producto',
  })
  @IsUUID()
  productId: string;

  @ApiProperty({ example: 3, description: 'Cantidad de unidades', minimum: 1 })
  @IsInt()
  @Min(1)
  quantity: number;

  @ApiProperty({
    example: 2500,
    description: 'Precio unitario de venta',
    minimum: 0,
  })
  @IsNumber()
  @Min(0)
  unitPrice: number;
}

export class CreateSaleDto {
  @ApiPropertyOptional({
    example: '550e8400-e29b-41d4-a716-446655440000',
    description: 'UUID del cliente (opcional para ventas sin cliente)',
  })
  @IsUUID()
  @IsOptional()
  customerId?: string;

  @ApiProperty({
    type: [CreateSaleItemDto],
    description: 'Artículos de la venta',
  })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateSaleItemDto)
  items: CreateSaleItemDto[];

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
    example: 'Venta de mostrador',
    description: 'Notas de la venta',
  })
  @IsString()
  @IsOptional()
  notes?: string;
}

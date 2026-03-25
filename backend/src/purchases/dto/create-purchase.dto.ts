import {
  IsUUID,
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

export class CreatePurchaseItemDto {
  @ApiProperty({ example: '550e8400-e29b-41d4-a716-446655440000', description: 'UUID del producto' })
  @IsUUID()
  productId: string;

  @ApiProperty({ example: 24, description: 'Cantidad de unidades', minimum: 1 })
  @IsInt()
  @Min(1)
  quantity: number;

  @ApiProperty({ example: 1800, description: 'Costo unitario', minimum: 0 })
  @IsNumber()
  @Min(0)
  unitCost: number;
}

export class CreatePurchaseDto {
  @ApiProperty({ example: '550e8400-e29b-41d4-a716-446655440000', description: 'UUID del proveedor' })
  @IsUUID()
  supplierId: string;

  @ApiProperty({ type: [CreatePurchaseItemDto], description: 'Artículos de la compra' })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreatePurchaseItemDto)
  items: CreatePurchaseItemDto[];

  @ApiPropertyOptional({ example: 'Pedido semanal de gaseosas', description: 'Notas de la compra' })
  @IsString()
  @IsOptional()
  notes?: string;
}

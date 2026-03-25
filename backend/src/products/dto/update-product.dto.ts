import {
  IsString,
  IsNumber,
  IsOptional,
  IsUUID,
  IsBoolean,
  Min,
} from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateProductDto {
  @ApiPropertyOptional({ example: 'Coca-Cola 350ml', description: 'Nombre del producto' })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiPropertyOptional({ example: '7702004003287', description: 'Código de barras' })
  @IsString()
  @IsOptional()
  barcode?: string;

  @ApiPropertyOptional({ example: 'Gaseosa Coca-Cola botella 350ml', description: 'Descripción del producto' })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiPropertyOptional({ example: 'https://ejemplo.co/imagen.jpg', description: 'URL de la imagen' })
  @IsString()
  @IsOptional()
  imageUrl?: string;

  @ApiPropertyOptional({ example: 2500, description: 'Precio de venta', minimum: 0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  price?: number;

  @ApiPropertyOptional({ example: 1800, description: 'Costo del producto', minimum: 0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  cost?: number;

  @ApiPropertyOptional({ example: 10, description: 'Stock mínimo para alertas', minimum: 0 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  minStock?: number;

  @ApiPropertyOptional({ example: false, description: 'Rastrear lotes para este producto' })
  @IsBoolean()
  @IsOptional()
  trackLots?: boolean;

  @ApiPropertyOptional({ example: '550e8400-e29b-41d4-a716-446655440000', description: 'UUID de la categoría' })
  @IsUUID()
  @IsOptional()
  categoryId?: string;

  @ApiPropertyOptional({ example: true, description: 'Estado activo del producto' })
  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}

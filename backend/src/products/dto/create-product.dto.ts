import { IsString, IsNumber, IsOptional, IsUUID, Min } from 'class-validator';

export class CreateProductDto {
  @IsString()
  sku: string;

  @IsString()
  name: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsNumber()
  @Min(0)
  price: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  cost?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  minStock?: number;

  @IsUUID()
  categoryId: string;
}

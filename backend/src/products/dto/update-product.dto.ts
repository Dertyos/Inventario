import {
  IsString,
  IsNumber,
  IsOptional,
  IsUUID,
  IsBoolean,
  Min,
} from 'class-validator';

export class UpdateProductDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsNumber()
  @Min(0)
  @IsOptional()
  price?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  cost?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  minStock?: number;

  @IsUUID()
  @IsOptional()
  categoryId?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}

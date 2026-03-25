import { IsString, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateCategoryDto {
  @ApiProperty({ example: 'Bebidas', description: 'Nombre de la categoría' })
  @IsString()
  name: string;

  @ApiPropertyOptional({ example: 'Gaseosas, jugos y agua', description: 'Descripción de la categoría' })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiPropertyOptional({ example: '#FF5733', description: 'Color para identificar la categoría' })
  @IsString()
  @IsOptional()
  color?: string;
}

import { IsString, IsOptional, MinLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateTeamDto {
  @ApiProperty({ example: 'Tienda Don José', description: 'Nombre del equipo', minLength: 2 })
  @IsString()
  @MinLength(2)
  name: string;

  @ApiPropertyOptional({ example: 'COP', description: 'Moneda del equipo' })
  @IsString()
  @IsOptional()
  currency?: string;

  @ApiPropertyOptional({ example: 'America/Bogota', description: 'Zona horaria' })
  @IsString()
  @IsOptional()
  timezone?: string;
}

import { IsString, IsNotEmpty, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class AppleAuthDto {
  @ApiProperty({
    description: 'Apple identity token (JWT) obtenido del cliente',
  })
  @IsString()
  @IsNotEmpty()
  identityToken: string;

  @ApiPropertyOptional({
    description: 'Nombre del usuario (solo disponible en el primer inicio de sesión)',
  })
  @IsString()
  @IsOptional()
  firstName?: string;

  @ApiPropertyOptional({
    description: 'Apellido del usuario (solo disponible en el primer inicio de sesión)',
  })
  @IsString()
  @IsOptional()
  lastName?: string;
}

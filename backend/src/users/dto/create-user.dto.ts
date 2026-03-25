import { IsEmail, IsString, MinLength, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateUserDto {
  @ApiProperty({ example: 'juan@mitienda.co', description: 'Correo electrónico' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'Clave$egura1', description: 'Contraseña (mínimo 8 caracteres)', minLength: 8 })
  @IsString()
  @MinLength(8)
  password: string;

  @ApiProperty({ example: 'Juan', description: 'Nombre' })
  @IsString()
  firstName: string;

  @ApiProperty({ example: 'Pérez', description: 'Apellido' })
  @IsString()
  lastName: string;

  @ApiPropertyOptional({ example: '3101234567', description: 'Teléfono' })
  @IsString()
  @IsOptional()
  phone?: string;
}

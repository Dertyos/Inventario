import { IsEmail, IsString } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class LoginDto {
  @ApiProperty({
    example: 'juan@mitienda.co',
    description: 'Correo electrónico',
  })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'Clave$egura1', description: 'Contraseña' })
  @IsString()
  password: string;
}

import { IsEmail, IsString, Length } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class VerifyEmailDto {
  @ApiProperty({
    example: 'juan@mitienda.co',
    description: 'Correo electrónico a verificar',
  })
  @IsEmail()
  email: string;

  @ApiProperty({
    example: '123456',
    description: 'Código de verificación de 6 dígitos',
  })
  @IsString()
  @Length(6, 6)
  code: string;
}

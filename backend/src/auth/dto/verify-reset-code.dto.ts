import { IsEmail, IsString, Length } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class VerifyResetCodeDto {
  @ApiProperty({
    example: 'juan@mitienda.co',
    description: 'Correo electrónico de la cuenta',
  })
  @IsEmail()
  email: string;

  @ApiProperty({
    example: '123456',
    description: 'Código de restablecimiento de 6 dígitos',
  })
  @IsString()
  @Length(6, 6)
  code: string;
}

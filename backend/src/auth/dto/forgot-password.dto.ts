import { IsEmail } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class ForgotPasswordDto {
  @ApiProperty({
    example: 'juan@mitienda.co',
    description: 'Correo electrónico de la cuenta',
  })
  @IsEmail()
  email: string;
}

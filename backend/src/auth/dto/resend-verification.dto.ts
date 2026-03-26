import { IsEmail } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class ResendVerificationDto {
  @ApiProperty({
    example: 'juan@mitienda.co',
    description: 'Correo electrónico al que reenviar el código',
  })
  @IsEmail()
  email: string;
}

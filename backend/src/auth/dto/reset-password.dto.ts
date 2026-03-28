import { IsString, MinLength, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class ResetPasswordDto {
  @ApiProperty({
    description: 'Token de restablecimiento obtenido al verificar el código',
  })
  @IsString()
  resetToken: string;

  @ApiProperty({
    example: 'NuevaClave$egura1',
    description:
      'Nueva contraseña (mínimo 8 caracteres, mayúscula, minúscula y número)',
    minLength: 8,
  })
  @IsString()
  @MinLength(8, { message: 'La contraseña debe tener al menos 8 caracteres' })
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$/, {
    message:
      'La contraseña debe incluir al menos una mayúscula, una minúscula y un número',
  })
  newPassword: string;
}

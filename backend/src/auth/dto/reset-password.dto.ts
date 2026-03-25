import { IsString, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class ResetPasswordDto {
  @ApiProperty({
    description: 'Token de restablecimiento obtenido al verificar el código',
  })
  @IsString()
  resetToken: string;

  @ApiProperty({
    example: 'NuevaClave$egura1',
    description: 'Nueva contraseña (mínimo 8 caracteres)',
    minLength: 8,
  })
  @IsString()
  @MinLength(8)
  newPassword: string;
}

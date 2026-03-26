import { IsString, IsNotEmpty } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class GoogleAuthDto {
  @ApiProperty({
    description: 'Google ID token obtenido del cliente',
  })
  @IsString()
  @IsNotEmpty()
  idToken: string;
}

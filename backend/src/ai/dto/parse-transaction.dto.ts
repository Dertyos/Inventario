import { IsNotEmpty, IsString, MaxLength, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class ParseTransactionDto {
  @ApiProperty({
    example: 'Venta de 5 tornillos a Pedro por 25 mil',
    description:
      'Natural language text describing a sale or purchase transaction',
    maxLength: 500,
  })
  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  @MaxLength(500)
  text: string;
}

import { IsNotEmpty, IsString } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class ParseTransactionDto {
  @ApiProperty({ example: 'Venta de 5 tornillos a Pedro por 25 mil' })
  @IsString()
  @IsNotEmpty()
  text: string;
}

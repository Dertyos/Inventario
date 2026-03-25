import { IsNumber, IsString, IsOptional, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class PayInstallmentDto {
  @ApiProperty({ example: 37500, description: 'Monto a pagar', minimum: 0.01 })
  @IsNumber()
  @Min(0.01)
  amount: number;

  @ApiPropertyOptional({ example: 'NEQUI-20260325', description: 'Referencia de la transacción' })
  @IsString()
  @IsOptional()
  reference?: string;

  @ApiPropertyOptional({ example: 'Cuota pagada por Nequi', description: 'Notas del pago' })
  @IsString()
  @IsOptional()
  notes?: string;
}

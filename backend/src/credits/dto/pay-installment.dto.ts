import { IsNumber, IsString, IsOptional, Min } from 'class-validator';

export class PayInstallmentDto {
  @IsNumber()
  @Min(0.01)
  amount: number;

  @IsString()
  @IsOptional()
  reference?: string;

  @IsString()
  @IsOptional()
  notes?: string;
}

import {
  IsString,
  IsInt,
  IsDateString,
  IsOptional,
  IsUUID,
  Min,
} from 'class-validator';

export class CreateLotDto {
  @IsUUID()
  productId: string;

  @IsString()
  lotNumber: string;

  @IsInt()
  @Min(1)
  quantity: number;

  @IsDateString()
  @IsOptional()
  expirationDate?: string;

  @IsDateString()
  @IsOptional()
  manufacturingDate?: string;

  @IsString()
  @IsOptional()
  notes?: string;
}

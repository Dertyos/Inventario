import {
  IsUUID,
  IsEnum,
  IsNumber,
  IsInt,
  IsDateString,
  IsOptional,
  Min,
  Max,
} from 'class-validator';
import { InterestType } from '../entities/credit-account.entity';

export class CreateCreditDto {
  @IsUUID()
  saleId: string;

  @IsUUID()
  customerId: string;

  @IsNumber()
  @Min(0)
  totalAmount: number;

  @IsNumber()
  @Min(0)
  @Max(100)
  @IsOptional()
  interestRate?: number;

  @IsEnum(InterestType)
  @IsOptional()
  interestType?: InterestType;

  @IsInt()
  @Min(1)
  @Max(60)
  installments: number;

  @IsDateString()
  @IsOptional()
  startDate?: string;
}

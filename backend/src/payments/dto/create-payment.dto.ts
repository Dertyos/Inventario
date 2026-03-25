import {
  IsUUID,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';
import { PaymentMethodType } from '../entities/payment.entity';

export class CreatePaymentDto {
  @IsUUID()
  @IsOptional()
  saleId?: string;

  @IsNumber()
  @Min(0.01)
  amount: number;

  @IsEnum(PaymentMethodType)
  @IsOptional()
  method?: PaymentMethodType;

  @IsString()
  @IsOptional()
  reference?: string;

  @IsString()
  @IsOptional()
  notes?: string;
}

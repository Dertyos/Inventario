import {
  IsEnum,
  IsInt,
  IsString,
  IsOptional,
  IsUUID,
  Min,
} from 'class-validator';
import { MovementType } from '../entities/inventory-movement.entity';

export class CreateMovementDto {
  @IsEnum(MovementType)
  type: MovementType;

  @IsInt()
  @Min(1)
  quantity: number;

  @IsString()
  @IsOptional()
  reason?: string;

  @IsUUID()
  productId: string;
}

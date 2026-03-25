import { IsString, IsEmail, IsEnum, IsOptional } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { DocumentType } from '../entities/customer.entity';

export class UpdateCustomerDto {
  @ApiPropertyOptional({
    example: 'María González',
    description: 'Nombre del cliente',
  })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiPropertyOptional({
    example: 'maria@correo.co',
    description: 'Correo electrónico del cliente',
  })
  @IsEmail()
  @IsOptional()
  email?: string;

  @ApiPropertyOptional({
    example: '3209876543',
    description: 'Teléfono del cliente',
  })
  @IsString()
  @IsOptional()
  phone?: string;

  @ApiPropertyOptional({
    enum: DocumentType,
    example: 'CC',
    description: 'Tipo de documento',
  })
  @IsEnum(DocumentType)
  @IsOptional()
  documentType?: DocumentType;

  @ApiPropertyOptional({
    example: '1023456789',
    description: 'Número de documento',
  })
  @IsString()
  @IsOptional()
  documentNumber?: string;

  @ApiPropertyOptional({
    example: 'Calle 45 #12-30, Bogotá',
    description: 'Dirección del cliente',
  })
  @IsString()
  @IsOptional()
  address?: string;

  @ApiPropertyOptional({
    example: 'Cliente frecuente',
    description: 'Notas adicionales',
  })
  @IsString()
  @IsOptional()
  notes?: string;
}

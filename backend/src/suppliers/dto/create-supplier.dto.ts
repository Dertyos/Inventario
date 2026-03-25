import { IsString, IsEmail, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateSupplierDto {
  @ApiProperty({ example: 'Distribuidora El Éxito', description: 'Nombre del proveedor' })
  @IsString()
  name: string;

  @ApiPropertyOptional({ example: '900123456-7', description: 'NIT del proveedor' })
  @IsString()
  @IsOptional()
  nit?: string;

  @ApiPropertyOptional({ example: 'Carlos Ramírez', description: 'Nombre del contacto' })
  @IsString()
  @IsOptional()
  contactName?: string;

  @ApiPropertyOptional({ example: 'ventas@distribuidora.co', description: 'Correo electrónico del proveedor' })
  @IsEmail()
  @IsOptional()
  email?: string;

  @ApiPropertyOptional({ example: '3115551234', description: 'Teléfono del proveedor' })
  @IsString()
  @IsOptional()
  phone?: string;

  @ApiPropertyOptional({ example: 'Carrera 7 #80-12, Bogotá', description: 'Dirección del proveedor' })
  @IsString()
  @IsOptional()
  address?: string;

  @ApiPropertyOptional({ example: 'Entrega los martes y jueves', description: 'Notas adicionales' })
  @IsString()
  @IsOptional()
  notes?: string;
}

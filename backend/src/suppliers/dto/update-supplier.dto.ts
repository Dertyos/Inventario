import { IsString, IsEmail, IsBoolean, IsOptional } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateSupplierDto {
  @ApiPropertyOptional({ example: 'Distribuidora El Éxito', description: 'Nombre del proveedor' })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiPropertyOptional({ example: '900123456-7', description: 'NIT del proveedor' })
  @IsString()
  @IsOptional()
  nit?: string;

  @ApiPropertyOptional({ example: 'Carlos Ramírez', description: 'Nombre del contacto' })
  @IsString()
  @IsOptional()
  contactName?: string;

  @ApiPropertyOptional({ example: 'ventas@distribuidora.co', description: 'Correo electrónico' })
  @IsEmail()
  @IsOptional()
  email?: string;

  @ApiPropertyOptional({ example: '3115551234', description: 'Teléfono' })
  @IsString()
  @IsOptional()
  phone?: string;

  @ApiPropertyOptional({ example: 'Carrera 7 #80-12, Bogotá', description: 'Dirección' })
  @IsString()
  @IsOptional()
  address?: string;

  @ApiPropertyOptional({ example: true, description: 'Estado activo del proveedor' })
  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @ApiPropertyOptional({ example: 'Entrega los martes y jueves', description: 'Notas adicionales' })
  @IsString()
  @IsOptional()
  notes?: string;
}

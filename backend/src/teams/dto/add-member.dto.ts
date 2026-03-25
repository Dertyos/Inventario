import { IsEmail, IsEnum, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { TeamRole } from '../entities/team-member.entity';

export class AddMemberDto {
  @ApiProperty({
    example: 'maria@mitienda.co',
    description: 'Correo del miembro a agregar',
  })
  @IsEmail()
  email: string;

  @ApiPropertyOptional({
    enum: TeamRole,
    example: 'staff',
    description: 'Rol del miembro en el equipo',
  })
  @IsEnum(TeamRole)
  @IsOptional()
  role?: TeamRole;
}

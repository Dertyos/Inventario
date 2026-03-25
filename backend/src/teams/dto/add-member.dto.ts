import { IsEmail, IsEnum, IsOptional } from 'class-validator';
import { TeamRole } from '../entities/team-member.entity';

export class AddMemberDto {
  @IsEmail()
  email: string;

  @IsEnum(TeamRole)
  @IsOptional()
  role?: TeamRole;
}

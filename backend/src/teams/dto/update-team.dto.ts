import { IsString, IsOptional, MinLength } from 'class-validator';

export class UpdateTeamDto {
  @IsString()
  @MinLength(2)
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  currency?: string;

  @IsString()
  @IsOptional()
  timezone?: string;
}

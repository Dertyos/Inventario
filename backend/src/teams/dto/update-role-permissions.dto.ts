import { IsArray, IsString } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UpdateRolePermissionsDto {
  @ApiProperty({
    example: ['sales.create', 'inventory.view', 'customers.create'],
    description: 'Array of permission keys to assign to the role',
  })
  @IsArray()
  @IsString({ each: true })
  permissions: string[];
}

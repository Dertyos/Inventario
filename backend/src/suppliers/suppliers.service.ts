import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Supplier } from './entities/supplier.entity';
import { CreateSupplierDto } from './dto/create-supplier.dto';
import { UpdateSupplierDto } from './dto/update-supplier.dto';

@Injectable()
export class SuppliersService {
  constructor(
    @InjectRepository(Supplier)
    private readonly suppliersRepository: Repository<Supplier>,
  ) {}

  async create(
    teamId: string,
    createSupplierDto: CreateSupplierDto,
  ): Promise<Supplier> {
    if (createSupplierDto.nit) {
      const existing = await this.suppliersRepository.findOne({
        where: { teamId, nit: createSupplierDto.nit },
      });
      if (existing) {
        throw new ConflictException('Supplier with this NIT already exists');
      }
    }

    const supplier = this.suppliersRepository.create({
      ...createSupplierDto,
      teamId,
    });
    return this.suppliersRepository.save(supplier);
  }

  async findAll(
    teamId: string,
    options?: { search?: string; active?: boolean },
  ): Promise<Supplier[]> {
    const query = this.suppliersRepository
      .createQueryBuilder('supplier')
      .where('supplier.teamId = :teamId', { teamId });

    if (options?.search) {
      query.andWhere(
        '(supplier.name ILIKE :search OR supplier.nit ILIKE :search)',
        { search: `%${options.search}%` },
      );
    }

    if (options?.active !== undefined) {
      query.andWhere('supplier.isActive = :active', {
        active: options.active,
      });
    }

    return query.orderBy('supplier.name', 'ASC').getMany();
  }

  async findOne(teamId: string, id: string): Promise<Supplier> {
    const supplier = await this.suppliersRepository.findOne({
      where: { id, teamId },
    });
    if (!supplier) {
      throw new NotFoundException(`Supplier #${id} not found`);
    }
    return supplier;
  }

  async update(
    teamId: string,
    id: string,
    updateSupplierDto: UpdateSupplierDto,
  ): Promise<Supplier> {
    const supplier = await this.findOne(teamId, id);
    Object.assign(supplier, updateSupplierDto);
    return this.suppliersRepository.save(supplier);
  }
}

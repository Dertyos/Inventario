import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Customer } from './entities/customer.entity';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';

@Injectable()
export class CustomersService {
  constructor(
    @InjectRepository(Customer)
    private readonly customersRepository: Repository<Customer>,
  ) {}

  async create(
    teamId: string,
    createCustomerDto: CreateCustomerDto,
  ): Promise<Customer> {
    if (createCustomerDto.documentNumber) {
      const existing = await this.customersRepository.findOne({
        where: { teamId, documentNumber: createCustomerDto.documentNumber },
      });
      if (existing) {
        throw new ConflictException(
          'Customer with this document already exists',
        );
      }
    }

    const customer = this.customersRepository.create({
      ...createCustomerDto,
      teamId,
    });
    return this.customersRepository.save(customer);
  }

  async findAll(
    teamId: string,
    options?: { search?: string },
  ): Promise<Customer[]> {
    const query = this.customersRepository
      .createQueryBuilder('customer')
      .where('customer.teamId = :teamId', { teamId });

    if (options?.search) {
      query.andWhere(
        '(customer.name ILIKE :search OR customer.documentNumber ILIKE :search OR customer.phone ILIKE :search)',
        { search: `%${options.search}%` },
      );
    }

    return query.orderBy('customer.name', 'ASC').getMany();
  }

  async findOne(teamId: string, id: string): Promise<Customer> {
    const customer = await this.customersRepository.findOne({
      where: { id, teamId },
      relations: ['sales'],
    });
    if (!customer) {
      throw new NotFoundException(`Customer #${id} not found`);
    }
    return customer;
  }

  async update(
    teamId: string,
    id: string,
    updateCustomerDto: UpdateCustomerDto,
  ): Promise<Customer> {
    const customer = await this.findOne(teamId, id);
    Object.assign(customer, updateCustomerDto);
    return this.customersRepository.save(customer);
  }

  async remove(teamId: string, id: string): Promise<void> {
    const customer = await this.findOne(teamId, id);
    if (customer.sales && customer.sales.length > 0) {
      throw new ConflictException(
        'Cannot delete customer with associated sales',
      );
    }
    await this.customersRepository.remove(customer);
  }
}

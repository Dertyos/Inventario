import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Product } from './entities/product.entity';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';

@Injectable()
export class ProductsService {
  constructor(
    @InjectRepository(Product)
    private readonly productsRepository: Repository<Product>,
  ) {}

  async create(
    teamId: string,
    createProductDto: CreateProductDto,
  ): Promise<Product> {
    const existing = await this.productsRepository.findOne({
      where: { teamId, sku: createProductDto.sku },
    });
    if (existing) {
      throw new ConflictException('SKU already exists in this team');
    }

    const product = this.productsRepository.create({
      ...createProductDto,
      teamId,
    });
    return this.productsRepository.save(product);
  }

  async findAll(
    teamId: string,
    options?: {
      categoryId?: string;
      isActive?: boolean;
      search?: string;
    },
  ): Promise<Product[]> {
    const query = this.productsRepository
      .createQueryBuilder('product')
      .leftJoinAndSelect('product.category', 'category')
      .where('product.teamId = :teamId', { teamId });

    if (options?.categoryId) {
      query.andWhere('product.categoryId = :categoryId', {
        categoryId: options.categoryId,
      });
    }

    if (options?.isActive !== undefined) {
      query.andWhere('product.isActive = :isActive', {
        isActive: options.isActive,
      });
    }

    if (options?.search) {
      query.andWhere(
        '(product.name ILIKE :search OR product.sku ILIKE :search)',
        { search: `%${options.search}%` },
      );
    }

    return query.orderBy('product.name', 'ASC').getMany();
  }

  async findOne(teamId: string, id: string): Promise<Product> {
    const product = await this.productsRepository.findOne({
      where: { id, teamId },
      relations: ['category'],
    });
    if (!product) {
      throw new NotFoundException(`Product #${id} not found`);
    }
    return product;
  }

  async update(
    teamId: string,
    id: string,
    updateProductDto: UpdateProductDto,
  ): Promise<Product> {
    const product = await this.findOne(teamId, id);
    Object.assign(product, updateProductDto);
    return this.productsRepository.save(product);
  }

  async remove(teamId: string, id: string): Promise<void> {
    const product = await this.findOne(teamId, id);
    product.isActive = false;
    await this.productsRepository.save(product);
  }

  async findLowStock(teamId: string): Promise<Product[]> {
    return this.productsRepository
      .createQueryBuilder('product')
      .leftJoinAndSelect('product.category', 'category')
      .where('product.teamId = :teamId', { teamId })
      .andWhere('product.stock <= product.minStock')
      .andWhere('product.isActive = true')
      .orderBy('product.stock', 'ASC')
      .getMany();
  }
}

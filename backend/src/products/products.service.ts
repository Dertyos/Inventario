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
    // Auto-generate SKU if not provided
    if (!createProductDto.sku) {
      const count = await this.productsRepository.count({ where: { teamId } });
      createProductDto.sku = `PROD-${String(count + 1).padStart(4, '0')}`;
    }

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
      page?: number;
      limit?: number;
    },
  ): Promise<Product[] | { data: Product[]; total: number; page: number; limit: number }> {
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
        '(product.name ILIKE :search OR product.sku ILIKE :search OR product.barcode ILIKE :search)',
        { search: `%${options.search}%` },
      );
    }

    query.orderBy('product.name', 'ASC');

    if (options?.page && options?.limit) {
      const page = Math.max(1, options.page);
      const limit = Math.max(1, options.limit);
      query.skip((page - 1) * limit).take(limit);
      const [data, total] = await query.getManyAndCount();
      return { data, total, page, limit };
    }

    return query.getMany();
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

    if (updateProductDto.sku && updateProductDto.sku !== product.sku) {
      const existing = await this.productsRepository.findOne({
        where: { teamId, sku: updateProductDto.sku },
      });
      if (existing) {
        throw new ConflictException('Ya existe un producto con ese código en este equipo');
      }
    }

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

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

  async create(createProductDto: CreateProductDto): Promise<Product> {
    const existing = await this.productsRepository.findOne({
      where: { sku: createProductDto.sku },
    });
    if (existing) {
      throw new ConflictException('SKU already exists');
    }

    const product = this.productsRepository.create(createProductDto);
    return this.productsRepository.save(product);
  }

  async findAll(options?: {
    categoryId?: string;
    isActive?: boolean;
    search?: string;
  }): Promise<Product[]> {
    const query = this.productsRepository
      .createQueryBuilder('product')
      .leftJoinAndSelect('product.category', 'category');

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

  async findOne(id: string): Promise<Product> {
    const product = await this.productsRepository.findOne({
      where: { id },
      relations: ['category'],
    });
    if (!product) {
      throw new NotFoundException(`Product #${id} not found`);
    }
    return product;
  }

  async update(
    id: string,
    updateProductDto: UpdateProductDto,
  ): Promise<Product> {
    const product = await this.findOne(id);
    Object.assign(product, updateProductDto);
    return this.productsRepository.save(product);
  }

  async remove(id: string): Promise<void> {
    const product = await this.findOne(id);
    product.isActive = false;
    await this.productsRepository.save(product);
  }

  async findLowStock(): Promise<Product[]> {
    return this.productsRepository
      .createQueryBuilder('product')
      .leftJoinAndSelect('product.category', 'category')
      .where('product.stock <= product.minStock')
      .andWhere('product.isActive = true')
      .orderBy('product.stock', 'ASC')
      .getMany();
  }
}

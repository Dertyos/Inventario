import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Category } from './entities/category.entity';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';

@Injectable()
export class CategoriesService {
  constructor(
    @InjectRepository(Category)
    private readonly categoriesRepository: Repository<Category>,
  ) {}

  async create(
    teamId: string,
    createCategoryDto: CreateCategoryDto,
  ): Promise<Category> {
    const existing = await this.categoriesRepository.findOne({
      where: { teamId, name: createCategoryDto.name },
    });
    if (existing) {
      throw new ConflictException('Category name already exists in this team');
    }

    const category = this.categoriesRepository.create({
      ...createCategoryDto,
      teamId,
    });
    return this.categoriesRepository.save(category);
  }

  async findAll(teamId: string): Promise<Category[]> {
    return this.categoriesRepository.find({
      where: { teamId },
      order: { name: 'ASC' },
    });
  }

  async findOne(teamId: string, id: string): Promise<Category> {
    const category = await this.categoriesRepository.findOne({
      where: { id, teamId },
      relations: ['products'],
    });
    if (!category) {
      throw new NotFoundException(`Category #${id} not found`);
    }
    return category;
  }

  async update(
    teamId: string,
    id: string,
    updateCategoryDto: UpdateCategoryDto,
  ): Promise<Category> {
    const category = await this.findOne(teamId, id);
    Object.assign(category, updateCategoryDto);
    return this.categoriesRepository.save(category);
  }

  async remove(teamId: string, id: string): Promise<void> {
    const category = await this.findOne(teamId, id);
    if (category.products && category.products.length > 0) {
      throw new ConflictException(
        'Cannot delete category with associated products',
      );
    }
    await this.categoriesRepository.remove(category);
  }
}

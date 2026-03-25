import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import Anthropic from '@anthropic-ai/sdk';
import { AiService } from './ai.service';
import { AiController } from './ai.controller';
import { ANTHROPIC_CLIENT } from './claude.provider';
import { ProductsModule } from '../products/products.module';

@Module({
  imports: [ConfigModule, ProductsModule],
  controllers: [AiController],
  providers: [
    {
      provide: ANTHROPIC_CLIENT,
      useFactory: (config: ConfigService) => {
        const apiKey = config.get<string>('ANTHROPIC_API_KEY');
        if (!apiKey) {
          return null;
        }
        return new Anthropic({
          apiKey,
          maxRetries: 3,
          timeout: 15_000,
        });
      },
      inject: [ConfigService],
    },
    AiService,
  ],
  exports: [AiService],
})
export class AiModule {}

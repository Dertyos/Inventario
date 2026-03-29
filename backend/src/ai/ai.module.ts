import { Module, Logger } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AiService } from './ai.service';
import { AiController } from './ai.controller';
import { AI_PROVIDER, IAiProvider } from './ai-provider.interface';
import { AnthropicProvider } from './providers/anthropic.provider';
import { OpenAiProvider } from './providers/openai.provider';
import { GeminiProvider } from './providers/gemini.provider';
import { GroqProvider } from './providers/groq.provider';
import { ProductsModule } from '../products/products.module';
import { TeamsModule } from '../teams/teams.module';
import { CategoriesModule } from '../categories/categories.module';
import { CustomersModule } from '../customers/customers.module';
import { SuppliersModule } from '../suppliers/suppliers.module';

const logger = new Logger('AiModule');

@Module({
  imports: [
    ConfigModule,
    ProductsModule,
    TeamsModule,
    CategoriesModule,
    CustomersModule,
    SuppliersModule,
  ],
  controllers: [AiController],
  providers: [
    {
      provide: AI_PROVIDER,
      useFactory: (config: ConfigService): IAiProvider | null => {
        const providerName = config.get<string>('AI_PROVIDER', 'anthropic');

        switch (providerName) {
          case 'openai': {
            const key = config.get<string>('OPENAI_API_KEY');
            if (!key) { logger.warn('OPENAI_API_KEY not set'); return null; }
            logger.log('AI provider: OpenAI');
            return new OpenAiProvider(key);
          }
          case 'gemini': {
            const key = config.get<string>('GEMINI_API_KEY');
            if (!key) { logger.warn('GEMINI_API_KEY not set'); return null; }
            logger.log('AI provider: Google Gemini');
            return new GeminiProvider(key);
          }
          case 'groq': {
            const key = config.get<string>('GROQ_API_KEY');
            if (!key) { logger.warn('GROQ_API_KEY not set'); return null; }
            logger.log('AI provider: Groq');
            return new GroqProvider(key);
          }
          case 'anthropic':
          default: {
            const key = config.get<string>('ANTHROPIC_API_KEY');
            if (!key) { logger.warn('ANTHROPIC_API_KEY not set'); return null; }
            logger.log('AI provider: Anthropic (Claude)');
            return new AnthropicProvider(key);
          }
        }
      },
      inject: [ConfigService],
    },
    AiService,
  ],
  exports: [AiService],
})
export class AiModule {}

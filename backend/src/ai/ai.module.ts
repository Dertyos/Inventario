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

function createProvider(name: string, config: ConfigService): IAiProvider | null {
  switch (name) {
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
}

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
        const explicit = config.get<string>('AI_PROVIDER');

        // If AI_PROVIDER is set explicitly, use that
        if (explicit) {
          return createProvider(explicit, config);
        }

        // Auto-detect: use whichever API key is configured
        const autoDetect: [string, string][] = [
          ['anthropic', 'ANTHROPIC_API_KEY'],
          ['openai', 'OPENAI_API_KEY'],
          ['gemini', 'GEMINI_API_KEY'],
          ['groq', 'GROQ_API_KEY'],
        ];

        for (const [name, envVar] of autoDetect) {
          if (config.get<string>(envVar)) {
            logger.log(`Auto-detected AI provider from ${envVar}`);
            return createProvider(name, config);
          }
        }

        logger.warn(
          'No AI provider configured. Set any API key: ANTHROPIC_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY, or GROQ_API_KEY',
        );
        return null;
      },
      inject: [ConfigService],
    },
    AiService,
  ],
  exports: [AiService],
})
export class AiModule {}

import { Module, Logger } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AiService } from './ai.service';
import { AiController } from './ai.controller';
import { AI_PROVIDER, IAiProvider } from './ai-provider.interface';
import { AnthropicProvider } from './providers/anthropic.provider';
import { OpenAiProvider } from './providers/openai.provider';
import { GeminiProvider } from './providers/gemini.provider';
import { GroqProvider } from './providers/groq.provider';
import { DeepSeekProvider } from './providers/deepseek.provider';
import { ProductsModule } from '../products/products.module';
import { TeamsModule } from '../teams/teams.module';
import { CategoriesModule } from '../categories/categories.module';
import { CustomersModule } from '../customers/customers.module';
import { SuppliersModule } from '../suppliers/suppliers.module';

const logger = new Logger('AiModule');

/**
 * Config:
 *   AI_PROVIDER=anthropic|openai|gemini|groq  (required)
 *   AI_API_KEY=sk-...                         (required)
 *
 * Also supports legacy per-provider keys (ANTHROPIC_API_KEY, etc.)
 * for backward compatibility.
 */
function createFromConfig(config: ConfigService): IAiProvider | null {
  const provider = config.get<string>('AI_PROVIDER');
  // Unified key first, fallback to legacy per-provider keys
  const apiKey = config.get<string>('AI_API_KEY');

  if (!provider && !apiKey) {
    // Legacy auto-detect: check individual keys
    const legacy: [string, string][] = [
      ['anthropic', 'ANTHROPIC_API_KEY'],
      ['openai', 'OPENAI_API_KEY'],
      ['gemini', 'GEMINI_API_KEY'],
      ['groq', 'GROQ_API_KEY'],
      ['deepseek', 'DEEPSEEK_API_KEY'],
    ];
    for (const [name, envVar] of legacy) {
      const key = config.get<string>(envVar);
      if (key) {
        logger.log(`AI provider: ${name} (auto-detected from ${envVar})`);
        return buildProvider(name, key);
      }
    }
    logger.warn('No AI configured. Set AI_PROVIDER + AI_API_KEY.');
    return null;
  }

  if (!provider) {
    logger.warn('AI_API_KEY is set but AI_PROVIDER is missing. Set AI_PROVIDER=anthropic|openai|gemini|groq');
    return null;
  }

  const key = apiKey
    || config.get<string>('ANTHROPIC_API_KEY')
    || config.get<string>('OPENAI_API_KEY')
    || config.get<string>('GEMINI_API_KEY')
    || config.get<string>('GROQ_API_KEY');

  if (!key) {
    logger.warn(`AI_PROVIDER=${provider} but no AI_API_KEY set.`);
    return null;
  }

  logger.log(`AI provider: ${provider}`);
  return buildProvider(provider, key);
}

function buildProvider(name: string, apiKey: string): IAiProvider {
  switch (name) {
    case 'openai':
      return new OpenAiProvider(apiKey);
    case 'gemini':
      return new GeminiProvider(apiKey);
    case 'groq':
      return new GroqProvider(apiKey);
    case 'deepseek':
      return new DeepSeekProvider(apiKey);
    case 'anthropic':
    default:
      return new AnthropicProvider(apiKey);
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
      useFactory: (config: ConfigService): IAiProvider | null =>
        createFromConfig(config),
      inject: [ConfigService],
    },
    AiService,
  ],
  exports: [AiService],
})
export class AiModule {}

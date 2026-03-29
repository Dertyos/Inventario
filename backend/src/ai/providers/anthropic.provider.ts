import Anthropic from '@anthropic-ai/sdk';
import { IAiProvider, AiTool, AiToolResponse } from '../ai-provider.interface';

export class AnthropicProvider implements IAiProvider {
  readonly name = 'anthropic';
  private client: Anthropic;

  constructor(apiKey: string) {
    this.client = new Anthropic({
      apiKey,
      maxRetries: 3,
      timeout: 30_000,
    });
  }

  async callWithTool(config: {
    model?: string;
    systemPrompt: string;
    userMessage: string;
    tool: AiTool;
    maxTokens?: number;
  }): Promise<AiToolResponse> {
    const model = config.model || 'claude-haiku-4-5-20251001';

    const response = await this.client.messages.create({
      model,
      max_tokens: config.maxTokens || 1024,
      temperature: 0,
      tools: [
        {
          name: config.tool.name,
          description: config.tool.description,
          input_schema: {
            type: 'object' as const,
            ...config.tool.parameters,
          },
        },
      ],
      tool_choice: { type: 'tool' as const, name: config.tool.name },
      system: config.systemPrompt,
      messages: [{ role: 'user' as const, content: config.userMessage }],
    });

    const toolBlock = response.content.find(
      (b: any) => b.type === 'tool_use',
    );

    if (!toolBlock || toolBlock.type !== 'tool_use') {
      throw new Error('Anthropic did not return a tool_use block');
    }

    return {
      toolName: (toolBlock as any).name,
      toolInput: (toolBlock as any).input as Record<string, any>,
    };
  }
}

import { IAiProvider, AiTool, AiToolResponse } from '../ai-provider.interface';

/**
 * OpenAI provider (GPT-4o, GPT-4o-mini, etc.)
 * Install: npm install openai
 */
export class OpenAiProvider implements IAiProvider {
  readonly name = 'openai';
  private client: any; // OpenAI SDK

  constructor(apiKey: string) {
    // Dynamic import to avoid requiring openai as a hard dependency
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const OpenAI = require('openai').default;
    this.client = new OpenAI({ apiKey, timeout: 30_000, maxRetries: 3 });
  }

  async callWithTool(config: {
    model?: string;
    systemPrompt: string;
    userMessage: string;
    tool: AiTool;
    maxTokens?: number;
  }): Promise<AiToolResponse> {
    const model = config.model || 'gpt-4o-mini';

    const response = await this.client.chat.completions.create({
      model,
      max_tokens: config.maxTokens || 1024,
      temperature: 0,
      tools: [
        {
          type: 'function',
          function: {
            name: config.tool.name,
            description: config.tool.description,
            parameters: {
              type: 'object',
              ...config.tool.parameters,
            },
          },
        },
      ],
      tool_choice: {
        type: 'function',
        function: { name: config.tool.name },
      },
      messages: [
        { role: 'system', content: config.systemPrompt },
        { role: 'user', content: config.userMessage },
      ],
    });

    const toolCall = response.choices?.[0]?.message?.tool_calls?.[0];
    if (!toolCall) {
      throw new Error('OpenAI did not return a tool call');
    }

    return {
      toolName: toolCall.function.name,
      toolInput: JSON.parse(toolCall.function.arguments),
    };
  }
}

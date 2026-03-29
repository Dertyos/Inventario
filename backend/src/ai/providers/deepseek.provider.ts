import { IAiProvider, AiTool, AiToolResponse } from '../ai-provider.interface';

/**
 * DeepSeek provider (deepseek-chat, etc.)
 * Uses OpenAI-compatible API.
 * Very cheap: $0.14/1M input tokens, $0.28/1M output tokens.
 */
export class DeepSeekProvider implements IAiProvider {
  readonly name = 'deepseek';
  private client: any;

  constructor(apiKey: string) {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const OpenAI = require('openai').default;
    this.client = new OpenAI({
      apiKey,
      baseURL: 'https://api.deepseek.com',
      timeout: 30_000,
      maxRetries: 3,
    });
  }

  async callWithTool(config: {
    model?: string;
    systemPrompt: string;
    userMessage: string;
    tool: AiTool;
    maxTokens?: number;
  }): Promise<AiToolResponse> {
    const model = config.model || 'deepseek-chat';

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
      throw new Error('DeepSeek did not return a tool call');
    }

    return {
      toolName: toolCall.function.name,
      toolInput: JSON.parse(toolCall.function.arguments),
    };
  }
}

import { IAiProvider, AiTool, AiToolResponse } from '../ai-provider.interface';

/**
 * Groq provider (llama-3.3-70b, mixtral, etc.)
 * Uses OpenAI-compatible API, so we use the openai SDK.
 * Install: npm install openai (if not already installed)
 */
export class GroqProvider implements IAiProvider {
  readonly name = 'groq';
  private client: any; // OpenAI SDK pointed at Groq

  constructor(apiKey: string) {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const OpenAI = require('openai').default;
    this.client = new OpenAI({
      apiKey,
      baseURL: 'https://api.groq.com/openai/v1',
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
    const model = config.model || 'llama-3.3-70b-versatile';

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
      throw new Error('Groq did not return a tool call');
    }

    return {
      toolName: toolCall.function.name,
      toolInput: JSON.parse(toolCall.function.arguments),
    };
  }
}

import { IAiProvider, AiTool, AiToolResponse } from '../ai-provider.interface';

/**
 * Google Gemini provider (gemini-2.0-flash, gemini-1.5-pro, etc.)
 * Install: npm install @google/generative-ai
 */
export class GeminiProvider implements IAiProvider {
  readonly name = 'gemini';
  private client: any; // GoogleGenerativeAI

  constructor(apiKey: string) {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { GoogleGenerativeAI } = require('@google/generative-ai');
    this.client = new GoogleGenerativeAI(apiKey);
  }

  async callWithTool(config: {
    model?: string;
    systemPrompt: string;
    userMessage: string;
    tool: AiTool;
    maxTokens?: number;
  }): Promise<AiToolResponse> {
    const modelName = config.model || 'gemini-2.5-flash';

    const model = this.client.getGenerativeModel({
      model: modelName,
      systemInstruction: config.systemPrompt,
      tools: [
        {
          functionDeclarations: [
            {
              name: config.tool.name,
              description: config.tool.description,
              parameters: {
                type: 'OBJECT',
                ...this.convertSchema(config.tool.parameters),
              },
            },
          ],
        },
      ],
      toolConfig: {
        functionCallingConfig: {
          mode: 'ANY',
          allowedFunctionNames: [config.tool.name],
        },
      },
      generationConfig: {
        temperature: 0,
        maxOutputTokens: config.maxTokens || 1024,
      },
    });

    const result = await model.generateContent(config.userMessage);
    const response = result.response;
    const functionCall = response.candidates?.[0]?.content?.parts?.find(
      (p: any) => p.functionCall,
    );

    if (!functionCall?.functionCall) {
      throw new Error('Gemini did not return a function call');
    }

    return {
      toolName: functionCall.functionCall.name,
      toolInput: functionCall.functionCall.args,
    };
  }

  /** Convert JSON Schema types to Gemini format (STRING instead of string, etc.) */
  private convertSchema(schema: Record<string, any>): Record<string, any> {
    const result: Record<string, any> = {};
    if (schema.properties) {
      result.properties = {};
      for (const [key, val] of Object.entries(schema.properties)) {
        result.properties[key] = this.convertType(val as any);
      }
    }
    if (schema.required) result.required = schema.required;
    return result;
  }

  private convertType(prop: Record<string, any>): Record<string, any> {
    const typeMap: Record<string, string> = {
      string: 'STRING',
      number: 'NUMBER',
      integer: 'INTEGER',
      boolean: 'BOOLEAN',
      array: 'ARRAY',
      object: 'OBJECT',
    };
    const converted: Record<string, any> = {
      ...prop,
      type: typeMap[prop.type] || prop.type,
    };
    if (prop.items) {
      converted.items = this.convertType(prop.items);
    }
    if (prop.properties) {
      converted.properties = {};
      for (const [k, v] of Object.entries(prop.properties)) {
        converted.properties[k] = this.convertType(v as any);
      }
    }
    if (prop.enum) converted.enum = prop.enum;
    return converted;
  }
}

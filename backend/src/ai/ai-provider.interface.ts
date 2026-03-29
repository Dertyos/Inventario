/**
 * AI Provider abstraction layer.
 *
 * Supports: Anthropic (Claude), OpenAI (GPT), Google (Gemini), Groq
 *
 * Environment variables:
 *   AI_PROVIDER=anthropic|openai|gemini|groq  (default: anthropic)
 *   ANTHROPIC_API_KEY=sk-ant-...
 *   OPENAI_API_KEY=sk-...
 *   GEMINI_API_KEY=AI...
 *   GROQ_API_KEY=gsk_...
 */

export const AI_PROVIDER = Symbol('AI_PROVIDER');

/** Universal tool definition (provider-agnostic). */
export interface AiTool {
  name: string;
  description: string;
  parameters: Record<string, any>; // JSON Schema
}

/** Normalized response from any provider. */
export interface AiToolResponse {
  toolName: string;
  toolInput: Record<string, any>;
}

/** Common interface all providers implement. */
export interface IAiProvider {
  readonly name: string;

  callWithTool(config: {
    model?: string;
    systemPrompt: string;
    userMessage: string;
    tool: AiTool;
    maxTokens?: number;
  }): Promise<AiToolResponse>;
}

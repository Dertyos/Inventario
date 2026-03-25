import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Anthropic from '@anthropic-ai/sdk';
import { ProductsService } from '../products/products.service';

interface ParsedItem {
  name: string;
  quantity: number;
  unitPrice?: number;
  matchedProductId?: string;
}

interface ParsedTransaction {
  type: 'sale' | 'purchase';
  items: ParsedItem[];
  customerOrSupplier?: string;
  totalAmount?: number;
  notes?: string;
  rawText: string;
  confidence: number;
}

@Injectable()
export class AiService {
  private readonly logger = new Logger(AiService.name);
  private readonly anthropic: Anthropic;

  constructor(
    private readonly config: ConfigService,
    private readonly productsService: ProductsService,
  ) {
    this.anthropic = new Anthropic({
      apiKey: this.config.get<string>('ANTHROPIC_API_KEY'),
    });
  }

  async parseTransaction(
    teamId: string,
    text: string,
  ): Promise<ParsedTransaction> {
    // Get team's product catalog for matching
    const products = await this.productsService.findAll(teamId);
    const productCatalog = products.map((p) => ({
      id: p.id,
      name: p.name,
      price: p.price,
      sku: p.sku,
    }));

    const systemPrompt = `Eres un asistente que parsea transacciones comerciales en lenguaje natural al español colombiano.

Catálogo de productos del negocio:
${JSON.stringify(productCatalog, null, 2)}

Responde SOLO con JSON válido, sin markdown ni explicaciones. El formato:
{
  "type": "sale" | "purchase",
  "items": [{ "name": "string", "quantity": number, "unitPrice": number | null, "matchedProductId": "string | null" }],
  "customerOrSupplier": "string | null",
  "totalAmount": number | null,
  "notes": "string | null",
  "confidence": number (0.0 a 1.0)
}

Reglas:
- Detecta si es venta (venta, vendí, le vendí) o compra (compra, compré, entrada, recibí del proveedor).
- Intenta hacer match de nombres de productos con el catálogo. Si hay match, usa matchedProductId y el precio del catálogo si no se especificó uno.
- "25 mil" = 25000, "5 lucas" = 5000. Interpreta jerga colombiana de dinero.
- Si no puedes determinar algo con certeza, pon null y baja la confidence.
- Si el texto no parece una transacción, retorna confidence < 0.3.`;

    try {
      const response = await this.anthropic.messages.create({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 1024,
        system: systemPrompt,
        messages: [{ role: 'user', content: text }],
      });

      const content = response.content[0];
      if (content.type !== 'text') {
        throw new Error('Unexpected response type');
      }

      const parsed: Omit<ParsedTransaction, 'rawText'> = JSON.parse(
        content.text,
      );

      return {
        ...parsed,
        rawText: text,
      };
    } catch (error) {
      this.logger.error(`Failed to parse transaction: ${error.message}`);
      throw error;
    }
  }
}

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Resend } from 'resend';

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private readonly resend: Resend | null;
  private readonly from: string;

  constructor(private readonly config: ConfigService) {
    const apiKey = this.config.get<string>('RESEND_API_KEY');
    this.from = 'Inventario <inventarios@dertyos.com>';

    if (!apiKey) {
      this.logger.warn(
        'RESEND_API_KEY not configured – email sending is disabled',
      );
      this.resend = null;
    } else {
      this.resend = new Resend(apiKey);
    }
  }

  async sendVerificationCode(email: string, code: string): Promise<void> {
    await this.send(
      email,
      'Código de verificación - Inventario',
      `
      <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px;">
        <h2 style="color: #333;">Verifica tu correo electrónico</h2>
        <p>Tu código de verificación es:</p>
        <div style="background: #f4f4f4; padding: 16px; text-align: center; border-radius: 8px; margin: 16px 0;">
          <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #111;">${code}</span>
        </div>
        <p style="color: #666; font-size: 14px;">Expira en 10 minutos. Si no solicitaste este código, ignora este mensaje.</p>
      </div>
      `,
    );
  }

  async sendPasswordResetCode(email: string, code: string): Promise<void> {
    await this.send(
      email,
      'Restablecer contraseña - Inventario',
      `
      <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px;">
        <h2 style="color: #333;">Restablecer contraseña</h2>
        <p>Tu código para restablecer tu contraseña es:</p>
        <div style="background: #f4f4f4; padding: 16px; text-align: center; border-radius: 8px; margin: 16px 0;">
          <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #111;">${code}</span>
        </div>
        <p style="color: #666; font-size: 14px;">Expira en 10 minutos. Si no solicitaste este código, ignora este mensaje.</p>
      </div>
      `,
    );
  }

  async sendTeamInvitation(
    email: string,
    teamName: string,
    inviterName: string,
    inviteLink: string,
  ): Promise<void> {
    await this.send(
      email,
      `Invitación al equipo ${teamName} - Inventario`,
      `
      <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px;">
        <h2 style="color: #333;">Has sido invitado a un equipo</h2>
        <p><strong>${inviterName}</strong> te ha invitado al equipo <strong>${teamName}</strong> en Inventario.</p>
        <p>Descarga la app para unirte:</p>
        <a href="${inviteLink}" style="display: inline-block; background: #4F46E5; color: #fff; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: bold;">Unirme al equipo</a>
      </div>
      `,
    );
  }

  private async send(
    to: string,
    subject: string,
    html: string,
  ): Promise<void> {
    if (!this.resend) {
      this.logger.warn(`Email not sent (no API key): to=${to} subject=${subject}`);
      return;
    }

    try {
      await this.resend.emails.send({
        from: this.from,
        to,
        subject,
        html,
      });
      this.logger.log(`Email sent to ${to}: ${subject}`);
    } catch (error) {
      this.logger.error(`Failed to send email to ${to}: ${error.message}`);
    }
  }
}

import {
  Controller,
  Get,
  Param,
  Res,
  NotFoundException,
} from '@nestjs/common';
import { Response } from 'express';
import { TeamsService } from './teams.service';

@Controller('invite')
export class InviteLandingController {
  constructor(private readonly teamsService: TeamsService) {}

  @Get(':token')
  async inviteLanding(@Param('token') token: string, @Res() res: Response) {
    let invite;
    try {
      invite = await this.teamsService.getInvitationByToken(token);
    } catch {
      throw new NotFoundException('Invitación no encontrada');
    }

    const teamName = invite.team.name;
    const inviterName =
      `${invite.inviter.firstName} ${invite.inviter.lastName}`.trim();
    const deepLink = `inventario://invite/${token}`;
    const webLink = `https://inventario.dertyos.com/invite/${token}`;

    const html = `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Invitación a ${this.escapeHtml(teamName)} - Inventario</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .card {
      background: white;
      border-radius: 16px;
      padding: 40px 32px;
      max-width: 420px;
      width: 100%;
      text-align: center;
      box-shadow: 0 20px 60px rgba(0,0,0,0.15);
    }
    .logo {
      width: 64px;
      height: 64px;
      background: #4F46E5;
      border-radius: 16px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 24px;
      font-size: 28px;
      color: white;
      font-weight: bold;
    }
    h1 {
      color: #1a1a2e;
      font-size: 22px;
      margin-bottom: 8px;
    }
    .subtitle {
      color: #666;
      font-size: 15px;
      margin-bottom: 32px;
      line-height: 1.5;
    }
    .team-name {
      color: #4F46E5;
      font-weight: 600;
    }
    .inviter {
      font-weight: 500;
    }
    .btn {
      display: block;
      width: 100%;
      padding: 14px 24px;
      border-radius: 10px;
      font-size: 16px;
      font-weight: 600;
      text-decoration: none;
      margin-bottom: 12px;
      cursor: pointer;
      border: none;
      transition: transform 0.1s, box-shadow 0.1s;
    }
    .btn:active { transform: scale(0.98); }
    .btn-primary {
      background: #4F46E5;
      color: white;
      box-shadow: 0 4px 14px rgba(79, 70, 229, 0.4);
    }
    .btn-primary:hover {
      background: #4338CA;
    }
    .btn-secondary {
      background: #f3f4f6;
      color: #374151;
    }
    .btn-secondary:hover {
      background: #e5e7eb;
    }
    .footer {
      margin-top: 24px;
      color: #999;
      font-size: 13px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">I</div>
    <h1>Te han invitado a un equipo</h1>
    <p class="subtitle">
      <span class="inviter">${this.escapeHtml(inviterName)}</span> te ha invitado
      al equipo <span class="team-name">${this.escapeHtml(teamName)}</span> en Inventario.
    </p>
    <a href="${deepLink}" class="btn btn-primary" id="openApp">
      Abrir en la app
    </a>
    <a href="https://github.com/DertyCorp/Inventario/releases" class="btn btn-secondary">
      Descargar la app
    </a>
    <p class="footer">Inventario - Gesti&oacute;n de inventario simplificada</p>
  </div>
  <script>
    // Try deep link first, fall back to web link
    document.getElementById('openApp').addEventListener('click', function(e) {
      e.preventDefault();
      var deepLink = '${deepLink}';
      var webLink = '${webLink}';
      window.location.href = deepLink;
      setTimeout(function() {
        // If the deep link didn't work (app not installed), the page is still here
        // Do nothing - user can click "Download" instead
      }, 2000);
    });
  </script>
</body>
</html>`;

    res.setHeader('Content-Type', 'text/html');
    res.send(html);
  }

  private escapeHtml(str: string): string {
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }
}

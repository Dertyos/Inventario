import { Controller, Get, Res } from '@nestjs/common';
import { Response } from 'express';

@Controller('.well-known')
export class WellKnownController {
  @Get('assetlinks.json')
  assetLinks(@Res() res: Response) {
    const json = [
      {
        relation: ['delegate_permission/common.handle_all_urls'],
        target: {
          namespace: 'android_app',
          package_name: 'com.inventario.inventario_mobile',
          sha256_cert_fingerprints: [
            'TODO:REPLACE_WITH_YOUR_SHA256_FINGERPRINT',
          ],
        },
      },
    ];
    res.setHeader('Content-Type', 'application/json');
    res.send(JSON.stringify(json));
  }

  @Get('apple-app-site-association')
  appleAppSiteAssociation(@Res() res: Response) {
    const json = {
      applinks: {
        apps: [],
        details: [
          {
            appID: 'TEAMID.com.inventario.inventarioMobile',
            paths: ['/invite/*'],
          },
        ],
      },
    };
    res.setHeader('Content-Type', 'application/json');
    res.send(JSON.stringify(json));
  }
}

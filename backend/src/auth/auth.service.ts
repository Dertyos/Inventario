import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { v4 as uuidv4 } from 'uuid';
import { UsersService } from '../users/users.service';
import { EmailService } from '../email/email.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly emailService: EmailService,
  ) {}

  async register(registerDto: RegisterDto) {
    const user = await this.usersService.create(registerDto);

    // Generate verification code and send email
    const code = this.generateSixDigitCode();
    const hashedCode = await bcrypt.hash(code, 10);
    const expiry = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await this.usersService.updateVerification(user.id, {
      verificationCode: hashedCode,
      verificationCodeExpiry: expiry,
      verificationAttempts: 0,
    });

    await this.emailService.sendVerificationCode(user.email, code);

    const token = this.generateToken(user.id, user.email);
    return {
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        emailVerified: false,
      },
      accessToken: token,
    };
  }

  async login(loginDto: LoginDto) {
    const user = await this.usersService.findByEmail(loginDto.email);
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const isPasswordValid = await bcrypt.compare(
      loginDto.password,
      user.password,
    );
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (!user.isActive) {
      throw new UnauthorizedException('Account is deactivated');
    }

    const token = this.generateToken(user.id, user.email);
    return {
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        emailVerified: user.emailVerified,
      },
      accessToken: token,
    };
  }

  async getProfile(userId: string) {
    const user = await this.usersService.findOne(userId);
    return {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      emailVerified: user.emailVerified,
    };
  }

  async verifyEmail(email: string, code: string) {
    const user = await this.usersService.findByEmail(email);
    if (!user) {
      throw new BadRequestException('Código inválido o expirado');
    }

    if (user.emailVerified) {
      return { message: 'El correo ya está verificado' };
    }

    if (!user.verificationCode || !user.verificationCodeExpiry) {
      throw new BadRequestException('Código inválido o expirado');
    }

    if (user.verificationAttempts >= 5) {
      // Invalidate the code after 5 attempts
      await this.usersService.updateVerification(user.id, {
        verificationCode: null,
        verificationCodeExpiry: null,
        verificationAttempts: 0,
      });
      throw new BadRequestException(
        'Demasiados intentos. Solicita un nuevo código.',
      );
    }

    if (new Date() > user.verificationCodeExpiry) {
      throw new BadRequestException('Código inválido o expirado');
    }

    const isCodeValid = await bcrypt.compare(code, user.verificationCode);
    if (!isCodeValid) {
      await this.usersService.updateVerification(user.id, {
        verificationAttempts: user.verificationAttempts + 1,
      });
      throw new BadRequestException('Código inválido o expirado');
    }

    await this.usersService.updateVerification(user.id, {
      emailVerified: true,
      verificationCode: null,
      verificationCodeExpiry: null,
      verificationAttempts: 0,
    });

    return { message: 'Correo verificado exitosamente' };
  }

  async resendVerification(email: string) {
    const user = await this.usersService.findByEmail(email);
    if (!user) {
      // Don't reveal if email exists
      return { message: 'Si el correo está registrado, se envió un nuevo código' };
    }

    if (user.emailVerified) {
      return { message: 'El correo ya está verificado' };
    }

    const code = this.generateSixDigitCode();
    const hashedCode = await bcrypt.hash(code, 10);
    const expiry = new Date(Date.now() + 10 * 60 * 1000);

    await this.usersService.updateVerification(user.id, {
      verificationCode: hashedCode,
      verificationCodeExpiry: expiry,
      verificationAttempts: 0,
    });

    await this.emailService.sendVerificationCode(user.email, code);

    return { message: 'Si el correo está registrado, se envió un nuevo código' };
  }

  async forgotPassword(email: string) {
    const genericMessage = {
      message:
        'Si el correo está registrado, se envió un código de restablecimiento',
    };

    const user = await this.usersService.findByEmail(email);
    if (!user) {
      return genericMessage;
    }

    const code = this.generateSixDigitCode();
    const hashedCode = await bcrypt.hash(code, 10);
    const expiry = new Date(Date.now() + 10 * 60 * 1000);

    await this.usersService.updateResetCode(user.id, {
      resetCode: hashedCode,
      resetCodeExpiry: expiry,
      resetAttempts: 0,
    });

    await this.emailService.sendPasswordResetCode(user.email, code);

    return genericMessage;
  }

  async verifyResetCode(email: string, code: string) {
    const user = await this.usersService.findByEmail(email);
    if (!user) {
      throw new BadRequestException('Código inválido o expirado');
    }

    if (!user.resetCode || !user.resetCodeExpiry) {
      throw new BadRequestException('Código inválido o expirado');
    }

    if (user.resetAttempts >= 5) {
      await this.usersService.updateResetCode(user.id, {
        resetCode: null,
        resetCodeExpiry: null,
        resetAttempts: 0,
      });
      throw new BadRequestException(
        'Demasiados intentos. Solicita un nuevo código.',
      );
    }

    if (new Date() > user.resetCodeExpiry) {
      throw new BadRequestException('Código inválido o expirado');
    }

    const isCodeValid = await bcrypt.compare(code, user.resetCode);
    if (!isCodeValid) {
      await this.usersService.updateResetCode(user.id, {
        resetAttempts: user.resetAttempts + 1,
      });
      throw new BadRequestException('Código inválido o expirado');
    }

    // Invalidate the code after successful verification
    await this.usersService.updateResetCode(user.id, {
      resetCode: null,
      resetCodeExpiry: null,
      resetAttempts: 0,
    });

    // Generate a short-lived reset token with a unique jti
    const jti = uuidv4();
    const resetToken = this.jwtService.sign(
      { sub: user.id, email: user.email, purpose: 'password-reset', jti },
      { expiresIn: '5m' },
    );

    // Store the jti on the user to ensure single-use
    await this.usersService.updateResetCode(user.id, {
      resetCode: jti,
      resetCodeExpiry: new Date(Date.now() + 5 * 60 * 1000),
    });

    return { resetToken };
  }

  async resetPassword(resetToken: string, newPassword: string) {
    let payload: any;
    try {
      payload = this.jwtService.verify(resetToken);
    } catch {
      throw new BadRequestException('Token inválido o expirado');
    }

    if (payload.purpose !== 'password-reset' || !payload.jti) {
      throw new BadRequestException('Token inválido o expirado');
    }

    const user = await this.usersService.findByEmail(payload.email);
    if (!user) {
      throw new BadRequestException('Token inválido o expirado');
    }

    // Verify the jti matches (single-use check)
    if (user.resetCode !== payload.jti) {
      throw new BadRequestException('Token inválido o expirado');
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await this.usersService.updatePassword(user.id, hashedPassword);

    // Invalidate the reset token
    await this.usersService.updateResetCode(user.id, {
      resetCode: null,
      resetCodeExpiry: null,
      resetAttempts: 0,
    });

    return { message: 'Contraseña restablecida exitosamente' };
  }

  private generateToken(userId: string, email: string): string {
    return this.jwtService.sign({ sub: userId, email });
  }

  private generateSixDigitCode(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }
}

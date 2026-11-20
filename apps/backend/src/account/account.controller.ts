import { Controller, Delete, HttpCode } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { type AuthUser, CurrentUser } from '../auth/auth-user.js';
import { Roles } from '../auth/roles.decorator.js';
import { AccountService } from './account.service.js';

@ApiTags('account')
@ApiBearerAuth()
@Controller()
export class AccountController {
  constructor(private readonly account: AccountService) {}

  @Roles('citizen', 'business')
  @HttpCode(204)
  @Delete('me')
  @ApiOperation({
    summary: 'Delete my account (citizen or business). Personal data is erased and login stops working; refused with 409 while a pickup is in progress or cash is owed',
  })
  async remove(@CurrentUser() user: AuthUser): Promise<void> {
    await this.account.deleteOwn(user.id);
  }
}

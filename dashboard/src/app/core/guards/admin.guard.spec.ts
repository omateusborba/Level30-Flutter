import { TestBed } from '@angular/core/testing';
import { Router, UrlTree } from '@angular/router';
import { adminGuard } from './admin.guard';
import { AuthService } from '../services/auth.service';

function run(): boolean | UrlTree {
  return TestBed.runInInjectionContext(() => adminGuard({} as never, {} as never)) as boolean | UrlTree;
}

describe('adminGuard', () => {
  let auth: { isAuthenticated: jasmine.Spy; isAdmin: jasmine.Spy };

  beforeEach(() => {
    auth = { isAuthenticated: jasmine.createSpy(), isAdmin: jasmine.createSpy() };
    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: auth },
        { provide: Router, useValue: { createUrlTree: (c: string[]) => ({ __tree: c[0] }) } },
      ],
    });
  });

  it('não autenticado → redireciona para /login', () => {
    auth.isAuthenticated.and.returnValue(false);
    expect(run()).toEqual({ __tree: '/login' } as never);
  });

  it('autenticado sem ADMIN → redireciona para /sem-acesso', () => {
    auth.isAuthenticated.and.returnValue(true);
    auth.isAdmin.and.returnValue(false);
    expect(run()).toEqual({ __tree: '/sem-acesso' } as never);
  });

  it('ADMIN → libera', () => {
    auth.isAuthenticated.and.returnValue(true);
    auth.isAdmin.and.returnValue(true);
    expect(run()).toBeTrue();
  });
});

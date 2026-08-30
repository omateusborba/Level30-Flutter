import { User } from './user.model';

export interface LoginRequest {
  email: string;
  password: string;
}

/** Resposta de POST /auth/login e POST /auth/signup (contract.md). */
export interface AuthResponse {
  token: string;
  refreshToken: string | null;
  user: User;
}

/** Formato de erro único da API (contract.md, todos os status >= 400). */
export interface ApiError {
  status: number;
  error: string;
  mensagem: string;
  detalhes: string[];
  timestamp: string;
}

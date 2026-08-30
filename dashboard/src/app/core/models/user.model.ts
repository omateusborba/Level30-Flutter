export type Role = 'USER' | 'ADMIN';

/** user retornado por /auth/login, /auth/signup e /me (contract.md). */
export interface User {
  id: string;
  name: string;
  email: string;
  totalXp: number;
  avatar: string | null;
  /** Adição aditiva (A5). Ausente em respostas antigas → tratar como 'USER'. */
  role?: Role;
}

/** Item de GET /admin/usuarios — Page<AdminUserResponse>. */
export interface AdminUser {
  id: string;
  nome: string;
  email: string;
  totalXp: number;
  nivel: number;
  rank: string;
  quantidadeDesafios: number;
}

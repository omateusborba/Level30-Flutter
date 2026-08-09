export interface Env {
  DB: D1Database;
  AI: Ai;
  JWT_SECRET: string;
}

export type ChallengeCategory =
  | 'health'
  | 'study'
  | 'productivity'
  | 'mindfulness'
  | 'fitness';

export const CHALLENGE_CATEGORIES: ChallengeCategory[] = [
  'health',
  'study',
  'productivity',
  'mindfulness',
  'fitness',
];

export interface UserRow {
  id: string;
  email: string;
  password_hash: string;
  password_salt: string;
  name: string;
  total_xp: number;
  avatar: string | null;
  created_at: string;
}

export interface ChallengeRow {
  id: string;
  user_id: string;
  title: string;
  category: string;
  description: string;
  total_days: number;
  current_day: number;
  xp_reward: number;
  streak: number;
  last_activity_at: string | null;
  created_at: string;
}

// Shape enviado ao Flutter — mesmo formato de Challenge.toJson() no Dart.
export interface ChallengeJson {
  id: string;
  title: string;
  category: string;
  description: string;
  totalDays: number;
  currentDay: number;
  xpReward: number;
  streak: number;
  lastActivityAt: string | null;
}

export function toChallengeJson(row: ChallengeRow): ChallengeJson {
  return {
    id: row.id,
    title: row.title,
    category: row.category,
    description: row.description,
    totalDays: row.total_days,
    currentDay: row.current_day,
    xpReward: row.xp_reward,
    streak: row.streak,
    lastActivityAt: row.last_activity_at,
  };
}

export function earnedXp(currentDay: number, totalDays: number, xpReward: number): number {
  if (totalDays <= 0) return 0;
  return Math.trunc((currentDay / totalDays) * xpReward);
}

import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Challenge, CreateChallengeRequest } from '../models';

/**
 * CRUD de desafios (contract.md: POST /challenges, DELETE /challenges/{id}).
 * HttpClient encapsulado no service — nunca no componente (checklist 3.3).
 */
@Injectable({ providedIn: 'root' })
export class ChallengeService {
  private readonly base = environment.apiBaseUrl;

  constructor(private http: HttpClient) {}

  create(payload: CreateChallengeRequest): Observable<Challenge> {
    return this.http.post<Challenge>(`${this.base}/challenges`, payload);
  }

  remove(id: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/challenges/${id}`);
  }
}

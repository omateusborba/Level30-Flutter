import { Component, Input } from '@angular/core';
import { NgFor, NgIf, NgStyle } from '@angular/common';
import { BarDatum } from './chart-types';

/** Barras horizontais rotuladas. Puro CSS/flex — nem SVG precisa. */
@Component({
  selector: 'app-bar-chart',
  standalone: true,
  imports: [NgFor, NgIf, NgStyle],
  template: `
    <div class="bc" *ngIf="data.length > 0; else vazio">
      <div class="bc-row" *ngFor="let d of data">
        <span class="bc-label" [title]="d.label">{{ d.label }}</span>
        <span class="bc-track">
          <span
            class="bc-fill"
            [ngStyle]="{
              width: pct(d.value) + '%',
              background: d.color || 'var(--accent)'
            }"
          ></span>
        </span>
        <span class="bc-value">{{ d.value }}</span>
      </div>
    </div>
    <ng-template #vazio><p class="bc-empty">Sem dados.</p></ng-template>
  `,
  styles: [`
    .bc { display: flex; flex-direction: column; gap: 8px; }
    .bc-row { display: flex; align-items: center; gap: 10px; }
    .bc-label {
      width: 120px; flex-shrink: 0; color: var(--text-dim); font-size: 12px;
      white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
    }
    .bc-track { flex: 1; height: 14px; background: var(--surface-2); border-radius: 6px; overflow: hidden; }
    .bc-fill { display: block; height: 100%; border-radius: 6px; transition: width .3s; min-width: 2px; }
    .bc-value { width: 40px; text-align: right; font-weight: 600; font-size: 13px; }
    .bc-empty { color: var(--text-dim); text-align: center; padding: 20px; }
  `],
})
export class BarChartComponent {
  @Input() data: BarDatum[] = [];

  pct(v: number): number {
    const max = Math.max(...this.data.map((d) => d.value), 1);
    return Math.round((v / max) * 100);
  }
}

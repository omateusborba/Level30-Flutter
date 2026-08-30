import { Component, Input } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { SliceDatum } from './chart-types';

/** Rosca de distribuição proporcional, com legenda. */
@Component({
  selector: 'app-donut-chart',
  standalone: true,
  imports: [NgFor, NgIf],
  template: `
    <div class="dc" *ngIf="total > 0; else vazio">
      <svg viewBox="0 0 42 42" class="dc-svg" role="img">
        <circle class="dc-hole" cx="21" cy="21" r="15.915" fill="transparent"></circle>
        <circle
          *ngFor="let s of segments"
          cx="21" cy="21" r="15.915" fill="transparent"
          [attr.stroke]="s.color"
          stroke-width="6"
          [attr.stroke-dasharray]="s.dash"
          [attr.stroke-dashoffset]="s.offset"
        ></circle>
        <text x="21" y="21" class="dc-center">{{ total }}</text>
      </svg>
      <ul class="dc-legend">
        <li *ngFor="let s of segments">
          <span class="dc-dot" [style.background]="s.color"></span>
          {{ s.label }} <strong>{{ s.value }}</strong>
          <span class="dc-pct">{{ s.pct }}%</span>
        </li>
      </ul>
    </div>
    <ng-template #vazio><p class="dc-empty">Sem dados.</p></ng-template>
  `,
  styles: [`
    .dc { display: flex; align-items: center; gap: 20px; flex-wrap: wrap; }
    .dc-svg { width: 140px; height: 140px; transform: rotate(-90deg); flex-shrink: 0; }
    .dc-hole { stroke: var(--surface-2); stroke-width: 6; }
    .dc-center { transform: rotate(90deg); transform-origin: 21px 21px; text-anchor: middle;
      dominant-baseline: central; font-size: 8px; font-weight: 700; fill: var(--text); }
    .dc-legend { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 6px; }
    .dc-legend li { display: flex; align-items: center; gap: 8px; font-size: 13px; }
    .dc-dot { width: 10px; height: 10px; border-radius: 3px; }
    .dc-pct { color: var(--text-dim); margin-left: 4px; }
    .dc-empty { color: var(--text-dim); text-align: center; padding: 20px; }
  `],
})
export class DonutChartComponent {
  @Input() data: SliceDatum[] = [];

  get total(): number {
    return this.data.reduce((s, d) => s + d.value, 0);
  }

  get segments(): (SliceDatum & { dash: string; offset: number; pct: number })[] {
    const total = this.total || 1;
    let acc = 0;
    return this.data
      .filter((d) => d.value > 0)
      .map((d) => {
        const frac = (d.value / total) * 100;
        const seg = { ...d, dash: `${frac} ${100 - frac}`, offset: 100 - acc, pct: Math.round(frac) };
        acc += frac;
        return seg;
      });
  }
}

import { Component, Input } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { HeatRow } from './chart-types';

/** Grade de intensidade — coorte de retenção, atividade por dia, etc. */
@Component({
  selector: 'app-heatmap',
  standalone: true,
  imports: [NgFor, NgIf],
  template: `
    <div class="hm" *ngIf="rows.length > 0; else vazio">
      <div class="hm-colhead" *ngIf="colLabels.length > 0">
        <span class="hm-rowlabel"></span>
        <span *ngFor="let c of colLabels">{{ c }}</span>
      </div>
      <div class="hm-row" *ngFor="let r of rows">
        <span class="hm-rowlabel" [title]="r.label">{{ r.label }}</span>
        <span
          *ngFor="let cell of r.cells"
          class="hm-cell"
          [class.hm-null]="cell === null"
          [style.background]="cell === null ? 'transparent' : color(cell)"
          [title]="cell === null ? '—' : cell + (unit ? unit : '')"
        >{{ cell === null ? '' : (showValues ? cell : '') }}</span>
      </div>
    </div>
    <ng-template #vazio><p class="hm-empty">Sem dados.</p></ng-template>
  `,
  styles: [`
    .hm { display: flex; flex-direction: column; gap: 4px; overflow-x: auto; }
    .hm-colhead, .hm-row { display: flex; gap: 4px; align-items: center; }
    .hm-colhead { color: var(--text-dim); font-size: 11px; }
    .hm-colhead span:not(.hm-rowlabel) { width: 34px; text-align: center; flex-shrink: 0; }
    .hm-rowlabel { width: 90px; flex-shrink: 0; color: var(--text-dim); font-size: 12px;
      white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .hm-cell { width: 34px; height: 28px; flex-shrink: 0; border-radius: 5px; display: grid;
      place-items: center; font-size: 11px; font-weight: 600; color: var(--accent-ink); }
    .hm-null { border: 1px dashed var(--border); }
    .hm-empty { color: var(--text-dim); text-align: center; padding: 20px; }
  `],
})
export class HeatmapComponent {
  @Input() rows: HeatRow[] = [];
  @Input() colLabels: string[] = [];
  @Input() max = 100;
  @Input() showValues = true;
  @Input() unit = '';

  color(v: number): string {
    const t = Math.max(0, Math.min(1, v / (this.max || 1)));
    // interpola surface-2 → accent
    const alpha = 0.12 + t * 0.88;
    return `color-mix(in srgb, var(--accent) ${Math.round(alpha * 100)}%, var(--surface-2))`;
  }
}

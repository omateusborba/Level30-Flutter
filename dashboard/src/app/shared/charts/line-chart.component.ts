import { Component, Input } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { LineSeries } from './chart-types';

/**
 * Série(s) temporal(is) em SVG. `stacked` empilha as áreas (distribuição no tempo);
 * caso contrário desenha linhas sobrepostas.
 */
@Component({
  selector: 'app-line-chart',
  standalone: true,
  imports: [NgFor, NgIf],
  template: `
    <svg
      *ngIf="series.length > 0 && width > 0"
      [attr.viewBox]="'0 0 ' + W + ' ' + H"
      preserveAspectRatio="none"
      class="lc"
      role="img"
    >
      <line *ngFor="let g of gridY" [attr.x1]="pad" [attr.x2]="W - padR"
            [attr.y1]="g" [attr.y2]="g" class="lc-grid" />

      <ng-container *ngIf="stacked">
        <path *ngFor="let a of stackedAreas" [attr.d]="a.d" [attr.fill]="a.color" fill-opacity="0.75" />
      </ng-container>

      <ng-container *ngIf="!stacked">
        <path *ngFor="let s of paths" [attr.d]="s.area" [attr.fill]="s.color" fill-opacity="0.12" />
        <path *ngFor="let s of paths" [attr.d]="s.line" [attr.stroke]="s.color"
              fill="none" stroke-width="2" vector-effect="non-scaling-stroke" />
      </ng-container>
    </svg>

    <div class="lc-legend" *ngIf="series.length > 1">
      <span *ngFor="let s of series" class="lc-key">
        <span class="lc-dot" [style.background]="s.color"></span>{{ s.name }}
      </span>
    </div>
    <div class="lc-axis" *ngIf="labels.length > 0">
      <span>{{ labels[0] }}</span><span>{{ labels[labels.length - 1] }}</span>
    </div>
  `,
  styles: [`
    .lc { width: 100%; height: 180px; display: block; }
    .lc-grid { stroke: var(--border); stroke-width: 1; vector-effect: non-scaling-stroke; }
    .lc-legend { display: flex; gap: 14px; flex-wrap: wrap; margin-top: 8px; }
    .lc-key { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--text-dim); }
    .lc-dot { width: 10px; height: 10px; border-radius: 3px; display: inline-block; }
    .lc-axis { display: flex; justify-content: space-between; font-size: 11px; color: var(--text-dim); margin-top: 2px; }
  `],
})
export class LineChartComponent {
  @Input() series: LineSeries[] = [];
  @Input() labels: string[] = [];
  @Input() stacked = false;

  readonly W = 600;
  readonly H = 180;
  readonly pad = 4;
  readonly padR = 4;

  get width(): number {
    return this.series[0]?.values.length ?? 0;
  }

  get gridY(): number[] {
    return [0, 0.25, 0.5, 0.75, 1].map((f) => this.pad + f * (this.H - 2 * this.pad));
  }

  private x(i: number, n: number): number {
    if (n <= 1) return this.pad;
    return this.pad + (i / (n - 1)) * (this.W - this.pad - this.padR);
  }

  private y(v: number, max: number): number {
    const h = this.H - 2 * this.pad;
    return this.pad + h - (max === 0 ? 0 : (v / max) * h);
  }

  get paths(): { line: string; area: string; color: string }[] {
    const n = this.width;
    const max = Math.max(1, ...this.series.flatMap((s) => s.values));
    return this.series.map((s) => {
      const pts = s.values.map((v, i) => `${this.x(i, n)},${this.y(v, max)}`);
      const line = 'M' + pts.join(' L');
      const area = `${line} L${this.x(n - 1, n)},${this.y(0, max)} L${this.x(0, n)},${this.y(0, max)} Z`;
      return { line, area, color: s.color };
    });
  }

  get stackedAreas(): { d: string; color: string }[] {
    const n = this.width;
    const totals = Array.from({ length: n }, (_, i) =>
      this.series.reduce((sum, s) => sum + (s.values[i] ?? 0), 0),
    );
    const max = Math.max(1, ...totals);
    const running = new Array(n).fill(0);
    return this.series.map((s) => {
      const lower = running.slice();
      s.values.forEach((v, i) => (running[i] += v ?? 0));
      const top = running.map((v, i) => `${this.x(i, n)},${this.y(v, max)}`);
      const bottom = lower.map((v, i) => `${this.x(i, n)},${this.y(v, max)}`).reverse();
      return { d: `M${top.join(' L')} L${bottom.join(' L')} Z`, color: s.color };
    });
  }
}

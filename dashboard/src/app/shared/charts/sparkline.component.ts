import { Component, Input } from '@angular/core';
import { NgIf } from '@angular/common';

/** Microtendência para dentro de um KPI card. */
@Component({
  selector: 'app-sparkline',
  standalone: true,
  imports: [NgIf],
  template: `
    <svg *ngIf="values.length > 1" viewBox="0 0 100 28" preserveAspectRatio="none" class="sl">
      <path [attr.d]="area" [attr.fill]="color" fill-opacity="0.15" />
      <path [attr.d]="line" [attr.stroke]="color" fill="none" stroke-width="1.5"
            vector-effect="non-scaling-stroke" />
    </svg>
  `,
  styles: [`.sl { width: 100%; height: 28px; display: block; }`],
})
export class SparklineComponent {
  @Input() values: number[] = [];
  @Input() color = 'var(--accent)';

  private get pts(): string[] {
    const n = this.values.length;
    const max = Math.max(...this.values, 1);
    const min = Math.min(...this.values, 0);
    const span = max - min || 1;
    return this.values.map((v, i) => {
      const x = (i / (n - 1)) * 100;
      const y = 26 - ((v - min) / span) * 24;
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    });
  }

  get line(): string {
    return 'M' + this.pts.join(' L');
  }

  get area(): string {
    return `${this.line} L100,28 L0,28 Z`;
  }
}

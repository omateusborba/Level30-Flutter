import { Component, Input } from '@angular/core';

export type IconName = 'users' | 'grid' | 'check' | 'warn' | 'bolt' | 'fire';

/**
 * Ícones como SVG inline, sem `[innerHTML]` nem `bypassSecurityTrust*`.
 * Conjunto fechado — o `name` é validado em tempo de compilação.
 */
const PATHS: Record<IconName, string> = {
  users: 'M16 14a4 4 0 1 0-8 0M12 10a3 3 0 1 0 0-6 3 3 0 0 0 0 6',
  grid: 'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z',
  check: 'M20 6 9 17l-5-5',
  warn: 'M12 3 2 20h20zM12 10v4M12 17h.01',
  bolt: 'M13 2 3 14h7l-1 8 10-12h-7z',
  fire: 'M12 3c1 3-2 5-2 8a4 4 0 0 0 8 0c0-2-1-3-2-4 0 2-1 3-2 3 1-4-1-7 0-10z',
};

@Component({
  selector: 'app-icon',
  standalone: true,
  template: `
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      <path [attr.d]="path"></path>
    </svg>
  `,
  styles: [':host{display:inline-flex;line-height:0}svg{width:100%;height:100%}'],
})
export class IconComponent {
  @Input({ required: true }) name!: IconName;

  get path(): string {
    return PATHS[this.name];
  }
}

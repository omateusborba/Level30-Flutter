/** Tipos compartilhados dos componentes de gráfico SVG (sem lib externa). */

export interface BarDatum {
  label: string;
  value: number;
  color?: string;
}

export interface SliceDatum {
  label: string;
  value: number;
  color: string;
}

export interface LineSeries {
  name: string;
  color: string;
  values: number[];
}

export interface HeatRow {
  label: string;
  cells: (number | null)[];
}

import { Pipe, PipeTransform } from '@angular/core';

const CATEGORIA: Record<string, string> = {
  health: 'Saúde',
  study: 'Estudos',
  productivity: 'Produtividade',
  mindfulness: 'Mindfulness',
  fitness: 'Fitness',
};

const RISCO: Record<string, string> = {
  low: 'Baixo',
  medium: 'Médio',
  high: 'Alto',
  critical: 'Crítico',
};

/**
 * Traduz o valor cru da API (minúsculas, inglês) para exibição. NÃO altera o
 * contrato — o valor enviado à API continua o original.
 */
@Pipe({ name: 'categoriaLabel', standalone: true })
export class CategoriaLabelPipe implements PipeTransform {
  transform(value: string | null | undefined): string {
    if (!value) return '—';
    return CATEGORIA[value.toLowerCase()] ?? value;
  }
}

@Pipe({ name: 'riscoLabel', standalone: true })
export class RiscoLabelPipe implements PipeTransform {
  transform(value: string | null | undefined): string {
    if (!value) return '—';
    return RISCO[value.toLowerCase()] ?? value;
  }
}

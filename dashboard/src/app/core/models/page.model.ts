/** Envelope de paginação padrão do Spring Data (contract.md). */
export interface Page<T> {
  content: T[];
  totalElements: number;
  totalPages: number;
  number: number;
  size: number;
}

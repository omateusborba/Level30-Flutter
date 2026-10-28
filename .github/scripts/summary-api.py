#!/usr/bin/env python3
"""Resumo do job `api` para $GITHUB_STEP_SUMMARY: testes (Surefire) e cobertura (JaCoCo)."""
import csv
import glob
import xml.etree.ElementTree as ET

total = falhas = erros = pulados = 0
for caminho in glob.glob("backend/target/surefire-reports/TEST-*.xml"):
    suite = ET.parse(caminho).getroot()
    total += int(suite.get("tests", 0))
    falhas += int(suite.get("failures", 0))
    erros += int(suite.get("errors", 0))
    pulados += int(suite.get("skipped", 0))

perdidas = cobertas = 0
try:
    with open("backend/target/site/jacoco/jacoco.csv", newline="", encoding="utf-8") as f:
        for linha in csv.DictReader(f):
            perdidas += int(linha["INSTRUCTION_MISSED"])
            cobertas += int(linha["INSTRUCTION_COVERED"])
except FileNotFoundError:
    pass
cobertura = f"{cobertas / (cobertas + perdidas) * 100:.1f}%" if cobertas + perdidas else "n/d"

print("### API — testes e cobertura")
print()
print("| Total | Falhas | Erros | Ignorados | Cobertura (instruções) |")
print("|---:|---:|---:|---:|---:|")
print(f"| {total} | {falhas} | {erros} | {pulados} | {cobertura} |")

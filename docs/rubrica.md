# Rubrica de correção

Total: **100 pontos** + até **10** de bônus. Aprovação sugerida: **≥ 70** com **nenhum item
crítico reprovado** (ver "Reprovação automática").

## Distribuição

### 1. Docker / imagens — 20 pts
| Critério | Pts |
|----------|-----|
| Dockerfile da API em multi-stage, build estático | 6 |
| Imagem final mínima (`scratch`/`distroless`) e tamanho documentado | 8 |
| Dockerfile do front (nginx servindo estático + proxy `/api`) | 6 |

### 2. Kubernetes / Helm — 35 pts
| Critério | Pts |
|----------|-----|
| Tudo empacotado num **Helm chart** (values parametrizáveis; não YAML solto) | 8 |
| Postgres como **StatefulSet + PVC** (não Deployment efêmero) | 8 |
| **Secret** para a credencial do banco (nada hardcoded) + ConfigMap onde couber | 7 |
| **liveness/readiness** corretas (liveness ≠ readiness) | 7 |
| **requests/limits** de CPU e memória em todos os workloads | 5 |

### 3. Terraform (maestro) — 35 pts
| Critério | Pts |
|----------|-----|
| `apply` do zero cria cluster + namespace + deploy do chart e a app responde | 12 |
| **Idempotência**: `apply` 2x → `0 changed`/nenhuma recriação à toa | 12 |
| `destroy` remove tudo | 6 |
| Uso adequado dos providers `kind`/`helm`/`kubernetes` e organização do código | 5 |

### 4. Fricções resolvidas — 10 pts
| Critério | Pts |
|----------|-----|
| Migração roda no cluster antes de a API ficar `Ready` (Job/hook) | 4 |
| Probes escolhidas corretamente (sem CrashLoop por liveness no `/readyz`) | 3 |
| Segredo em Secret | 3 |

### Bônus — até 10 pts
| Critério | Pts |
|----------|-----|
| HPA na API + prova de escala sob carga (k6/hey) | 7 |
| Automação (Makefile/script) e README de decisões | 3 |

## Reprovação automática (independe da nota)
- `terraform apply` **não sobe** a aplicação num ambiente limpo.
- `apply` repetido **recria/derruba** recursos (não é idempotente).
- Credencial do banco **hardcoded** em manifest versionado.
- Entregou **YAML solto** em vez de Helm chart (requisito explícito).

## Como corrigir (roteiro rápido)
1. `cd infra/terraform && terraform init && terraform apply` num ambiente limpo → app no ar?
2. `terraform apply` de novo → confere `0 added, 0 changed, 0 destroyed`.
3. `kubectl get pods,statefulset,ingress,secret` → StatefulSet? Secret? probes/limits no manifest?
4. Inspecione os `Dockerfile` (multi-stage? imagem mínima?) e o chart (values, hooks).
5. `terraform destroy` → limpou?

# Prior art — o que já existe (pesquisa 2026-11-23)

Levantamento de dois ecossistemas que hoje não se conversam: **kits de spec-driven
development (SDD)** genéricos e **coleções de skills de Godot** para agentes.

---

## 1. Kits de spec-driven development

### 1.1 GitHub Spec Kit — o padrão de fato

CLI Python `specify`, MIT, agent-agnostic (30+ agentes, incluindo Claude Code).
O fluxo canônico:

| Comando | Produz |
|---|---|
| `/speckit-constitution` | Princípios do projeto (qualidade, testes, manutenibilidade) → `memory/constitution.md` |
| `/speckit-specify` | **O quê e por quê** → `specs/<feature>/spec.md` |
| `/speckit-clarify` | Resolve marcadores `[NEEDS CLARIFICATION]` |
| `/speckit-plan` | Abordagem técnica e arquitetura → `plan.md` |
| `/speckit-tasks` | Itens de trabalho pequenos e testáveis → `tasks.md` |
| `/speckit-analyze` | Consistência cruzada entre spec/plan/tasks |
| `/speckit-checklist` | Checklists de qualidade |
| `/speckit-implement` | Código |
| `/speckit-converge` | **Gap analysis** spec↔código; repete até reportar `Converged` |

Artefatos vivem em `.specify/` (inclui `.specify/bugs/`, `.specify/assessments/`,
`.specify/extensions.yml`).

**Convenções que valem copiar:**
- Requisitos funcionais com ID estável: `FR-001`, `FR-002`.
- User stories priorizadas `P1/P2/P3`, cada uma **independentemente testável e entregável**.
- Critérios de aceitação em **Given/When/Then**.
- Marcador explícito `[NEEDS CLARIFICATION]` para lacunas — força o clarify antes do plan.
- Success criteria **mensuráveis**, separados dos requisitos.
- Seções de Edge cases, Key entities e Assumptions.

**O detalhe mais interessante é o `converge`:** ele lê spec+plan+tasks+constitution,
monta um *intent inventory* (requisito → escopo de código), classifica cada gap como
`missing | partial | contradicts | unrequested`, atribui severidade CRITICAL/HIGH/MEDIUM/LOW,
mostra a tabela **antes** de escrever, e só então acrescenta uma `## Phase N: Convergence`
ao `tasks.md`. Nunca edita spec, plan nem código. "Converged" = nenhum gap restante.

> Esse loop é exatamente o que falta nos kits de Godot: eles verificam *código*,
> não verificam *aderência à especificação*.

### 1.2 Agent OS

Quatro fases: **Discover Standards** (extrai padrões do código existente) → **Deploy
Standards** (injeta só o que é relevante ao trabalho atual) → **Shape Spec** → **Index
Standards**. Diretórios `standards/`, `product/`, `specs/`.

**Ideia a roubar:** o padrão não é decretado de cima, é *descoberto* do código que já
existe e reinjetado contextualmente. Para Godot isso é ouro — cada projeto já tem um
jeito de organizar autoloads, nomear sinais e montar pastas de cena.

### 1.3 BMAD-METHOD

Multi-agente com personas (Analyst, PM, Architect, Scrum Master, Dev, QA). O mecanismo
central é o **sharding**: PRD + Architecture grandes são quebrados em *story files*
auto-contidos, cada um carregando exatamente o contexto que o agente Dev precisa.

**Ideia a roubar:** o problema real não é escrever a spec, é **entregá-la ao agente em
pedaços que cabem na janela de contexto** sem perder rastreabilidade.

---

## 2. Coleções de skills para Godot

### 2.1 `Richy-was-here/gg-godot` — o mais próximo de um kit SDD para Godot

Sete papéis de agente: Manager, Producer, Planner, Researcher, Developer, Reviewer, QA.

Estrutura de artefatos em `.gamedev/`:

```
.gamedev/
├── config.md        # caminho do binário Godot, settings
├── vision.md        # visão do projeto, contradições resolvidas
├── roadmap.md       # milestones, phases, critérios done_when
├── decisions.md     # decisões com escopo e rationale
├── contracts.md     # especificação de subsistemas
├── qa-results.md
└── checks.md        # itens que só o humano julga
.gdignore            # esconde .gamedev do editor Godot
```

Mecanismos originais:
- **IDs de decisão com escopo embutido:** `P-D-01` (projeto), `M2-D-01` (milestone 2),
  `M2-P3-D-01` (milestone 2, fase 3).
- **Critérios de done divididos em duas colunas:** *o que um agente consegue checar*
  vs. *o que só você consegue julgar*. Honestidade sobre o limite da verificação automática.
- **File check-out:** planos declaram o conjunto de arquivos que vão tocar. Planos com
  conjuntos disjuntos rodam em paralelo; `project.godot` e autoloads ficam sempre sequenciais.
- **Dez gates de verificação** em `/gg:verify`: projeto carrega headless; todos os scripts
  parseiam; nenhum stub; QA passa; cada decisão rastreável no diff; índice de arquivos
  consistente; sem arquivos de teste esquecidos; critérios de fase atendidos; sem código
  morto/prints de debug; documentos dentro do template e do limite de tamanho.
- **Blind QA:** o agente QA testa o subsistema contra o contrato escrito pelo Planner,
  via scripts headless descartáveis, **sem acesso ao código nem à documentação**.
- `/gg:autonomous` roda até achar uma decisão ou um bloqueio; `/gg:review` processa os
  vereditos humanos depois.

### 2.2 `Qb-Lab/godot-agent-skills` — a camada de *enforcement*

22 skills, mas o valor está nos **4 hooks**:

| Hook | Evento | Função |
|---|---|---|
| `godot-context.sh` | `UserPromptSubmit` | Injeta versão da engine + regras permanentes em todo prompt |
| `guard-scene-files.py` | `PreToolUse` | **Bloqueia** edições estruturais em `.tscn`/`.tres`; libera scalars e `[connection]` |
| `require-verify.sh` | `Stop` | Impede encerrar o turno com `.gd`/`.tscn`/`.tres` alterados e nada verificado |
| `verify-baseline.sh` | `SessionStart` | Marca o baseline de verificação |

O guard bloqueia exatamente: `uid://`, `load_steps`, ids de `ext_resource`/`sub_resource`,
e estrutura de blocos de nó. Skills notáveis: `godot-scene-surgery`, `godot4-api-guard`
(tabelas de tradução 3→4 + drift entre versões menores, detectando a versão via
`config/features` do `project.godot`), `godot-verify`.

### 2.3 `iboss-ptk/godot-claude-plugin` — precisão sobre autonomia

Três princípios declarados: precisão > autonomia; verificação determinística que não pode
ser pulada; gating humano para mudanças controversas.

- **Build scripts são a fonte da verdade das cenas:** `build_<name>.gd` gera o `.tscn`.
  O `.tscn` nunca é editado à mão. (Alternativa radical ao "scene surgery".)
- Tipagem explícita obrigatória em todo `var`, parâmetro, retorno e coleção (`Array[Card]`),
  incluindo `@onready` e `@export`.
- `%UniqueName` obrigatório; lookup por path banido.
- Hook `PostToolUse` roda `gdlint` + `godot --headless --check-only` após todo write de `.gd`.
  Três falhas seguidas do hook → revisão manual.
- Agente `gdscript-verifier` read-only audita tipagem antes do código chegar ao usuário.
- 1.034 docs de classe da API Godot 4 carregados sob demanda.

### 2.4 Bibliotecas grandes — `bgrenat/godot-game-dev-studio` e `thedivergentai/Game-Dev-Agentic-Skills`

- **bgrenat:** 188 skills em 4 famílias (`godot-*` 95, `godot-prompter-*` 54, `gamedev-*` 27,
  `studio-*` 12). Os 12 `studio-*` são orquestradores por papel (director, producer,
  technical-director, gameplay-lead, systems-designer, level-design-lead, narrative,
  ui-ux, addon-integrator, qa-playtest, performance-release) com um `studio-router` na
  entrada. Regra declarada: *"route first, load only relevant SKILL.md, do not load the
  entire library into one task."*
- **thedivergentai:** 100 skills Godot + 83 Bevy, `skills_index.json` machine-readable,
  982 scripts GDScript prontos. Regra **"Power of One"**: instale *ou* o master *ou* as
  skills de domínio, **nunca os dois** — senão ocorre **"Context Storm"**, inundação de
  metadados que degrada o agente.

> Lição direta: a metadata (`name` + `description`) de **toda** skill instalada entra no
> system prompt no startup. 188 skills = 188 descrições competindo por atenção. Um kit
> de processo precisa ser **pequeno** e roteado, não enciclopédico.

### 2.5 Outros

`alexmeckes/godot-claude-skills` (5 skills, foco em MCP + AI Bridge para loop
inspect/edit/run/debug), `godomaster`, `hermeticormus/godot-development`.

MCP servers para Godot são vários e nenhum é canônico: `slangwald/godot-mcp` (stdio↔TCP),
`mkdevkit/godot-mcp`, `voidrot/godot-mcp` (addon de editor 4.7, expõe o editor aberto),
`raising-heart/godot-mcp` (overview de projeto/cena, check de erros, rodar o jogo,
screenshots). Argumento a favor deles: ferramentas que rodam **dentro** do editor leem o
índice de UIDs real e mantêm sidecars junto dos arquivos em qualquer operação — vantagem
estrutural sobre editar `.tscn` como texto.

---

## 3. Análise de lacunas — por que um kit novo se justifica

1. **Os kits SDD são CRUD-shaped.** O template de spec do Spec Kit assume user stories e
   requisitos funcionais verificáveis por teste automatizado. A unidade de trabalho de um
   jogo não é "user story", é **sistema/mecânica**: máquina de estados + constantes de
   tuning + feedback sensorial. Boa parte disso não é determinísticamente testável.

2. **Os kits de Godot são bibliotecas de conhecimento, não processos.** Ensinam a escrever
   GDScript; não definem o que é uma especificação aceita, nem o que significa "pronto".
   A exceção é o gg-godot — e ele não tem o loop de convergência spec↔código.

3. **Ninguém tem uma escada de verificação honesta.** Os kits ou prometem verificação
   total (e mentem sobre game feel) ou só rodam lint. Falta: cada critério de aceitação
   declarar **em qual degrau** ele é verificado — parse, unit, integração headless, bot
   com seed determinístico, evidência visual, ou julgamento humano.

4. **Ninguém trata dados de tuning como artefato de spec.** `Resource`/`.tres` é o lugar
   nativo do Godot para números de balanceamento. Uma spec deveria declarar a *superfície
   de tuning* (nome, tipo, faixa, default, dono) para que o agente escreva `@export` num
   Resource em vez de magic numbers espalhados no código.

5. **Ninguém especifica o contrato de cena.** O problema de `.tscn` é tratado como risco de
   edição (guard/hook), nunca como item de projeto. Se a spec declarasse a forma da árvore
   de nós, os sinais emitidos/consumidos, grupos e collision layers, a geração do `.tscn`
   viraria determinística e o diff viraria revisável.

# godot-4 — especificação do kit spec-driven para Godot 4 no Claude Code

**Status:** implementado em `.claude/` · **Engine alvo:** Godot 4.7.x

Este documento é a especificação. O framework que ela descreve está construído em
[`.claude/`](../../.claude): 15 skills, 14 comandos, 7 agentes, 5 hooks, 7 scripts e
6 templates.

Baseado em [prior-art.md](../research/prior-art.md) e [godot-constraints.md](../research/godot-constraints.md).

---

## 1. Tese

Os kits de spec-driven development existentes são *CRUD-shaped*: a unidade de spec é a
user story, e o critério de pronto é um teste automatizado verde. Jogos não cabem nisso —
a unidade é o **sistema/mecânica** (máquina de estados + constantes de tuning + feedback
sensorial), e uma parte grande do "pronto" é julgamento humano que nenhum agente verifica.

As coleções de skills de Godot, por sua vez, são **bibliotecas de conhecimento**: ensinam
GDScript, não definem processo. E as maiores (100–188 skills) causam *context storm*.

Este kit é a junção que falta, com três ideias que nenhum dos dois lados tem:

1. **Escada de verificação explícita (V0–V5).** Todo critério de aceitação declara *em que
   degrau* é verificado. O agente nunca diz "pronto" sobre algo que ele não pode checar —
   ele diz "V1–V3 verdes, V5 aguardando você".
2. **Superfície de tuning como artefato de primeira classe.** A spec declara os números
   ajustáveis (nome, tipo, faixa, default, dono) e eles viram `@export` num `Resource`
   `.tres` — nunca magic numbers no código. Ajustar o jogo deixa de ser tarefa de agente.
3. **Contrato de cena como item de projeto.** A spec declara a forma da árvore de nós, os
   sinais emitidos/consumidos, grupos e collision layers **antes** de o `.tscn` existir.
   A geração vira determinística e o diff vira revisável — o problema de `.tscn` deixa de
   ser só um risco a ser bloqueado por hook.

---

## 2. Princípios de desenho

| # | Princípio | Consequência prática |
|---|---|---|
| P1 | **Pequeno e roteado, não enciclopédico** | Teto rígido de 15 skills. Uma skill-router na entrada. Rejeitamos o modelo de 100+ skills (*Power of One* / context storm) |
| P2 | **Honestidade sobre verificação** | Nenhum gate mente. Critério não-automatizável é marcado como humano e entra numa fila de julgamento, não é silenciosamente aprovado |
| P3 | **Determinismo onde dá, guard onde não dá** | Scripts com saída estável (`verify.sh`) em vez de o agente inventar o comando. Hooks que bloqueiam o que o agente erra de forma recorrente |
| P4 | **A spec é o contrato; o código converge para ela** | Loop de convergência spec↔código, não o inverso. O código nunca é a fonte da verdade do design |
| P5 | **Descobrir antes de decretar** | `init` lê o projeto existente e propõe a constituição a partir dele (Agent OS), em vez de impor um estilo |
| P6 | **O humano decide design, o agente executa mecânica** | Decisões de design viram itens com ID e ficam registradas; o agente para e pergunta em vez de escolher |
| P7 | **Orçamento de contexto é recurso escasso** | Spec de sistema cabe numa janela; referências a um nível de profundidade; o que é grande vira `references/` carregado sob demanda |
| P8 | **Funciona sem MCP** | MCP de Godot é opcional e melhora o loop; o caminho base é CLI headless, que roda em qualquer máquina e no CI |
| P9 | **Scale-free, não configurável por perfil** | Um único processo serve game jam e projeto de 3 anos, 2D e 3D, qualquer gênero. O que escala não é a *configuração* do kit, é a *quantidade* de sistemas. Sem modo lite, sem modo enterprise, sem blueprint de gênero |

---

## 3. Escopo

**Dentro:** processo de especificação e verificação; convenções GDScript/arquitetura;
cirurgia e geração de cenas; dados de tuning; execução headless, testes e playtest por bot;
rastreabilidade spec↔código; trabalho paralelo/worktrees.

O kit é **agnóstico a dimensão, gênero e tamanho**: 2D e 3D, jam de 48h e produção longa.
Isso é possível porque a unidade de trabalho — o sistema — tem o mesmo tamanho em qualquer
projeto. Um jogo grande não tem specs maiores, tem **mais** specs. Ver P9 e §19.

**Fora (não-objetivos declarados):**
- Enciclopédia de API do Godot (já existe; e custa contexto).
- Geração de assets (arte, áudio, música).
- Blueprints de gênero prontos ("faça um roguelike").
- Substituir o editor Godot. O editor continua sendo onde cena complexa se monta.
- Ser um MCP server.

---

## 4. Modelo de artefatos

Tudo em `.godotspec/` na raiz do projeto, com um `.gdignore` dentro para o editor Godot
ignorar a pasta (truque do gg-godot — sem isso o Godot tenta importar os `.md`).

```
.godotspec/
├── .gdignore
├── config.yml              # binário do Godot, versão detectada, paths, framework de teste
├── constitution.md         # regras invioláveis do projeto (engine, tipagem, arquitetura)
├── vision.md               # o jogo: pilares, fantasia do jogador, não-objetivos
├── roadmap.md              # milestones → fatias verticais, com done_when
├── decisions.md            # log de decisões com ID escopado
├── glossary.md             # termos do domínio do jogo (evita sinônimos no código)
├── systems/
│   └── <NNN>-<slug>/
│       ├── spec.md         # O QUÊ: comportamento, critérios, superfície de tuning
│       ├── plan.md         # COMO: contratos de cena, arquivos tocados, riscos
│       ├── tasks.md        # passos executáveis + file check-out set
│       ├── contract.md     # contrato público para Blind QA (sem detalhe de implementação)
│       └── evidence/       # saídas de verificação: logs, junit.xml, screenshots, vídeos
├── checks.md               # fila de julgamento humano (o que só você decide)
└── handoff.md              # snapshot de sessão para retomada
```

**Convenções de ID** (herdadas do Spec Kit + gg-godot, unificadas):

| Prefixo | Significado | Exemplo |
|---|---|---|
| `SYS-<nnn>` | Sistema | `SYS-004` (Dash) |
| `BEH-<nnn>` | Comportamento especificado | `BEH-012` |
| `AC-<nnn>` | Critério de aceitação | `AC-031` |
| `TUN-<nome>` | Parâmetro de tuning | `TUN-dash_speed` |
| `SIG-<nome>` | Sinal do contrato | `SIG-dash_started` |
| `D-<escopo>-<nn>` | Decisão | `D-SYS004-02`, `D-M2-01`, `D-P-07` |
| `[NEEDS CLARIFICATION: ...]` | Lacuna bloqueante | — |
| `[DESIGN DECISION: ...]` | Escolha que é do humano, não do agente | — |

---

## 5. A escada de verificação (V0–V5)

O coração do kit. Todo `AC-nnn` carrega uma tag de degrau.

| Degrau | Nome | Como é verificado | Custo | Pode ser automatizado? |
|---|---|---|---|---|
| **V0** | Sintaxe | `gdlint` + `godot --headless --check-only -s <file>` | ~s | sim, em hook |
| **V1** | Import & carga | `godot --headless --path . --import` sem erro; projeto carrega headless; `.uid` presentes | ~s–min | sim |
| **V2** | Unidade | GUT/gdUnit4 sobre lógica pura (resolvers, cálculo de dano, state machine sem nó) | ~s | sim |
| **V3** | Integração headless | Cena instanciada em runner, input simulado via `Input.parse_input_event`, asserts de estado/sinal | ~s–min | sim, **exceto UI com `Control`** |
| **V4** | Bot determinístico | Autoload de bot com `--fixed-fps 60 --quit-after N -- --bot`, seed fixo, exit code explícito; evidência em screenshot/`--write-movie` (requer Xvfb) | min | sim, frágil |
| **V5** | Julgamento humano | Game feel, legibilidade, diversão, clareza visual. Vai para `checks.md` com roteiro de playtest | humano | **não** |

**Regras do degrau:**
- Todo `AC` precisa de exatamente uma tag `V0`–`V5`. Spec sem tag não passa no `/godot-4:analyze`.
- Um sistema com **zero** ACs em V2–V4 é suspeito: ou a spec está vaga, ou a lógica está
  acoplada demais aos nós para ser testável. O `analyze` sinaliza.
- Um AC V5 **nunca** é marcado como concluído por um agente. Só por entrada humana em
  `checks.md`.
- `evidence/` guarda a prova de cada degrau rodado, com timestamp e commit.

**Anti-falso-verde (regras que o `verify.sh` implementa):**
1. Validar que o JUnit XML existe **e** tem contagem de testes > 0 — exit 0 com zero testes
   é o modo de falha mais comum no CI.
2. Rodar `--import` antes de qualquer teste (sem isso, scripts com `class_name` não existem).
3. Fazer grep de `SCRIPT ERROR` / `ERROR:` no stdout, porque o Godot sai 0 depois de erro
   de script.
4. Mapear exit codes do gdUnit4 (0/100/101/103) em vez de tratar "≠0" como genérico.
5. Falhar se houver `.gd` novo sem `.uid` correspondente.

---

## 6. Template: `spec.md` de sistema

```markdown
# SYS-004 — Dash

## Resumo
Uma frase: o que o jogador faz e por que isso existe no jogo.

## Pilares atendidos
Referência a vision.md (ex.: "mobilidade expressiva", "combate legível").

## Fora de escopo
Explícito. Evita que o agente alargue o sistema.

## Comportamento
BEH-012 — Ao pressionar <ação>, o personagem move-se N unidades na direção do input.
BEH-013 — Durante o dash, o personagem é imune a dano de contato.
BEH-014 — [NEEDS CLARIFICATION: o dash cancela o ataque em andamento?]

## Máquina de estados
| Estado | Entra quando | Sai quando | Permite |
|---|---|---|---|
| Idle | ... | ... | ... |
| Dashing | input de dash && cooldown == 0 | duração expira ou colisão | i-frames |

## Superfície de tuning            → vira DashConfig.tres
| ID | Tipo | Faixa | Default | Dono |
|---|---|---|---|---|
| TUN-dash_speed | float | 200–1200 | 600.0 | design |
| TUN-dash_duration | float | 0.05–0.4 | 0.18 | design |
| TUN-dash_cooldown | float | 0.0–3.0 | 0.6 | design |
| TUN-iframe_window | float | 0.0–0.4 | 0.15 | design |

## Contrato de sinais
| ID | Direção | Assinatura | Quem escuta |
|---|---|---|---|
| SIG-dash_started | emite | `dash_started(direction: Vector2)` | VFX, SFX, camera shake |
| SIG-dash_ended | emite | `dash_ended()` | VFX |
| (consome) | ouve | `Input` action "dash" | — |

## Contrato de cena
Árvore mínima exigida, unique names, grupos, collision layers/masks.
Detalhado em plan.md; aqui só o que é observável de fora.

## Critérios de aceitação
| ID | Critério (Given/When/Then) | Degrau |
|---|---|---|
| AC-031 | Given cooldown 0, When ação dash, Then velocidade == TUN-dash_speed por TUN-dash_duration | V2 |
| AC-032 | Given em dash, When corpo inimigo sobrepõe, Then vida não muda | V3 |
| AC-033 | Given dash em parede, When colide, Then estado volta a Idle no mesmo frame | V3 |
| AC-034 | Bot percorre o corredor de teste em ≤ 4.0s com seed 42 | V4 |
| AC-035 | O dash "sente" responsivo: sem atraso perceptível entre input e movimento | **V5** |
| AC-036 | A trilha visual comunica a direção sem poluir a leitura do combate | **V5** |

## Orçamento de performance
Alocações por dash: 0. Draw calls adicionais: ≤ 2. Custo de frame: ≤ 0.2ms em alvo mínimo.

## Decisões
D-SYS004-01 — i-frames começam no frame 1, não no 0. Rationale: ...
D-SYS004-02 — [DESIGN DECISION: dash aéreo permitido?]
```

> Note o que mudou em relação ao Spec Kit: `FR-001` virou `BEH-nnn`; apareceram **máquina
> de estados**, **superfície de tuning**, **contrato de sinais**, **orçamento de
> performance** e a **coluna de degrau** nos critérios. A ausência dessas seções é
> exatamente o que faz um kit genérico produzir código de jogo ruim.

---

## 7. Contrato de cena e a política de `.tscn`

Três estratégias existem no mercado; o kit adota a **híbrida**:

| Estratégia | Quem usa | Veredito |
|---|---|---|
| Guard: bloquear edição estrutural, liberar scalars e `[connection]` | Qb-Lab | **Adotar** como rede de segurança |
| Build script `build_<name>.gd` gera o `.tscn` | iboss-ptk | **Adotar** para cenas novas criadas pelo agente |
| Editar via MCP/editor com índice de UID real | godot-mcp | **Opcional**, quando disponível |

**Política proposta:**
1. Cena **nova** criada pelo agente → sempre via build script em `tools/scenes/build_<name>.gd`,
   executado com `godot --headless -s`. O `.tscn` é artefato gerado e o build script é a
   fonte da verdade.
2. Cena **existente** (feita no editor pelo humano) → o agente só pode alterar valores
   escalares e `[connection]`. Mudança estrutural vira **tarefa para o humano no editor**,
   descrita no `plan.md`, ou vai pelo MCP se instalado.
3. `uid://`, `load_steps`, ids de `ext_resource`/`sub_resource` e blocos de nó são
   **imutáveis por edição de texto**. Hook `PreToolUse` bloqueia.
4. Depois de qualquer criação de arquivo: `godot --headless --path . --import` para gerar
   `.uid`, e falha se sobrar `.gd` sem sidecar.

---

## 8. Comandos

Prefixo `gdspec` (o nome do plugin vira o namespace: `/godot-4:specify`).

| Comando | Faz | Lê | Escreve |
|---|---|---|---|
| `/godot-4:init` | Detecta binário, versão do Godot, renderer, 2D/3D e framework de teste presente; escaneia o projeto e **propõe** a constituição a partir das convenções já existentes; cria `.godotspec/` e o `.gdignore`. Não pergunta "perfil" nem gênero | projeto | `config.yml`, `constitution.md` |
| `/godot-4:vision` | Entrevista sobre pilares, fantasia do jogador, não-objetivos; resolve contradições | — | `vision.md` |
| `/godot-4:roadmap` | Milestones → fatias verticais com `done_when` em duas colunas (agente checa / humano julga) | vision | `roadmap.md` |
| `/godot-4:specify <sistema>` | Gera `spec.md` pelo template da §6, marcando lacunas | vision, roadmap, constitution | `systems/<n>/spec.md` |
| `/godot-4:clarify` | Percorre `[NEEDS CLARIFICATION]` e `[DESIGN DECISION]`, uma pergunta por vez | spec | spec, decisions |
| `/godot-4:plan` | Contratos de cena, schema de Resource, lista de arquivos tocados, riscos, estratégia por degrau | spec, constitution | `plan.md`, `contract.md` |
| `/godot-4:tasks` | Decompõe em passos com file check-out set por tarefa | plan | `tasks.md` |
| `/godot-4:implement` | Executa tarefas; para em `[DESIGN DECISION]` | tasks | código |
| `/godot-4:verify [V0..V5]` | Roda a escada até o degrau pedido, grava evidência, aplica as regras anti-falso-verde | tasks, código | `evidence/` |
| `/godot-4:playtest` | Gera/roda o bot determinístico (V4) e imprime o roteiro de playtest humano (V5) | spec | `evidence/`, `checks.md` |
| `/godot-4:converge` | Gap analysis spec↔código: inventário de intenção, classificação `missing/partial/contradicts/unrequested`, severidade, tabela antes de escrever; só anexa fase de convergência a `tasks.md` | tudo | `tasks.md` |
| `/godot-4:tune <sistema>` | Edita só os `.tres` de tuning, sem tocar em código; registra o antes/depois | spec, `.tres` | `.tres` |
| `/godot-4:review` | Processa vereditos humanos de `checks.md`, fechando ACs V5 | checks | checks, tasks |
| `/godot-4:handoff` | Snapshot do estado para retomar depois | tudo | `handoff.md` |

Conjunto mínimo viável (MVP): `init`, `specify`, `plan`, `tasks`, `implement`, `verify`,
`converge`. O resto é fase 2.

---

## 9. Skills (teto: 15)

Router-first. Só a `using-godot-4` descreve o mapa; as outras são carregadas sob demanda.

| Skill | Quando dispara | Conteúdo pesado em `references/` |
|---|---|---|
| `using-godot-4` | meta/entrada: precedência entre skills, mapa de delegação | — |
| `writing-game-specs` | escrever/revisar `spec.md`, ACs, degraus | templates, exemplos bons e ruins |
| `godot-scene-contracts` | criar/alterar `.tscn`, build scripts, cirurgia segura | regras de uid/load_steps, template de build script |
| `godot-resource-tuning` | superfície de tuning, `@export`, `.tres`, custom resources | padrões de Resource, validação de faixa |
| `godot4-api-guard` | qualquer escrita de GDScript | tabela 3→4, drift entre minors, detecção via `config/features` |
| `gdscript-conventions` | escrita de `.gd` | tipagem estrita, nomes de sinal, `%UniqueName`, estrutura de arquivo |
| `godot-architecture` | decidir onde um sistema mora | composição, autoload sim/não, event bus, DI, layout de pastas |
| `godot-verification` | rodar/entender gates | comandos exatos, exit codes, armadilhas de falso-verde |
| `godot-testing` | escrever testes | GUT e gdUnit4, input simulado, runner de cena, fixtures determinísticas |
| `godot-bot-playtest` | V4 | autoload de bot, seeds, `--fixed-fps`, Xvfb, captura de vídeo |
| `game-feel-review` | V5 | checklist: input buffering, coyote time, hitstop, curvas de câmera, legibilidade |
| `godot-performance` | orçamento de frame, profiling | budgets por plataforma, custos comuns |
| `godot-parallel-work` | 2+ agentes / worktrees | worktree, cache `.godot`, `override.cfg`, merge de `project.godot` |
| `godot-release` | export, presets, CI | `--export-release`, presets, pipeline |
| `godot-mcp-bridge` | um MCP de Godot está conectado | o que ele substitui e o que não substitui (§18) |

Todas seguem as regras de autoria: `SKILL.md` < 500 linhas, descrição em terceira pessoa
dizendo *o que faz e quando usar*, referências a **um nível** de profundidade, ToC em
reference > 100 linhas, sem informação datada fora de seção "padrões antigos".

---

## 10. Agentes (7)

Um agente se justifica quando satisfaz pelo menos um destes critérios. Fora deles, o
mesmo conteúdo é mais barato como skill ou como script:

- **Isolamento** — precisa *não* saber algo que a sessão principal sabe
- **Volume** — leitura ou tentativa-e-erro que encheria o contexto de quem chamou
- **Incentivo conflitante** — quem construiu é o pior juiz do que construiu

| Agente | Critério | Papel |
|---|---|---|
| `verifier` | volume + incentivo | Roda a escada, lê a evidência, reporta. Nunca corrige |
| `blind-qa` | isolamento + incentivo | Testa contra `contract.md`, sem ver código, `plan.md` nem `spec.md` |
| `auditor` | volume | Gap analysis spec↔código para o `converge` |
| `spec-reviewer` | incentivo | Audita a spec antes de existir código: transição de estado faltando, critério no degrau errado, número que virará literal |
| `test-writer` | isolamento + volume | Escreve testes V2/V3 a partir dos critérios, **sem ler a implementação** — senão testa o que o código faz, não o que foi prometido |
| `scene-builder` | volume | Escreve e roda o build script até o `.tscn` carregar. Só cena nova; mudança estrutural em cena feita no editor volta como tarefa humana |
| `researcher` | volume | Resolve uma dúvida de API na *minor* exata do projeto e devolve só a conclusão |

**O que deliberadamente não virou agente:** detecção de API do Godot 3 e conferência de
`.uid` são determinísticas — viram script e hook, onde reprovam de verdade, em vez de
dependerem de um modelo reparar. Profiling foi absorvido pelo `verifier`: é mais uma
leitura de evidência, não outro papel.

---

## 11. Hooks

| Evento | Matcher | Ação | Bloqueia? |
|---|---|---|---|
| `SessionStart` | — | Detecta versão da engine, grava baseline de verificação em `.godotspec/.session` | não |
| `UserPromptSubmit` | — | Injeta linha curta: versão da engine + 3–5 regras invioláveis da constituição | não |
| `PreToolUse` | `Write\|Edit` em `*.tscn,*.tres,project.godot` | Guard estrutural: bloqueia alteração de `uid://`, `load_steps`, ids de `ext_resource`/`sub_resource`, blocos `[node]`; libera scalars e `[connection]` | **sim** |
| `PostToolUse` | `Write\|Edit` em `*.gd` | `gdlint` + `godot --headless --check-only`; 3 falhas seguidas → escala para revisão humana | não (reporta) |
| `PostToolUse` | `Write` criando `*.gd`/`*.tscn`/`*.tres` | Marca pendência de `--import` para gerar `.uid` | não |
| `Stop` | — | Impede encerrar o turno com `.gd`/`.tscn`/`.tres` alterados desde o baseline e nenhum `verify` rodado | **sim** |

Hooks usam `${CLAUDE_PLUGIN_ROOT}` e form exec com `args` para não quebrar em path com
espaço. Todos precisam de um escape hatch documentado (variável de ambiente) — guard que
não pode ser desligado vira guard que o usuário desinstala.

---

## 12. Scripts (`scripts/`)

| Script | Função |
|---|---|
| `godot_env.sh` | Localiza o binário (config.yml → `$GODOT_BIN` → PATH → paths de macOS/Linux/Windows), valida a versão contra a constituição |
| `verify.sh <V0..V5>` | Executa a escada, implementa as 5 regras anti-falso-verde, escreve `evidence/` e um resumo determinístico em uma linha por degrau |
| `guard_scene.py` | Hook `PreToolUse`; diff estrutural de `.tscn`/`.tres` |
| `check_uid.sh` | Encontra `.gd`/`.tres` sem sidecar `.uid` |
| `new_system.sh <slug>` | Cria `systems/<nnn>-<slug>/` a partir dos templates |
| `bot_template.gd` | Autoload de bot com parsing de `OS.get_cmdline_user_args()` e `quit(1)` explícito na falha |

Scripts resolvem o problema em vez de delegar ao modelo: sem constante mágica sem
justificativa, erro com mensagem acionável, saída parseável.

---

## 13. Layout do repositório do kit

```
godot-4-for-claude-code/
├── .claude/                    ← o framework; é isto que o usuário instala
│   ├── settings.json           # os 5 hooks
│   ├── skills/<nome>/SKILL.md  # 15 skills (+ references/ onde faz sentido)
│   ├── commands/godot-4/*.md   # 14 comandos → /godot-4:<nome>
│   ├── agents/*.md             # 7 agentes (§10)
│   ├── scripts/*.sh|*.py|*.gd  # hooks, escada de verificação, scaffolding
│   └── templates/              # spec, plan, tasks, contract, constitution, config
├── CLAUDE.md                   # regras de review, lidas pelo Claude
├── .github/workflows/          # validate · claude-review · release
├── tools/validate_kit.py       # gate de CI; não vai para o usuário
└── docs/                       # pesquisa e especificação; não vai para o usuário
```

Os comandos ficam em `commands/godot-4/` porque o subdiretório vira o namespace:
`/godot-4:specify`. Os scripts de hook saem sem efeito em qualquer repositório sem
`project.godot` — é o que permite o framework conviver com este repo, que não é um
jogo.

**O projeto Godot de validação fica fora deste repositório.** O kit é exercitado de ponta
a ponta num jogo pequeno e completo mantido num projeto separado; aqui entram apenas os
casos de `evals/` e os achados que voltam de lá. Nada de `examples/` no repo.

Distribuição copiando `.claude/` para o projeto Godot. Como não é um plugin,
`claude plugin validate` não se aplica: o gate equivalente é `tools/validate_kit.py`,
que checa frontmatter, tamanho de skill, links quebrados, hooks apontando para scripts
existentes e executáveis, sintaxe dos scripts e incompatibilidades de bash 4 / GNU
coreutils. Ver [release-process.md §3](release-process.md).

---

## 14. Fluxos de referência

**Sistema novo (caminho feliz)**
```
/godot-4:specify dash  →  /godot-4:clarify  →  /godot-4:plan  →  /godot-4:tasks
      →  /godot-4:implement  →  /godot-4:verify V3
      →  /godot-4:playtest        (V4 roda; V5 vai para checks.md)
      →  [humano joga, preenche checks.md]
      →  /godot-4:review  →  /godot-4:converge  →  Converged
```

**Balanceamento sem tocar em código**
```
/godot-4:tune dash   →  edita DashConfig.tres  →  /godot-4:verify V4  →  checks.md
```

**Retomada de sessão**
```
/godot-4:handoff  …  (nova sessão)  …  SessionStart lê handoff.md + baseline
```

---

## 15. Riscos

| Risco | Mitigação |
|---|---|
| `gdformat` gera código que o Godot rejeita (bug aberto em 2026) | Nunca formatar sem parse check depois; `gdformat --check` em vez de escrita automática por padrão |
| V3 não cobre UI (`Control` não recebe clique headless) | Documentado na skill; UI de botão cai em V4 com Xvfb ou direto em V5 |
| V4 é frágil (timing, seeds, Xvfb) | V4 é opcional por sistema; o kit não falha se ele não existir |
| Drift de versão (4.8 chegando) | Versão fixada em `config.yml` e injetada em todo prompt; `api-guard` versiona a tabela |
| Hooks irritam e o usuário desinstala | Todo hook bloqueante tem escape hatch e mensagem explicando *como* prosseguir |
| Context storm | Teto de 14 skills, router na entrada, referências sob demanda |
| Over-engineering para jogo pequeno | Resolvido por desenho, não por flag: artefatos nascem sob demanda e degraus são opcionais por sistema (§19) |
| Dependência de MCP que muda | MCP é opcional e isolado numa skill |

## 16. Critérios de sucesso do próprio kit

- Um sistema de complexidade média (dash, inventário, diálogo) vai de spec a implementação
  verificada **sem o usuário precisar corrigir código Godot 3**.
- Zero `.tscn` corrompido em 20 execuções de ponta a ponta no projeto de validação externo.
- `verify.sh` nunca reporta verde com zero testes executados (teste de regressão próprio).
- Todo AC V5 chega ao humano com roteiro de playtest, nunca marcado como concluído sozinho.
- Metadata total das skills ≤ ~1.500 tokens no startup.
- `tools/validate_kit.py` limpo.

## 17. Decisões

| # | Decisão | Default proposto |
|---|---|---|
| D-P-01 | Distribuição: plugin vs. `.claude/` copiável | **`.claude/`** · *decidido pelo usuário em 22/11*. A justificativa anterior ("plugin é o único formato que entrega hooks") estava errada: `.claude/settings.json` de projeto suporta hooks normalmente. Plugin é sobre distribuição, não sobre capacidade |
| D-P-02 | Framework de teste padrão | **GUT.** Roda headless sem flag extra, exit code binário, JUnit XML. gdUnit4 suportado como alternativa para quem precisa do scene runner · *decidido* |
| D-P-03 | MCP de Godot: obrigatório, opcional ou ausente | **Opcional**, com `tugcantopaloglu/godot-mcp` como alvo de integração (§18) · *decidido* |
| D-P-04 | Idioma do conteúdo do kit (skills/commands) | **Inglês** no kit, docs em PT-BR. A `description` da skill é o que decide o match no startup, e o vocabulário técnico do Godot e do ecossistema é inglês · *decidido* |
| D-P-05 | Escopo 2D, 3D ou ambos no v1 | **Agnóstico a 2D/3D e a gênero** · *decidido* |
| D-P-08 | Perfil de projeto (longo prazo / game jam) | **Sem perfis.** Processo único, scale-free (P9, §19) · *decidido* |
| D-P-09 | Caso de validação | **Jogo pequeno completo, em projeto separado** · *decidido* |
| D-P-06 | Política de `.tscn`: híbrida vs. build-script-only | **Híbrida** (§7). Build-script-only quebraria em projeto que já tem cenas feitas no editor — e esse é o caso normal · *decidido* |
| D-P-07 | Nome do plugin / prefixo de comando | **`godot-4`** → `/godot-4:<cmd>` · *decidido* |

---

## 18. MCP servers de Godot — levantamento (2026-11)

Existem **muitos** e nenhum é oficial. O ecossistema se divide por uma pergunta: *o agente
fala com o editor aberto, ou com o projeto em disco?*

| Projeto | Licença | Editor aberto? | Tools | Notas |
|---|---|---|---|---|
| [`Coding-Solo/godot-mcp`](https://github.com/Coding-Solo/godot-mcp) | MIT | não (CLI) | 14 | O mais popular (~6.7k ⭐, ~4.7k downloads npm/semana). `npx @coding-solo/godot-mcp`. Tem `get_uid` e `update_project_uids`. Escopo pequeno: lançar editor, rodar projeto, capturar debug output, criar cena, add node, salvar |
| [`tugcantopaloglu/godot-mcp`](https://github.com/tugcantopaloglu/godot-mcp) | MIT | **não** | 157 | Godot 4.4+ (testado até 4.7). Dois canais: CLI headless para operações de cena + socket TCP para runtime com o jogo rodando. `modify_scene_node`/`attach_script` fazem alteração pontual em vez de reescrever o arquivo. Tem `get_uid` e `update_project_uids`. Build manual (`npm install && npm run build`) |
| [`voidrot/godot-mcp`](https://github.com/voidrot/godot-mcp) | MIT | **sim** | ~25 | Addon de editor para 4.7 (testado em 4.7.2 mono). Edições de nó viram um passo de undo no editor; exige `save_scene` explícito. Sem tratamento documentado de UID. Tem `validate_script`, `run_headless`, `build_dotnet` |
| `godot-ai` (hi-godot) | MIT | sim | — | ~2.7k ⭐, roda no seu editor 4.7 |
| `satelliteoflove/godot-mcp` | MIT | sim | — | Godot 4.5+; apontado como o melhor para *testes com timing exato* |
| `ee0pdt/Godot-MCP`, `tomyud1/Godlink`, `GoPeak`, `bradypp/godot-mcp` | MIT | sim | 16–… | Alternativas menores |
| Flockbay, GDAI MCP, Godot MCP Pro, Ziva | fechados | sim | — | Comerciais/closed-source. Ziva tem agente de playtest que joga o jogo e devolve pass/fail com vídeo — mas **não roda headless nem em CI**, exige o editor aberto |

### Leitura para o kit

1. **Nenhum MCP substitui a escada de verificação.** Todos os que fazem playtest de verdade
   exigem o editor aberto e não rodam em CI. O caminho base continua sendo CLI headless.
2. **O melhor encaixe com a spec é `tugcantopaloglu/godot-mcp`**: MIT, não exige editor
   aberto, cobre 4.4–4.7, tem `get_uid`/`update_project_uids` e faz edição pontual de nó em
   vez de reescrita do `.tscn` — exatamente o que a §7 pede. Risco: 157 tools inundam a
   lista de ferramentas do agente; precisaria de curadoria.
3. **`Coding-Solo/godot-mcp` é o default pragmático** para quem só quer rodar o projeto e
   capturar debug output: 14 tools, instala com um comando, é o mais usado do ecossistema.
4. **Decisão mantida:** MCP continua **opcional**. Uma skill isolada (`godot-mcp-bridge`)
   detecta qual servidor está instalado e adapta o loop; sem MCP, tudo cai no CLI. Isso
   protege o kit da instabilidade de um ecossistema com dez implementações concorrentes.

---

## 19. Como um processo único serve qualquer jogo

O kit não tem modo lite nem modo enterprise, não tem blueprint de gênero e não se importa
com 2D ou 3D. Isso só funciona porque a adaptação à escala está no **desenho**, não numa
flag de configuração. Quatro mecanismos:

### 19.1 A unidade é o sistema, não o projeto

Uma `spec.md` de sistema tem o mesmo tamanho num jogo de jam e num RPG de três anos — ela
descreve *um* comportamento com sua máquina de estados, seu tuning e seus critérios. Um
jogo grande não tem specs maiores: tem **mais** specs. Toda a escala do projeto vive na
quantidade de pastas em `systems/`, e nenhuma delas precisa ser lida junto com as outras.

É isso que mantém o orçamento de contexto constante (P7) independente do tamanho do jogo.

### 19.2 Artefatos nascem sob demanda

O mínimo viável de `.godotspec/` é `config.yml` + `constitution.md` + `systems/`. Os
demais aparecem quando o projeto os pede, e **nenhum é pré-requisito** para `specify`:

| Artefato | Nasce quando |
|---|---|
| `vision.md` | surge a segunda decisão de design que contradiz a primeira |
| `roadmap.md` | existe mais de um marco a ordenar |
| `glossary.md` | o mesmo conceito aparece com dois nomes no código |
| `contract.md` | você quer blind QA naquele sistema específico |
| `checks.md` | o primeiro AC em V5 é escrito |
| `handoff.md` | a primeira sessão termina com trabalho em aberto |

Um jogo de jam pode viver a vida inteira com três arquivos. O mesmo kit, sem nenhuma
configuração diferente, sustenta um projeto com quarenta sistemas e roadmap de marcos.

### 19.3 Os degraus são opcionais por sistema, nunca por projeto

A regra da escada (§5) é que **todo AC declare seu degrau**, não que todos os degraus
existam. Na prática:

| Tipo de sistema | Perfil típico de ACs |
|---|---|
| Resolver de dano, economia, save/load | V0–V2, sem V3+ |
| Movimento, colisão, máquina de estados | V0–V3, talvez V4 |
| VFX, shader, feedback sensorial | V0, V1 e V5 — e está correto |
| UI de menu | V0, V1, V4 (com Xvfb) ou V5 |

Um sistema com ACs só em V5 não é uma falha do kit: é um sistema cujo valor é inteiramente
perceptual, e o kit torna isso **explícito** em vez de fingir cobertura. O que o `analyze`
sinaliza é outra coisa — um sistema de lógica que *deveria* ser testável e não tem nenhum
AC em V2–V4, sinal de acoplamento demais aos nós.

### 19.4 Dimensão e gênero não entram no processo

Nada em `specify → plan → tasks → implement → verify → converge` depende de ser 2D ou 3D.
O que muda é o conteúdo que o usuário escreve na spec — `Vector2` vs `Vector3` nos asserts,
e os números do orçamento de performance. Ambos vivem na spec do sistema, nunca no kit.

Gênero é conhecimento de design, não processo. Blueprints de gênero são exatamente o que
produz bibliotecas de 100+ skills e o *context storm* descrito em [prior-art.md](../research/prior-art.md).
Ficam de fora (§3).

### 19.5 A menor sessão útil

```
/godot-4:init  →  /godot-4:specify <sistema>  →  /godot-4:implement  →  /godot-4:verify V1
```

Quatro comandos, nenhum artefato além de `config.yml`, `constitution.md` e uma `spec.md`.
Todo o resto — clarify, plan, tasks, blind QA, bot, converge — é adotado quando a dor
aparece, não antes.

# godot-4

Framework de **spec-driven development** para fazer jogos em **Godot 4** com o Claude Code.

Instala como um diretório `.claude/` no seu projeto Godot. Traz 15 skills, 14 comandos,
7 agentes e 5 hooks que impedem os erros que um agente comete em Godot — e uma escada de
verificação que não mente sobre o que foi checado.

---

## O problema

Kits de spec-driven development existentes assumem *user stories* verificáveis por teste
automatizado. Jogo não é assim. A unidade de trabalho é a **mecânica**: uma máquina de
estados, um punhado de números de tuning e uma camada de feedback sensorial — e boa parte
do "está pronto" é julgamento humano que nenhum teste alcança.

E o Godot tem armadilhas próprias que um agente cai sem perceber:

- `.tscn` e `.tres` **parecem INI editável e não são**. Reescrever um como texto
  dessincroniza `uid://`, erra `load_steps` e deixa conexão de sinal pendurada — em
  silêncio, com a quebra aparecendo muito depois.
- A maior parte do GDScript indexado na web é **Godot 3**. `yield`, `.instance()` e
  `export var` saem fluentes e não compilam.
- O engine **sai com exit code 0 depois de um `SCRIPT ERROR`**, e um runner de teste que
  não encontrou teste nenhum também sai 0. Um gate ingênuo reporta verde sobre um projeto
  quebrado.

Este framework responde às três coisas.

## Instalação

Rode **de dentro do seu projeto Godot**. O pacote vai para o diretório temporário, então
nada sobra no projeto.

**macOS / Linux**

```bash
curl -fsSL https://github.com/juannobrega/godot-4-for-claude-code/releases/latest/download/godot-4.tar.gz | tar -xz -C /tmp
/tmp/godot-4/install.sh
```

**Windows (PowerShell)**

```powershell
Invoke-WebRequest https://github.com/juannobrega/godot-4-for-claude-code/releases/latest/download/godot-4.zip -OutFile $env:TEMP\godot-4.zip
Expand-Archive $env:TEMP\godot-4.zip -DestinationPath $env:TEMP -Force
powershell -ExecutionPolicy Bypass -File $env:TEMP\godot-4\install.ps1
```

São dois assets com o **mesmo payload** — o que muda por plataforma é o formato, não o
conteúdo: `unzip` não existe em Linux mínimo e `tar.gz` é estranho no Windows. Os dois
instaladores vão dentro de ambos.

O `install.ps1` roda no Windows PowerShell 5.1 e no PowerShell 7, sem depender de
Python. O `-ExecutionPolicy Bypass` vale só para essa execução e evita o bloqueio de
script baixado da internet. Os hooks continuam sendo scripts bash e Python, então o
Windows precisa do Git for Windows (Git Bash) e de `python3` no PATH; o instalador avisa
se algum dos dois faltar.

### Três formas de escolher o destino

| Comando | Onde instala |
|---|---|
| `install.sh` | **Sobe a árvore** até achar `project.godot` — qualquer subpasta do projeto serve |
| `install.sh --here` | **Nesta pasta**, sem procurar nada. A pasta pode estar vazia |
| `install.sh <path>` | No caminho que você apontar |

No Windows, `-Here` e o caminho posicional. `--dry-run` (`-DryRun`) mostra o que seria
escrito sem escrever. `--help` lista o resto.

A única coisa que o instalador recusa é o **diretório do próprio pacote** — ali o
`.claude` ficaria ao lado do instalador, onde o Claude Code nunca olha. Instalar numa
pasta sem `project.godot` é permitido e só gera um aviso: o framework foi feito para
ficar inerte até o projeto existir.

Ele faz **merge** dos hooks num `settings.json` que já exista, em vez de sobrescrever, e
reinstalar é no-op. Um `settings.json` inválido no destino aborta **antes** de copiar
qualquer arquivo.

Depois, dentro do projeto:

```
/godot-4:init
```

Para atualizar mais tarde, `/godot-4:update`: ele lê o changelog da release nova, mostra o
que muda **neste** projeto, preserva o que você editou e remove o que saiu da versão.

O `init` detecta a versão da engine, lê as convenções que o seu código **já usa** e
propõe uma constituição a partir delas — em vez de impor um estilo de fora.

**Requisitos:** Godot 4.4+ (testado em 4.7.2). Opcionais: `gdtoolkit` para o degrau V0
(`pip install gdtoolkit`) e GUT ou gdUnit4 para V2/V3.

## Como se usa

```
/godot-4:specify dash      →  o quê: comportamento, máquina de estados,
                              superfície de tuning, contrato de sinais
/godot-4:clarify           →  resolve as lacunas marcadas, uma pergunta por vez
/godot-4:plan              →  como: contrato de cena, schema do Resource,
                              arquivos tocados, estratégia por degrau
/godot-4:tasks             →  passos com conjunto de arquivos declarado
/godot-4:implement         →  código, parando em toda decisão de design
/godot-4:verify V3         →  roda a escada e arquiva a evidência
/godot-4:playtest          →  bot determinístico (V4) + roteiro humano (V5)
/godot-4:converge          →  gap analysis spec↔código até "Converged"
```

Nada disso é obrigatório de uma vez. A menor sessão útil é
`init → specify → implement → verify V1`; o resto entra quando a dor aparece.

## A escada de verificação

Todo critério de aceitação declara **em que degrau** é verificado. É a ideia central.

| | Prova que | Automatizável |
|---|---|---|
| **V0** | É GDScript válido e passa no lint | sim |
| **V1** | O projeto importa e carrega; sidecars `.uid` em dia | sim |
| **V2** | Lógica pura se comporta | sim |
| **V3** | A cena se comporta com input simulado | sim, exceto `Control` |
| **V4** | Uma partida inteira atinge a meta, com seed fixo | frágil |
| **V5** | **Parece certo, lê bem, é divertido** | **não** |

Um critério V5 nunca é fechado por um agente. Vai para `checks.md` com um roteiro de
playtest e espera você jogar.

O relatório distingue três desfechos, não dois:

```
V0  SKIP gdlint not installed (pip install gdtoolkit)
V1  PASS import clean, uid sidecars in sync
V2  SKIP no tests/unit/ in this project
V3  SKIP no tests/integration/ in this project
not run: V0 V2 V3 — these prove nothing either way
```

"Não rodou" e "passou" nunca aparecem iguais. O `verify.sh` também escaneia a saída do
engine atrás de `SCRIPT ERROR`, exige que o JUnit XML tenha contagem maior que zero, e
mapeia os exit codes do gdUnit4 (`100` falha, `101` vazou nó, `103` recusou headless).

## O que ele faz no seu projeto

Cria `.godotspec/`, com um `.gdignore` dentro para o editor do Godot ignorar:

```
.godotspec/
├── config.yml          binário, versão, framework de teste, degrau padrão
├── constitution.md     as regras deste projeto
├── systems/<nnn>-<slug>/
│   ├── spec.md         comportamento, tuning, critérios por degrau
│   ├── plan.md         contrato de cena, arquivos tocados
│   ├── contract.md     contrato público, para o blind QA
│   └── evidence/       saída de cada verificação
└── checks.md           a fila de julgamento humano
```

E ativa 5 hooks:

| Evento | O que faz |
|---|---|
| `PreToolUse` | **Bloqueia** edição estrutural de `.tscn`/`.tres`; libera escalares e `[connection]` |
| `PostToolUse` | `gdlint` + parse check em todo `.gd` escrito |
| `Stop` | **Impede encerrar o turno** com arquivos alterados e nenhuma verificação rodada |
| `UserPromptSubmit` | Injeta a versão da engine e avisa se o binário diverge do fixado |
| `SessionStart` | Marca o baseline de verificação |

Os dois bloqueantes têm escape hatch (`GODOT4_GUARD_OFF`, `GODOT4_VERIFY_OFF`), e **todos
saem sem efeito** num diretório sem `project.godot`.

## O que tem na caixa

| | |
|---|---|
| **15 skills** | roteadas por `using-godot-4`; carregue só a que a tarefa pede |
| **15 comandos** | `/godot-4:init`, `:specify`, `:verify`, `:converge`, `:update`, … |
| **7 agentes** | `verifier` · `blind-qa` · `auditor` · `spec-reviewer` · `test-writer` · `scene-builder` · `researcher` |
| **5 hooks** | a camada que impede, não só aconselha |
| **7 templates** | spec · plan · tasks · contract · constitution · config · CLAUDE.md |

O teto de skills é deliberado. A metadata de toda skill instalada entra no system prompt
no startup: bibliotecas de 100+ skills afogam o agente em descrições concorrentes.

## Para que tipo de jogo

Qualquer um — pequeno ou grande, 2D ou 3D, qualquer gênero. Não há modo *lite* nem
blueprint de gênero. A unidade de trabalho é o **sistema**, e um jogo grande não tem specs
maiores: tem mais specs. Artefatos nascem sob demanda, e os degraus são opcionais **por
sistema**, nunca por projeto.

## Documentação

| | |
|---|---|
| [kit-spec.md](docs/spec/kit-spec.md) | A especificação do framework: tese, princípios, artefatos, escada, comandos, skills, agentes, hooks, riscos, decisões |
| [update-and-memory.md](docs/spec/update-and-memory.md) | Como atualizar um projeto já instalado: manifesto, divisão entre script e julgamento, e memória de projeto via `CLAUDE.md` |
| [release-process.md](docs/spec/release-process.md) | Branches, versionamento semver pela descrição do PR, empacotamento |
| [prior-art.md](docs/research/prior-art.md) | Spec Kit, Agent OS, BMAD e as coleções de skills de Godot, com análise de lacunas |
| [godot-constraints.md](docs/research/godot-constraints.md) | As restrições verificadas do Godot 4 que determinam o desenho |

## Contribuindo

Duas branches. `dev` é onde o trabalho acontece; `main` recebe PR só vindo dela, e todo
merge gera release. O incremento vai numa linha da descrição do PR:

```
Release: minor
```

Sem ela a esteira reprova — um `patch` implícito esconde uma decisão que ninguém tomou.

## Licença

MIT.

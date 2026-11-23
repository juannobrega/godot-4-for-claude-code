# Branches, versionamento e release

**Status:** implementado. Branches em vigor, esteira em
[`.github/workflows/`](../../.github/workflows).

Repositório: `github.com/juannobrega/godot-4-for-claude-code`. O usuário fala em *merge
request*; no GitHub o equivalente é **pull request**. Neste documento: **MR**.

---

## 1. Modelo de branches

Apenas **duas** branches no repositório. Qualquer outra é erro.

| Branch | Papel | Regras |
|---|---|---|
| `main` | Branch principal e única fonte de release | Protegida. Recebe apenas MR vindo de `dev`. Todo merge gera uma release |
| `dev` | Branch de trabalho | Único origem de MR. Todo commit de desenvolvimento nasce aqui |

```
dev  ──●──●──●──●─────────────●──●──●──▶   todo push vai para cá
                 \           /
main ─────────────●─────────●───────────▶   cada merge = uma release
                  v0.2.0    v0.3.0
          ↑ PR aberto = esteira roda
```

**Push vai sempre para `dev`.** A esteira de CI/CD roda **na abertura do pull request
para `main`** — não a cada push. Isso dá ao `dev` liberdade para commits intermediários
quebrados sem gastar execução de pipeline, e concentra a validação no ponto em que ela
decide alguma coisa.

**Consequência aceita conscientemente:** sem branches de feature, tudo que estiver em `dev`
no momento do MR entra na mesma release. Não há como soltar metade do trabalho acumulado.
É a troca deliberada por simplicidade num repositório de um mantenedor.

---

## 2. Versionamento

Semver `MAJOR.MINOR.PATCH`. O tipo de incremento vem de um **parâmetro na descrição do MR**.

### 2.1 Formato do parâmetro

Uma linha na descrição do MR:

```
Release: minor
```

Regra de parsing proposta: primeira ocorrência de `^Release:\s*(major|minor|patch)\s*$`,
case-insensitive. **Ausente → o pipeline falha** com mensagem explícita, em vez de assumir
`patch` em silêncio. Default implícito é como gate de CI mente: parece que alguém decidiu.

> **Alternativa a avaliar:** uma *label* no MR (`release:minor`) em vez de texto livre na
> descrição. Labels são estruturadas, não quebram com edição de prosa e aparecem na lista
> de MRs. O requisito atual é a descrição; registrado como D-R-01.

### 2.2 O que conta como cada incremento *neste kit*

Semver genérico não diz nada útil para um kit de processo. Aqui:

| Incremento | Quando | Exemplos |
|---|---|---|
| **MAJOR** | Quebra o que o usuário já tem em `.godotspec/` ou nos comandos que ele usa | Mudar o formato de `spec.md`; renomear ou remover um comando; renomear a pasta de artefatos; mudar o significado de um degrau da escada |
| **MINOR** | Acréscimo compatível | Nova skill; novo comando; nova seção opcional num template; novo gate que não reprova projeto existente |
| **PATCH** | Correção sem mudança de contrato | Bug em script ou hook; correção de comando errado numa reference; ajuste de texto de skill; atualização de tabela de API |

Regra prática: se um projeto que já usa o kit precisa **mudar algum arquivo dele** para
continuar funcionando, é MAJOR.

**A exceção é a 1.0.0.** Sair de `0.x` é uma declaração de estabilidade, não um aviso de
quebra: diz que os comandos, o formato dos artefatos em `.godotspec/` e os degraus da
escada passam a ter compatibilidade garantida nas versões seguintes. É a única vez que um
MAJOR não exige nada do usuário — e, por isso, a única que é decisão de produto e não
consequência do diff.

---

## 3. O que entra na release

O framework é um diretório `.claude/`, não um plugin do Claude Code. Isso simplifica o
empacotamento: não há `plugin.json` com versão fixada, não há entrada de marketplace para
atualizar, e nenhuma escrita automatizada em branch protegida.

**Entra** — o payload que o usuário copia para o projeto Godot dele:

```
.claude/settings.json      .claude/skills/      .claude/commands/
.claude/agents/            .claude/scripts/     .claude/templates/
LICENSE                    README.md
```

**Não entra** — material do repositório:

```
docs/                      especificação e pesquisa
tools/                     validador do próprio kit
.github/                   instruções de review
```

O empacotamento **remove e depois confere** que nenhum `__pycache__` ou `.pyc` sobrou: o
`validate_kit.py` roda `py_compile` antes do build e a v0.1.0 chegou a publicar um. A
verificação de vazamento checa tanto diretórios de topo quanto artefatos de build.

São **dois assets com o mesmo payload**: `godot-4.tar.gz` e `godot-4.zip`. O que difere
por plataforma é o formato, não o conteúdo — `unzip` não existe em imagem Linux mínima e
`tar.gz` é estranho no Windows. Separar o payload em si só deixaria duas árvores idênticas
para manter em sincronia, então `install.sh` e `install.ps1` vão dentro de ambos.

O pacote leva um `INSTALL.md` gerado no build, não o README do repositório: o README é
sobre contribuir com o framework, não sobre instalá-lo.

Os dois instaladores copiam os diretórios para o projeto alvo e fazem **merge** dos hooks
no `settings.json` existente em vez de sobrescrevê-lo — um projeto Godot provavelmente já
tem hooks próprios. Ambos **sobem a árvore procurando `project.godot`** em vez de usar o
diretório atual: o default anterior instalava onde o shell estivesse, e como o `unzip`
deixa o pacote na pasta atual, bastava um `cd` para o `.claude` ir para dentro do pacote,
onde o Claude Code nunca olha. Também recusam o próprio diretório do pacote como destino,
e recusam quando não existe projeto algum.

A versão vive na tag e num `VERSION` dentro do pacote, gerado no build. Nada precisa ser
commitado em `main` a cada release.

## 4. A esteira

Duas etapas, em momentos diferentes.

### 4.1 `validate.yml` — na abertura do PR `dev → main`

Dispara em `opened`, `reopened`, `synchronize` e **`edited`** — este último porque o
incremento mora na descrição do PR e editá-la precisa revalidar.

| Job | O que faz | Bloqueia? |
|---|---|---|
| `kit` | `tools/validate_kit.py`; `shellcheck -S warning`; `gdlint` no `bot_template.gd` | sim |
| `install-windows` | `tools/test_install_ps1.ps1` em `windows-latest`, no Windows PowerShell 5.1 e no PowerShell 7: instalação limpa, reinstalação sem efeito, merge com hooks existentes e `settings.json` inválido abortando antes de copiar | sim |
| `increment` | Lê `Release: <tipo>` da descrição, com label `release:<tipo>` como fallback | sim |
| `review` (workflow `claude-review.yml`) | Review do Claude no PR, via `claude-code-action` | não |

Um detalhe de segurança: a descrição do PR é entrada não confiável. Ela chega aos scripts
por variável de ambiente, nunca interpolada direto no comando — `${{ }}` dentro de um
`run:` é injeção de shell.

### 4.2 Revisor de IA: Claude, não Copilot

`claude-review.yml` roda o plugin oficial `code-review` via `claude-code-action`,
autenticado com `CLAUDE_CODE_OAUTH_TOKEN` — token de assinatura gerado por
`claude setup-token`, válido em Pro, Max, Ultra, Team e Enterprise. Com ele os runs
saem na assinatura em vez de billing de API.

**Por que não o Copilot.** O Copilot code review exige plano pago a partir do Pro
($10/mês) e, desde 01/06/2026, consome AI credits por review. Na conta deste repositório
ele não está disponível: `suggestedActors` não retorna o bot e a REST responde
422 "Reviews may only be requested from collaborators". O job que pedia a review foi
**removido** — ele ficava verde sem ter feito nada, que é exatamente o gate desonesto
que este kit existe para impedir.

As regras de review vivem em [`CLAUDE.md`](../../CLAUDE.md) na raiz, em um arquivo só.
`.github/copilot-instructions.md` ficou como ponteiro, para que habilitar o Copilot um
dia não exija reescrever nada.

**Limite que continua valendo:** o review comenta, não reprova. O gate duro é
`validate.yml`. E quando o secret não existe, o job diz isso no resumo do PR em vez de
passar em silêncio.

### 4.3 `release.yml` — no merge em `main`

Dispara em `pull_request: closed` com `merged == true`, e não em `push: main`. O motivo é
prático: o evento de PR carrega a descrição, que é onde o incremento está declarado — um
evento de push teria que ir procurar o PR correspondente ao commit de merge.

1. Revalida sobre o resultado do merge, não sobre a head do PR
2. Calcula a versão: última tag `v*` + incremento (sem tag → `v0.0.0`)
3. Monta o zip com o payload da §3, `VERSION` gerado, `install.sh` e `install.ps1`
4. **Checa que `docs/`, `tools/` e `.github/` não vazaram** para o pacote — a exclusão é
   verificada, não assumida a partir da lista de cópia
5. Cria a tag e publica a GitHub Release

O asset chama-se `godot-4.zip` sem versão no nome, de propósito: mantém estável a URL
`releases/latest/download/godot-4.zip`.

### 4.4 `install.sh`

Vai dentro do zip. Copia `skills/`, `commands/`, `agents/`, `scripts/` e `templates/` para
o `.claude/` do projeto alvo e faz **merge** dos hooks no `settings.json` existente em vez
de sobrescrevê-lo — um projeto Godot real provavelmente já tem hooks próprios. O merge
identifica um grupo pelos scripts que ele roda, então reinstalar é no-op e um matcher
editado à mão não é revertido em silêncio.

### 4.5 `install.ps1`

Equivalente do `install.sh` para Windows, com o mesmo contrato: mesmos diretórios, mesma
regra de merge por comando. Roda no Windows PowerShell 5.1 e no PowerShell 7 e não depende
de Python, porque o merge é feito com `ConvertFrom-Json`/`ConvertTo-Json`.

Duas diferenças deliberadas em relação ao `install.sh`:

1. Os dois `settings.json` são lidos **antes** de qualquer cópia. Um `settings.json`
   inválido no projeto alvo aborta a instalação sem deixar nada pela metade.
2. O `settings.json` é gravado em UTF-8 **sem BOM**. O `Set-Content -Encoding UTF8` do
   PowerShell 5.1 grava BOM, e um BOM antes do JSON quebra parsers que não o esperam.

O instalador não reescreve os hooks: eles continuam sendo `.sh` e `.py`, executados pelo
Git Bash. Ele avisa, sem bloquear, quando `bash` ou `python3` não estão no PATH.

O job `install-windows` testa o instalador. Ele não prova que os hooks rodam numa sessão
do Claude Code no Windows; isso continua sendo verificação manual.

## 5. Decisões

| # | Decisão | Estado |
|---|---|---|
| D-R-01 | Parâmetro de incremento | **Linha `Release: <major\|minor\|patch>` na descrição do MR.** O pipeline aceita também uma label `release:<tipo>` como fallback — aditivo, não substitui |
| D-R-02 | Marketplace / `plugin.json` | **Não se aplica.** O framework é um `.claude/`, não um plugin (D-P-01) |
| D-R-03 | Validação automatizada | **`tools/validate_kit.py` + `shellcheck -S warning` + `gdlint` como gate duro, na abertura do PR** |
| D-R-08 | Patamar do shellcheck | **`-S warning` bloqueia.** A execução 45187189794 confirmou a base limpa nesse nível, então um achado novo é regressão |
| D-R-04 | Forma de empacotamento | **Zip do payload da §3 como asset da GitHub Release, com `install.sh` que faz merge dos hooks** |
| D-R-06 | Revisor de IA na esteira | **`claude-code-action` com token de assinatura**, não Copilot. O Copilot exige plano pago e não está disponível nesta conta (§4.2) |
| D-R-09 | Onde vivem as regras de review | **`CLAUDE.md` na raiz**, arquivo único; `copilot-instructions.md` é ponteiro |
| D-R-07 | Quando a esteira roda | **Na abertura do PR `dev → main`**, não a cada push |
| D-R-05 | Ausência do parâmetro no MR reprova o pipeline | **Sim**, sem default implícito |
| D-R-10 | Instalação no Windows | **`install.ps1` nativo em PowerShell**, sem Python, testado em `windows-latest` nos dois hosts. Os hooks seguem em bash e rodam pelo Git Bash |


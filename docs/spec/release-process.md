# Branches, versionamento e release

**Status:** modelo de branches em vigor · pipeline é **trabalho futuro**, não implementar ainda.
`.github/copilot-instructions.md` já existe: é inerte sem a esteira, e é o que torna a
review do Copilot específica deste kit quando ela for ligada.

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

O artefato é um zip publicado como asset da GitHub Release, mais um `install.sh` que
copia os diretórios para o projeto alvo e faz **merge** dos hooks no `settings.json`
existente em vez de sobrescrevê-lo — um projeto Godot provavelmente já tem hooks próprios.

A versão vive na tag e num `VERSION` dentro do zip, gerado no build. Nada precisa ser
commitado em `main` a cada release.

## 4. Esboço do pipeline (não implementar ainda)

Duas etapas, em momentos diferentes.

### 4.1 Na abertura do PR `dev → main` — validação

```
1. tools/validate_kit.py                 # frontmatter, tamanho de skill, links,
                                         # hooks apontando para scripts existentes,
                                         # sintaxe dos scripts, bash 4 / GNU-ismos
2. shellcheck .claude/scripts/*.sh
3. GitHub Copilot code review            # revisor automático (ver 4.2)
4. ler o incremento da descrição do PR   # falhar se ausente ou inválido
```

### 4.2 GitHub Copilot como validador

O Copilot é adicionado como revisor automático do PR, guiado por
[`.github/copilot-instructions.md`](../../.github/copilot-instructions.md). Sem esse
arquivo ele revisaria shell e Markdown genéricos; com ele, revisa contra as regras que
este kit realmente tem — bash 3.2 do macOS, GNU-ismos, hooks que precisam sair sem efeito
fora de um projeto Godot, hook bloqueante sem escape hatch, os cinco modos de falso-verde
do `verify.sh`, e API do Godot 3 vazando para exemplos que o usuário vai copiar.

**Limite a registrar antes de montar a esteira:** o Copilot code review **comenta, não
reprova**. Ele não produz um check de status que a proteção de branch possa exigir, e a
review dele não conta como aprovação para efeito de branch protection. Então:

- **Gate duro** = `validate_kit.py` + `shellcheck` + o parsing do incremento. São eles
  que reprovam o merge.
- **Copilot** = revisor cuja saída é lida antes do merge. Para torná-lo semi-bloqueante,
  a opção é exigir que conversas do PR estejam resolvidas na proteção de branch — o que
  obriga a responder cada comentário dele, mas também aos comentários humanos.

Chamar o Copilot de "validador" sem essa distinção criaria a impressão de um gate que
não existe. Ele é a segunda leitura; o gate é script.

### 4.3 No merge em `main` — release

```
5. revalidar
6. calcular a nova versão a partir da última tag e do incremento
7. montar o zip com as pastas da §3 e um VERSION gerado
8. criar a tag vX.Y.Z
9. publicar a GitHub Release com o zip
```

## 5. Decisões

| # | Decisão | Estado |
|---|---|---|
| D-R-01 | Parâmetro de incremento | **Linha `Release: <major\|minor\|patch>` na descrição do MR.** O pipeline aceita também uma label `release:<tipo>` como fallback — aditivo, não substitui |
| D-R-02 | Marketplace / `plugin.json` | **Não se aplica.** O framework é um `.claude/`, não um plugin (D-P-01) |
| D-R-03 | Validação automatizada | **`tools/validate_kit.py` + `shellcheck` como gate duro, na abertura do PR** |
| D-R-04 | Forma de empacotamento | **Zip do payload da §3 como asset da GitHub Release, com `install.sh` que faz merge dos hooks** |
| D-R-06 | GitHub Copilot na esteira | **Revisor automático do PR, guiado por `.github/copilot-instructions.md`.** Comenta, não reprova — o gate duro continua sendo script (§4.2) |
| D-R-07 | Quando a esteira roda | **Na abertura do PR `dev → main`**, não a cada push |
| D-R-05 | Ausência do parâmetro no MR reprova o pipeline | **Sim**, sem default implícito |


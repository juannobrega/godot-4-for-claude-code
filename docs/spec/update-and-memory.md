# Atualização e memória de projeto

**Status:** implementado. `installer.py`, `/godot-4:update`, manifesto e a ligação com
`CLAUDE.md` estão no `.claude/` e nos instaladores.

Como um projeto que já tem o framework instalado passa para uma versão nova, e como
as regras do projeto deixam de ser reinjetadas a cada turno.

---

## 1. O que quebra num update hoje

Rodar o instalador da versão nova já sobrescreve os arquivos. O problema é o que ele
não faz, e a causa raiz é única: **o projeto instalado não guarda registro do que foi
instalado.** O `VERSION` fica na raiz do pacote e nunca entra no `.claude/`.

| # | Defeito | Consequência |
|---|---|---|
| B1 | `cp -R` só adiciona e sobrescreve | Skill removida numa versão nova fica para sempre, e a `description` dela continua disputando atenção no startup — o *context storm* que o teto de 15 skills existe para evitar |
| B2 | O merge identifica grupo de hook pelo caminho do script | Script renomeado deixa o grupo antigo apontando para arquivo inexistente: hook falha em todo write. Hook removido continua ativo |
| B3 | Nada distingue arquivo do framework de arquivo do usuário | Edição local é sobrescrita em silêncio, e arquivos obsoletos não podem ser apagados com segurança |
| B4 | Sem versão registrada | Impossível dizer se os artefatos em `.godotspec/` precisam de migração |

## 2. O manifesto

`.claude/.godot-4-manifest.json`, escrito em toda instalação:

```json
{
  "version": "1.0.1",
  "installed_at": "2026-11-22T23:59:00-03:00",
  "files": { "skills/godot-testing/SKILL.md": "<sha256>" },
  "hook_groups": [["scripts/guard_scene.py"], ["scripts/lint_gd.sh"]]
}
```

O hash é o do arquivo **como entregue**, não como está agora. É a diferença entre
"isto é nosso" e "isto é nosso e intocado", e é o que torna B3 resolvível.

## 3. Divisão de trabalho

O difícil num update não é copiar arquivos, é julgamento: quais edições locais
conflitam, o que o changelog mudou e se afeta *este* projeto, se uma skill removida
era usada aqui, se um MAJOR exige migrar artefatos. Script não faz nada disso.

| Camada | Responsabilidade | Por quê |
|---|---|---|
| `installer.py` | Diff determinístico: sobrescreve, remove obsoleto, troca grupos de hook, reporta conflitos | Precisa funcionar sem modelo — CI, frota, quem não tem sessão |
| `/godot-4:update` | Lê as release notes, roda `--dry-run`, explica o que muda para este projeto, resolve conflitos, reconcilia a constituição | É tudo o que script não prova |

`install.sh` e `install.ps1` passaram a ser só a casca: resolvem o destino e aplicam os
guards. Tudo que toca arquivo está no `installer.py`, compartilhado, porque a lógica de
manifesto duplicada em bash e PowerShell divergiria. Isso também eliminou a duplicação
que já existia no merge de hooks, e tirou 78 linhas do `install.ps1`.

A promessa de "sem dependência de Python" do `install.ps1` caiu, e não custou nada: os
hooks são bash e Python, então uma instalação Windows sem Python produzia um framework
que não roda. Depender dele no instalador troca duas implementações por uma.

O script é o piso e não é opcional. O comando é o teto. Mesma divisão da escada
V0–V5: determinístico onde dá, julgamento onde não dá.

## 4. O algoritmo

Todo arquivo sob `.claude/` cai em exatamente uma categoria:

| Situação | Ação |
|---|---|
| No manifesto, hash bate | sobrescreve ou apaga sem perguntar |
| No manifesto, hash **não** bate | conflito: preserva, salva `.orig`, reporta |
| **Fora** do manifesto | é do usuário — nunca toca |
| No manifesto antigo, ausente na versão nova | obsoleto: remove se intacto |

Grupos de hook do manifesto antigo são **removidos antes** de mesclar os novos.
Resolve B2 de uma vez: renomeação e remoção passam a funcionar.

`.godotspec/` nunca é tocado por um update. As specs são do usuário; só `.claude/`
é do framework.

## 5. Memória de projeto

Hoje o hook `UserPromptSubmit` injeta versão da engine e regras **a cada turno** —
custo de token em toda mensagem para entregar algo que muda uma vez por sessão.

A constituição deveria chegar pelo `CLAUDE.md` do projeto Godot, que carrega uma vez.
O hook encolhe para só o aviso de divergência de versão, que é a única parte que
precisa ser verificada continuamente.

**Decisão necessária: quem é a fonte da verdade?** Duas cópias das mesmas regras
divergem — já aconteceu neste repo com a versão da engine em `config.yml` e em
`constitution.md`, e o resultado foi a issue #7. Proposta: `CLAUDE.md` com um
`@import` da constituição. Uma fonte, dois leitores.

No update isso é o caso que mais exige julgamento: a constituição do projeto foi
**descoberta do código dele** pelo `init`. Sobrescrever apaga o que o projeto é.
Reconciliar com o template novo não tem merge mecânico possível.

## 6. A sessão precisa reiniciar

Skills e hooks carregam no início da sessão, então **um update nunca faz efeito na
sessão que o rodou**. O comando precisa dizer isso, e compõe com `/godot-4:handoff`:
update escreve o handoff, o usuário reinicia, a sessão nova lê onde parou.

## 7. Decisões em aberto

| # | Decisão | Proposta |
|---|---|---|
| D-U-01 | Edição local | **Preserva e avisa**, e grava o arquivo da versão nova como `.new` ao lado para diff. `--force` substitui · *implementado* |
| D-U-02 | Checagem de versão nova via API de releases | **No comando, não no script.** O `installer.py` não toca a rede; quem consulta a API é o `/godot-4:update` · *implementado* |
| D-U-03 | Fonte da verdade das regras | **`CLAUDE.md` com `@import` da constituição.** O hook deixou de repetir as regras e caiu de 5 linhas por turno para 1 · *implementado* |
| D-U-04 | Rollback | Reexecutar o instalador da versão antiga. Releases são imutáveis, então sai de graça |
| D-U-05 | O manifesto entra em `.gitignore` do usuário? | **Não.** Versionado, para o time todo saber qual versão o projeto tem |
| D-U-06 | O que acontece sem manifesto (instalação anterior a ele) | Instala por cima e **avisa que não consegue limpar obsoletos**, por não haver registro do que foi entregue |

## 8. Não-objetivos

- Atualizar o `.godotspec/` do usuário automaticamente num MAJOR. O comando detecta e
  orienta; migrar é decisão do usuário.
- Update parcial ("só as skills"). Versão é um conjunto coerente.
- Auto-update silencioso.

## 9. Verificado

Cenário de update com as quatro categorias ao mesmo tempo, em projeto Godot real:

| Defeito | Resultado |
|---|---|
| B1 skill removida na versão nova | removida do projeto |
| B2 hook renomeado | grupo antigo substituído; zero grupos órfãos |
| B3 skill editada pelo usuário | preservada, com `.new` ao lado |
| B3 skill própria do usuário | intocada |
| B4 versão | manifesto registra 1.0.2, e exclui o arquivo editado por não ser mais nosso |

As oito verificações de `tools/test_install_ps1.ps1` passam, incluindo três novas para as
formas de destino. O empacotamento falha se `installer.py` ou `VERSION` não entrarem.

## 10. Limitação a registrar

Esta spec foi escrita como documento, não produzida por `/godot-4:specify`. O
framework só opera dentro de um diretório com `project.godot`, e este repositório não
é um jogo — **o kit não consegue especificar o próprio desenvolvimento**. É um
argumento a mais para o projeto de validação da D-P-09, que continua não existindo.

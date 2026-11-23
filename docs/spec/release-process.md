# Branches, versionamento e release

**Status:** modelo de branches em vigor desde já · pipeline é **trabalho futuro**, não implementar ainda.

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
dev  ──●──●──●──●─────────────●──●──●──▶
                 \           /
main ─────────────●─────────●───────────▶   cada merge = uma release
                  v0.2.0    v0.3.0
```

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

**Entra** — o kit executável:

```
.claude-plugin/plugin.json
skills/      commands/      agents/
hooks/       scripts/       templates/
LICENSE      README.md
```

**Não entra** — material de projeto:

```
docs/        (pesquisa e especificação)
evals/       (casos de teste do próprio kit)
```

### 3.1 O problema: o caminho normal de instalação traz o repo inteiro

Um plugin instalado de um marketplace com `source` apontando para o repositório recebe
**todos os arquivos do repositório**. Então "excluir `docs/` da release" não acontece
sozinho — depende de escolher a forma do `source` no `marketplace.json`.

Três formas possíveis, confirmadas na [referência de marketplace](https://code.claude.com/docs/en/plugins/marketplace-reference):

| Opção | `source` da entrada | `docs/` chega ao usuário? | Custo |
|---|---|---|---|
| **A — archive** | `{"source":"archive","url":".../releases/latest/download/godot-4.zip"}` | **não** | Pipeline monta o zip e publica a release. A entrada nunca muda (§3.3) |
| **B — subdiretório** | `"./plugin"` (caminho relativo, resolvido a partir da raiz do marketplace) | sim, mas inerte — só `plugin/` é carregado | Reorganizar o repo: kit em `plugin/`, docs na raiz |
| **C — repo inteiro** | `{"source":"github","repo":"<owner>/<repo>","ref":"v1.2.0"}` | sim | Nenhum — mas **não atende ao requisito** |

### 3.2 Recomendação: opção A

Além de ser a única que cumpre o requisito literalmente, ela resolve um problema de
versionamento que a B tem.

O `version` do `plugin.json` **fixa o usuário naquela versão até mudar**, então o pipeline
precisa necessariamente escrevê-lo a cada release. Com a opção B, isso é um commit de bump
direto em `main` — que é protegida e só aceita MR. Saídas seriam dar bypass de proteção ao
token de CI, ou bumpar na própria `dev` antes do merge (e aí a decisão major/minor/patch
teria que ser tomada duas vezes).

Com a opção A o `plugin.json` é **gerado no build**: o pipeline deriva a versão da tag e a
injeta no zip, sem commitar nada em `main`. Nenhum bypass de proteção, nenhuma divergência
entre `main` e `dev`.

### 3.3 Como o `marketplace.json` nunca precisa ser tocado

O ponto fraco aparente da opção A seria ter que reescrever a URL do zip a cada release.
Não precisa: o GitHub serve um endereço estável que redireciona para o asset da release
mais recente.

```json
{
  "name": "godot-4",
  "source": {
    "source": "archive",
    "url": "https://github.com/juannobrega/godot-4-for-claude-code/releases/latest/download/godot-4.zip"
  }
}
```

Com o nome do asset fixo (`godot-4.zip`, sem versão embutida), a entrada é escrita **uma
vez** e nunca mais. O pipeline só publica a release; nada é commitado em `main`, não há
bypass de proteção, e `main` e `dev` jamais divergem.

**O preço:** abrir mão do `sha256`. Ele é opcional — quando presente, o Claude Code recusa
um download que não bata —, mas um digest fixo é incompatível com uma URL cujo conteúdo
muda a cada release. Troca aceita: o repositório é de um mantenedor só, e a alternativa
custa um commit automatizado em branch protegida a cada release.

**A verificar antes de implementar:** que o cliente siga o redirect de
`/releases/latest/download/` dentro dos limites de download de arquivos hospedados.
Se não seguir, cai-se no plano B — URL versionada e um único commit automatizado em `main`
restrito ao `marketplace.json`.

---

## 4. Esboço do pipeline (não implementar ainda)

Disparado por: merge de MR em `main`.

```
1. claude plugin validate --strict .          # gate — warnings viram falha
2. shellcheck scripts/*.sh ; python -m py_compile scripts/*.py
3. ler o tipo de incremento da descrição do MR  → falhar se ausente/inválido
4. calcular a nova versão a partir da última tag
5. montar o pacote: só as pastas da §3, com plugin.json.version injetado
6. criar a tag vX.Y.Z
7. publicar a GitHub Release com o zip e o sha256
8. atualizar a entrada do marketplace.json  (ver D-R-02)
```

### 4.1 Onde o eval roda

`claude plugin eval` **não** entra no pipeline de release: rodar os casos depois do merge é
tarde demais, a release já está acontecendo. O eval é gate do **MR**, junto com o
`validate --strict`. O pipeline de `main` revalida e publica.

```
MR (dev → main):   claude plugin validate --strict  +  claude plugin eval  +  lint de scripts
merge em main:     revalida, empacota, taggeia, publica
```

---

## 5. Decisões

| # | Decisão | Estado |
|---|---|---|
| D-R-01 | Parâmetro de incremento | **Linha `Release: <major\|minor\|patch>` na descrição do MR.** O pipeline aceita também uma label `release:<tipo>` como fallback — aditivo, não substitui |
| D-R-02 | Onde vive o `marketplace.json` e quem o atualiza | **`.claude-plugin/marketplace.json` no repo, apontando para a URL `releases/latest/download/`. Nunca é atualizado pelo pipeline** (§3.3) |
| D-R-03 | `claude plugin eval` como gate | **Gate do MR, não do release** (§4.1) |
| D-R-04 | Forma de empacotamento | **Opção A — archive** |
| D-R-05 | Ausência do parâmetro no MR reprova o pipeline | **Sim**, sem default implícito |

Tarefa de verificação pendente antes de implementar: confirmar que o cliente segue o
redirect de `/releases/latest/download/` (§3.3).

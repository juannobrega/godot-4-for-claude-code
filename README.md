# godot-4-for-claude-code

Kit de **spec-driven development** para desenvolvimento de jogos em **Godot 4** com o
Claude Code.

> **Status:** framework construído em [`.claude/`](.claude), especificação em `docs/`.
> A esteira de CI/CD ainda não existe.

## O que tem aqui

```
.claude/
├── settings.json          5 hooks: guard de cena, lint pós-escrita,
│                          contexto da engine, baseline, verify-before-done
├── skills/                15 skills, roteadas por using-godot-4
├── commands/godot-4/      14 comandos  →  /godot-4:init, :specify, :verify …
├── agents/                verifier · blind-qa · auditor
├── scripts/               escada de verificação, hooks, scaffolding, bot
└── templates/             spec · plan · tasks · contract · constitution · config
```

Para usar num projeto Godot: copie `.claude/` para o projeto e rode `/godot-4:init`.
Fora de um projeto com `project.godot`, todos os hooks saem sem efeito.

## Documentos

| Documento | Conteúdo |
|---|---|
| [docs/spec/kit-spec.md](docs/spec/kit-spec.md) | **A especificação do framework** — tese, princípios, artefatos, escada de verificação, comandos `/godot-4:*`, skills, agentes, hooks, riscos, levantamento de MCP servers, decisões |
| [docs/spec/release-process.md](docs/spec/release-process.md) | Modelo de branches (`main` + `dev`), versionamento semver dirigido pela descrição do MR, e o que entra no pacote de release |
| [docs/research/prior-art.md](docs/research/prior-art.md) | Levantamento de kits SDD (Spec Kit, Agent OS, BMAD) e de coleções de skills de Godot, com análise de lacunas |
| [docs/research/godot-constraints.md](docs/research/godot-constraints.md) | Restrições técnicas verificadas do Godot 4 que determinam o desenho: `.tscn`/`.uid`, comandos headless, exit codes, armadilhas de CI, input simulado, trabalho paralelo |

## Para que tipo de jogo

Qualquer um. Pequeno ou grande, 2D ou 3D, qualquer gênero. O kit não tem modo lite nem
blueprint de gênero: a unidade de trabalho é o **sistema**, e um jogo grande não tem specs
maiores — tem mais specs. Ver §19 da especificação.

## Em uma frase

Os kits de spec-driven existentes assumem user stories verificáveis por teste; jogos têm
**mecânicas com números de tuning e feel que nenhum teste verifica**. O kit fecha essa
distância com uma escada de verificação explícita (V0–V5), tuning como artefato de spec, e
contratos de cena declarados antes de o `.tscn` existir.

## Como trabalhamos neste repositório

Duas branches, só. `dev` é onde o trabalho acontece; `main` é a branch principal e todo
merge nela gera uma release, com o incremento (`major`/`minor`/`patch`) declarado na
descrição do merge request. Detalhes em [docs/spec/release-process.md](docs/spec/release-process.md).

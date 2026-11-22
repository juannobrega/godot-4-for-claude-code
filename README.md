# godot-4-for-claude-code

Kit de **spec-driven development** para desenvolvimento de jogos em **Godot 4** com o
Claude Code.

> **Status: especificação.** Nenhum código ainda. Estamos definindo o que o kit é.

## Documentos

| Documento | Conteúdo |
|---|---|
| [docs/spec/kit-spec.md](docs/spec/kit-spec.md) | **A especificação do kit** — tese, princípios, artefatos, escada de verificação, comandos `/godot-4:*`, skills, agentes, hooks, riscos, levantamento de MCP servers, decisões em aberto |
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

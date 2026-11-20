# Restrições técnicas do Godot 4 que o kit precisa conhecer

Fatos verificados que determinam o desenho do kit. Tudo aqui é material para virar
`references/` de skill ou script de hook.

---

## 1. Versão da engine

- **Estável atual: 4.7.2** (18/08/2026). 4.7 saiu em 18/06/2026; **4.8 está em beta**
  (beta 4 em 18/11/2026).
- A versão precisa ser **detectada e fixada**, não assumida: `config/features` no
  `project.godot` carrega a versão, e `godot --version` confirma o binário.
- Drift entre versões menores do 4.x é real (renomes de API). Um kit que escreve
  "Godot 4" sem minor version produz código que não compila.

## 2. O problema dos arquivos de cena e recurso

`.tscn`, `.tres` e `project.godot` **parecem INI editável e não são**. Quebram em silêncio
quando um agente os edita como texto puro:

| Elemento | O que quebra |
|---|---|
| `uid://...` | Dessincroniza do índice; referências apontam para o nada |
| `load_steps` | Contagem errada → falha de carregamento |
| ids de `ext_resource` / `sub_resource` | Colisão de ids |
| blocos `[node ...]` | Conexões de sinal ficam penduradas |
| overrides de cena herdada | Malformam silenciosamente |

**Edições seguras** (consenso entre os guards existentes): valores escalares de
propriedade e linhas `[connection]`. Todo o resto é cirurgia estrutural e deve passar por
guard ou pelo editor.

### `.uid` sidecars (Godot 4.4+)

- Todo script e recurso ganha um `.uid` ao lado. Agentes movem o `.gd` e esquecem o `.uid`.
- Modelos treinados antes do 4.4 **não sabem que o arquivo existe**.
- Gerar os faltantes: `godot --headless --path . --import` antes de commitar.
- **Nunca reusar um UID em outro path.**

## 3. Envenenamento de dados de treino: Godot 3 vs 4

A maior parte do GDScript indexado na web é Godot 3. Saem fluentes e quebram na hora:

| Godot 3 | Godot 4 |
|---|---|
| `yield(...)` | `await` |
| `.instance()` | `.instantiate()` |
| `export var x` | `@export var x: Type` |
| `onready var` | `@onready var` |
| `connect("sig", self, "_on")` | `sig.connect(_on)` |

Isso exige uma skill de *API guard* com tabela de tradução, não só uma linha de instrução.

## 4. Comandos de verificação — a base factual da "escada"

```bash
# Import + geração de .uid (obrigatório antes de testes: scripts com class_name
# não ficam disponíveis sem isso)
godot --headless --path . --import

# Parse/erro-only, sem executar
godot --headless --check-only -s res://script.gd

# Export
godot --headless --path . --export-release "Linux/X11" build/game

# Bot/playtest determinístico
godot --headless --path . --fixed-fps 60 --quit-after 600 -- --bot
#   --fixed-fps 60   → física/timers determinísticos entre runs
#   --quit-after N   → mata processos pendurados no CI
#   tudo após "--"   → chega via OS.get_cmdline_user_args()
```

### Frameworks de teste

```bash
# GUT (GDScript puro, roda headless sem fricção)
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/gut -gexit \
      -gjunit_xml_file=res://reports/gut-junit.xml
# exit 0 = passou (ou nenhum teste encontrado), 1 = falha

# gdUnit4 (scene runner mais rico, simula mouse/teclado/touch)
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
      -a res://tests/gdunit --ignoreHeadlessMode
# exit 0 = passou, 100 = falha, 101 = vazou nó, 103 = headless sem a flag
# relatório em reports/report_N/results.xml
```

### Armadilhas que invalidam um gate de verificação

1. **`godot` sai com código 0 depois de um `SCRIPT ERROR`.** O exit code não reflete erro
   de script. Um bot precisa chamar `get_tree().quit(1)` explicitamente ao falhar.
2. **Exit 0 com zero testes executados** passa como verde. Três causas: faltou o `--import`;
   path de testes errado; pasta de relatório inexistente. **Mitigação: validar que o JUnit
   XML existe e contém contagem de testes > 0.**
3. **`--headless` não entrega cliques a nós `Control`.** Em 4.7.2, cliques simulados chegam
   a `_input` mas não pressionam um `Button`. Teste de UI exige Xvfb.
4. **`--write-movie` exige display.** Crasha com `--headless`; use Xvfb.
5. **gdUnit4 recusa headless** (`exit 103`) sem `--ignoreHeadlessMode`.

### Lint e formatação

`gdtoolkit` 4.5.0 (2025-10-09): `gdlint` (análise estática) e `gdformat` (formatador
determinístico), config em `.gdlintrc` / `.gdformatrc`. Tem pre-commit hooks oficiais e
GitHub Action. **Ressalva registrada na comunidade em 2026: há casos de `gdformat`
produzindo código que o Godot rejeita.** Portanto `gdformat` entra sempre seguido de um
parse check, nunca sozinho.

## 5. Input simulado

```gdscript
# Evento bruto — passa por _input(), mais próximo do hardware
var key := InputEventKey.new()
key.keycode = KEY_RIGHT
key.pressed = true
Input.parse_input_event(key)

# Action-based — pula a camada _input()
Input.action_press("ui_right")
Input.action_release("ui_right")
```

GUT tem `GutInputSender` encadeável (`action_down("ui_right").hold_for(1.2).wait(0.3)`);
gdUnit4 usa esperas em milissegundos em vez de frames, porque timing de frame varia.

## 6. Agentes em paralelo no mesmo projeto

Problemas reais e as mitigações conhecidas:

| Problema | Mitigação |
|---|---|
| Conflito de arquivos, especialmente `project.godot` | `git worktree add ../proj-feat -b feat`; merge **um branch por vez**, resolvendo `project.godot` à mão e **mantendo todos os autoloads** |
| Reimport total de assets em cada checkout novo (`.godot` é gitignored) | Copiar a pasta `.godot` para o worktree |
| `user://` é nomeado pelo projeto → um run sobrescreve o save do outro | `override.cfg` com `config/custom_user_dir_name="proj-agents/feat"` por cópia |
| `.uid` faltando em scripts novos | `godot --headless --path <copy> --import` antes do commit |

## 7. Arquitetura — o que a constituição do projeto deve fixar

- **Composição sobre herança.** Cena é a unidade reutilizável: cenas pequenas de
  responsabilidade única, compostas em maiores (personagem = Hurtbox + AnimationPlayer +
  weapon mount, não um CharacterBody monolítico).
- **Autoload só para serviço global de verdade** — event bus, save manager, settings,
  transição de cena, áudio. Nunca estado por nível, por personagem, ou com múltiplas
  instâncias.
- **Sinais em vez de polling.** Se A reage a B, B emite e A conecta. Nomeação:
  substantivo + verbo no passado — `player_died`, `score_updated`, `level_loaded`.
- **Cena sem dependência externa.** Se precisar de contexto externo, injeção de dependência
  do alto nível para o baixo nível.
- **Layout de arquivos:** cena + script + assets dela na mesma pasta. `res://scripts/` só
  para o que não pertence a uma cena (utils, autoloads, classes base).
- **`%UniqueName`** em vez de path de nó.
- **Tipagem estática explícita** em todo `var`, parâmetro, retorno e coleção.

## 8. Fontes

- Spec Kit: <https://github.com/github/spec-kit> · [GitHub Blog](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/)
- Agent OS: <https://github.com/buildermethods/agent-os>
- BMAD-METHOD: <https://github.com/PavanAnganna90/BMAD-METHOD-v6>
- gg-godot: <https://github.com/Richy-was-here/gg-godot>
- godot-agent-skills: <https://github.com/Qb-Lab/godot-agent-skills>
- godot-claude-plugin: <https://github.com/iboss-ptk/godot-claude-plugin>
- godot-game-dev-studio: <https://github.com/bgrenat/godot-game-dev-studio>
- Game-Dev-Agentic-Skills: <https://github.com/thedivergentai/Game-Dev-Agentic-Skills>
- godot-claude-skills: <https://github.com/alexmeckes/godot-claude-skills>
- Godot CLI: <https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html>
- Scene organization: <https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html>
- Formato `.tscn`: <https://github.com/godotengine/godot-docs/blob/master/engine_details/file_formats/tscn.rst>
- Testes por CLI: <https://www.openredsoftware.com/blog/run-godot-unit-tests-command-line/>
- Playtest automatizado: <https://ziva.sh/blogs/godot-automated-playtesting>
- Agentes em paralelo: <https://ziva.sh/blogs/parallel-ai-agents-godot>
- UID files: <https://dev.to/ziva/godot-44-added-uid-files-everywhere-heres-what-they-actually-do-4e56>
- gdtoolkit: <https://github.com/Scony/godot-gdscript-toolkit>
- Skill authoring: <https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices>
- Plugin reference: <https://code.claude.com/docs/en/plugins-reference>

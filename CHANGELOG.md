# 0.7.0-rc.1 — Glass/dark development candidate

Added: distinct Full/Compact/Mini/Hidden, reusable speed and deferred seek, shared player state, geometry-correct two-color roll, phrase/motif performance layers, game/song settings resolution, manual calibration, queue, toasts, diagnostics sheets, clean bundled entry point, dev loader and test harness.

Fixed: offscreen window bounds, gesture ownership, hold adapter truncation at 260 ms, release scheduling at changed speed, active expressive holds after seek/resume, stale visual hand/track filtering, same-tick MIDI tempo precedence.

Removed from the new execution path: cyclic speed control, permanent ±5 s buttons, technical status wall, speculative Cloud routes, old version-to-version UI patch loading. Historical files retained; stable unchanged.

Validation: Luau regression and UI contract/layout tests passed. Roblox/device testing and live Dodo Cloud remain pending. See docs/VALIDATION.md.

---

# Changelog

## 0.6.1 - Premium Plus

### Humanização
- Corrigida a escala dupla que deixava o preset Pianist quase imperceptível.
- Humanização agora combina timing global, frase, mão, microtiming, rubato e chord roll com um único controle de intensidade.
- Presets passam a usar faixas musicais reais e separadas: Exact, Very Subtle, Natural, Pianist e Expressive.
- Estatísticas da interpretação mostram delta médio, pico e desvio de timing.
- Botão **Nova interpretação** gera uma nova seed mantendo o mesmo MIDI.

### Piano roll
- Duas cores apenas: mão esquerda em verde-água e mão direita em violeta.
- A cor de melodia não substitui mais a cor da mão.
- Ao escolher somente LH ou RH, as notas da outra mão deixam de existir na PerformanceTimeline e somem do piano roll.
- Teclas do piano visual acendem com a cor da mão no momento do ataque.
- Look-ahead reduzido para deixar microtiming e chord rolls mais legíveis.

### Interface
- Transições animadas entre Biblioteca, Player, Performance e Ajustes.
- Animações ao alternar Full, Mini e Hidden.
- Changelog interno acessível pelo botão **NEW**.
- Changelog aparece uma única vez por versão.
- Novo card de interpretação com métricas da humanização.
- Refinos de cor, gradientes e hierarquia visual.

### Dodo Cloud
- Timeout real por requisição e teto de tempo para a busca completa.
- Rotas públicas adicionais recuperadas do APK 2.3.0 são testadas de forma controlada.
- Diagnóstico informa timeout, HTTP incompatível ou resposta não suportada.
- Falha do Dodo Cloud não bloqueia MIDIs locais.

### Correções
- Duração total do scheduler agora considera a PerformanceTimeline humanizada, evitando cortar finais deslocados.
- Configurações de humanização antigas são migradas para os novos padrões na primeira execução da v0.6.1.
- Mudanças de mão/track refazem imediatamente a timeline visual e musical.

## 0.6.0 - Premium
- Nova UI mobile agrupada em 4 áreas.
- Mini-player com play/pause, tempo e seekbar.
- Piano-roll em tempo real.
- Duração das teclas baseada em NoteOff/keyReleaseTime do MIDI.
- Primeira integração experimental com Dodo Cloud.

## 0.5.1 - Expression
- Velocity mantida até a camada de input.
- Expressive Strike e duração variável de toque.

## 0.5.0 - Human Lab
- Presets e controles avançados de humanização.

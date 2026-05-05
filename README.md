# BiriApp

Guia rápido para ingestão de dados (CSV + Supabase + BGG) e operação do projeto.

## Pré-requisitos

1. Python 3
2. Pacote `requests`
3. Chaves do Supabase (URL + service role key)

Comando:

```bash
pip3 install requests
```

## Variáveis de ambiente

```bash
export SUPABASE_URL="https://SEU-PROJETO.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="SUA_SERVICE_ROLE_KEY"
export CSV_PATH="/Volumes/HD_Ext_Ital/Board/App/Biriapp/carteados.csv"
```

## Script principal (recomendado)

Arquivo:
`Biriapp/Biriapp/Support/Scripts/sync_carteados_supabase.py`

### O que ele faz

1. Lê o CSV de carteados.
2. Confere se os jogos do CSV existem no `public.games`.
3. Insere os jogos faltantes.
4. Atualiza `game_external_links` (BGG/Ludopedia/Regras/Pagat).
5. Chama a API do BGG para preencher no `games`:
- `description`
- `year_published`
- `playing_time_min`
- `min_players`
- `max_players`
- `image_url`

### Rodar com logs em tempo real

```bash
python3 -u /Volumes/HD_Ext_Ital/Board/App/Biriapp/Biriapp/Support/Scripts/sync_carteados_supabase.py
```

Comando completo (igual você já usa no terminal):

```bash
pip3 install requests
export SUPABASE_URL="https://cgggviihmznmcitwtsoa.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="SUA_SERVICE_ROLE_KEY"
export CSV_PATH="/Volumes/HD_Ext_Ital/Board/App/Biriapp/carteados.csv"
python3 -u /Volumes/HD_Ext_Ital/Board/App/Biriapp/Biriapp/Support/Scripts/sync_carteados_supabase.py
```

Esse script é idempotente: se o CSV atualizar, pode rodar de novo. Ele insere o que falta e atualiza metadados conforme a configuração (`ONLY_FILL_EMPTY`).

### Modos

Padrão (`ONLY_FILL_EMPTY=1`): só preenche campos vazios.

```bash
export ONLY_FILL_EMPTY=1
python3 -u /Volumes/HD_Ext_Ital/Board/App/Biriapp/Biriapp/Support/Scripts/sync_carteados_supabase.py
```

Forçar atualização de campos já preenchidos:

```bash
export ONLY_FILL_EMPTY=0
python3 -u /Volumes/HD_Ext_Ital/Board/App/Biriapp/Biriapp/Support/Scripts/sync_carteados_supabase.py
```

Ajustar ritmo/lote:

```bash
export BATCH_SIZE=250
export SLEEP_MS=120
python3 -u /Volumes/HD_Ext_Ital/Board/App/Biriapp/Biriapp/Support/Scripts/sync_carteados_supabase.py
```

## Scripts auxiliares

### `import_carteados_csv.py`

Carga inicial mais completa do CSV (inclui conteúdo adicional, mecânicas e legado).

```bash
python3 /Volumes/HD_Ext_Ital/Board/App/Biriapp/Biriapp/Support/Scripts/import_carteados_csv.py
```

### `backfill_games_from_bgg.py`

Backfill focado em metadados BGG direto em `games`.

```bash
python3 /Volumes/HD_Ext_Ital/Board/App/Biriapp/Biriapp/Support/Scripts/backfill_games_from_bgg.py
```

## Boas práticas

1. Sempre rodar scripts via terminal para ingestão em lote.
2. Usar `ONLY_FILL_EMPTY=1` no dia a dia.
3. Usar `ONLY_FILL_EMPTY=0` apenas quando quiser recalcular/atualizar tudo.
4. Rotacionar a `service_role key` se ela for exposta.
5. Fazer commit após cada ingestão importante (com resumo do que foi atualizado).

## GitHub (versionamento)

Fluxo sugerido:

```bash
cd /Volumes/HD_Ext_Ital/Board/App/Biriapp
git init
git add .
git commit -m "chore: initial BiriApp iOS + data sync scripts"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/SEU_REPO.git
git push -u origin main
```

Se já existir repo local, só configurar remoto e `push`.

---

Se der erro em qualquer script, copiar o traceback completo e ajustar antes de rerodar.

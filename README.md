# Proyecto Integrador de Probabilidades — Detección de incidentes de seguridad

Análisis probabilístico en R sobre un log de eventos de seguridad (`eventos_seguridad.csv`):
combinatoria, probabilidad condicional/total, Teorema de Bayes y validación por
simulación Monte Carlo.

## Estructura del proyecto

```
.
├── CLAUDE.md                 # Contexto e instrucciones del proyecto
├── bitacora.md               # Bitácora cronológica de prompts (entregable)
├── datos/
│   ├── crudos/                # Dataset original, sin modificar
│   │   └── eventos_seguridad.csv
│   └── procesados/             # Dataset limpio, generado por los scripts
│       ├── eventos_seguridad_limpio.csv
│       └── eventos_seguridad_limpio.rds
├── scripts/
│   ├── 00_configuracion.R      # Semilla, paquetes y rutas comunes
│   └── 01_limpieza_datos.R     # Carga y limpieza exhaustiva (Fase 1)
├── informes/                  # Informe final en R Markdown / Quarto (Fase 5)
└── resultados/                 # Tablas y gráficos generados en fases 2-4
```

## Requisitos

- R (>= 4.1)
- Paquetes: `tidyverse`, `lubridate`

Instalación:

```r
install.packages(c("tidyverse", "lubridate"))
```

## Cómo ejecutar

Todos los scripts asumen que el directorio de trabajo es la raíz del proyecto.

```bash
Rscript scripts/01_limpieza_datos.R
```

Esto lee `datos/crudos/eventos_seguridad.csv`, aplica la limpieza y guarda el
resultado en `datos/procesados/`.

## Reproducibilidad

Toda la aleatoriedad del proyecto (en particular la simulación Monte Carlo de
la Fase 4) usa una semilla fija definida una sola vez en
[`scripts/00_configuracion.R`](scripts/00_configuracion.R):

```r
SEMILLA_PROYECTO <- 2026
set.seed(SEMILLA_PROYECTO)
```

## Limpieza de datos (Fase 1)

Problemas detectados en `eventos_seguridad.csv` y cómo se resolvieron en
`scripts/01_limpieza_datos.R`:

| Columna | Problema | Tratamiento |
|---|---|---|
| `fecha` | 3 formatos mezclados (`YYYY/MM/DD HH:MM`, `YYYY-MM-DD`, `DD/MM/YYYY`) y vacíos | Se parsean los 3 formatos con `lubridate` y se combinan con `coalesce()`; vacíos → `NA` |
| `modulo` | Mayúsculas/minúsculas mezcladas, espacios extra, sinónimos (`database`, `authentication`) y errores de tipeo (`athu`, `ap i`, `data base`) | Se normaliza a minúsculas, se recortan espacios y se mapea a 4 categorías: `api`, `auth`, `db`, `ui` |
| `alerta` | Mezcla de `0`/`1`, `si`/`no`/`sí`, `SI`/`NO`, `true`/`false`, `yes`, `N/A` | Se normaliza a lógico `TRUE`/`FALSE`; `N/A` y vacíos → `NA` |
| `incidente_real` | Mezcla de `0`/`1`, `si`/`sí`/`no`, `?`, `unknown` | Igual que `alerta`; `?`/`unknown`/vacíos → `NA` |
| `veredicto` | Etiquetas mezcladas: `clean`/`limpio`, `malware`/`MALWARE`/`Malware`, `positivo`/`negativo`, `+`/`-` | **Se colapsa a binario** `positivo` (`malware`, `+`, `positivo`) / `negativo` (`clean`, `limpio`, `-`, `negativo`) — ver supuesto documentado abajo |
| `tam_commit` | Valores negativos (imposibles) y un valor centinela `999999` | Se marcan en `tam_commit_atipico` y se convierten a `NA` |
| `t_respuesta_h` | Texto con comillas y coma decimal (ej. `"3,9"`); algunos valores negativos | Se reemplaza `,` por `.` y se convierte a numérico; negativos se marcan en `t_respuesta_h_atipico` y se convierten a `NA` |
| `id_evento` | No es único: hay valores repetidos | No se eliminan filas; se agrega la columna `id_duplicado` para identificarlas (cada fila sigue siendo un evento/log distinto) |

### Supuestos documentados

- **`veredicto` binario**: se decidió junto con el usuario mapear todas las
  etiquetas a `positivo`/`negativo` para poder usarlo directamente como
  resultado del detector en el Teorema de Bayes de la Fase 3
  (`P(incidente | veredicto positivo)`).
- **`tam_commit` == 999999**: se trata como valor centinela de error (además
  de los negativos), ya que un tamaño de commit de ~1 millón de líneas es
  incoherente con el resto de la distribución.
- **`id_evento` duplicado**: se mantienen todas las filas (no se asume que
  sea una clave primaria limpia); se deja la columna `id_duplicado` para que
  las fases de combinatoria/probabilidad decidan si filtrar o no.

Detalle completo de decisiones y preguntas en [`bitacora.md`](bitacora.md).

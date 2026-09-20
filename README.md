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

## Fase 2 — Combinatoria y probabilidad

Script: [`scripts/02_combinatoria_probabilidad.R`](scripts/02_combinatoria_probabilidad.R)
(requiere haber corrido antes `01_limpieza_datos.R`). Resultados en `resultados/`.

### Reto 1a — Espacio de claves (ataque de fuerza bruta a `auth`)

- **Espacio muestral:** todas las contraseñas de longitud `L = 8` formadas con
  un alfabeto alfanumérico de `N = 62` caracteres (supuesto de política de
  contraseñas).
- **Técnica:** variación con repetición — importa el orden (`ab12` ≠ `12ab`)
  y hay reemplazo (un carácter puede repetirse). `VR(n, r) = n^r ≈ 2.18×10^14`.
- **Probabilidad:** cada contraseña es un resultado igual de probable, por lo
  que `P(acertar en un intento) = 1 / VR(n, r) ≈ 4.58×10^-15`.
- **Enlace con los datos:** usando el tiempo medio real de respuesta del
  módulo `auth` (≈ 6.3 h, ya limpio en Fase 1) como tiempo ilustrativo por
  intento, agotar el espacio de claves tomaría del orden de `1.6×10^11` años
  — un ejercicio de escala, no una medición real de fuerza bruta.

### Reto 1b — Espacio de logs (muestra de auditoría del módulo con más eventos)

- **Espacio muestral:** subconjuntos de tamaño `m = 3` sobre los `n = 930`
  eventos del módulo `auth` (el de mayor actividad).
- **Técnica:** combinación sin repetición — no importa el orden de la
  muestra y no se audita el mismo evento dos veces. `C(930, 3) = 133 627 360`.
- Se contrasta con la variación `V(930, 3) = 801 764 160` (si el orden de
  revisión importara, ej. un reporte secuencial).
- **Probabilidad:** `P(una muestra particular) = 1 / C(n, m) ≈ 7.48×10^-9`.

### Reto 2 — Probabilidad condicional y probabilidad total

- `P(incidente_real | alerta = TRUE) = 0.3807`
- `P(incidente_real | alerta = FALSE) = 0.0055`
  → una alerta activa multiplica por ~69 la probabilidad de que el incidente
  sea real, evidencia de que `alerta` es informativa (no independiente de
  `incidente_real`).
- Probabilidad total de incidente, partiendo el espacio muestral por
  `modulo` (partición: `api`, `auth`, `db`, `ui`):
  `P(incidente) = Σ P(incidente | modulo) · P(modulo) = 0.0562`,
  verificado contra el cálculo directo sobre los mismos datos (diferencia
  ≈ 0, solo error de punto flotante).

### Corrección a la Fase 1 detectada durante la Fase 2

Al calcular el tiempo medio de `t_respuesta_h` para el Reto 1a apareció una
media de **2143 horas**, inconsistente con los valores de una sola cifra
observados en el CSV crudo. Se encontró un segundo valor centinela no
documentado en `CLAUDE.md`: **`t_respuesta_h == 99999`** (64 filas), análogo
al `999999` de `tam_commit`. Se corrigió `01_limpieza_datos.R` para tratarlo
también como atípico → `NA` (ahora `t_respuesta_h_atipico` marca 111 filas en
vez de 47) y se volvió a generar `datos/procesados/`.

## Fase 3 — Teorema de Bayes y sensibilidad del prior

Script: [`scripts/03_bayes.R`](scripts/03_bayes.R). Resultados en `resultados/`
(`reto3_*.csv` y `fase3_sensibilidad_prior.png`).

Se define `A = incidente_real` (la creencia a actualizar) y
`B = veredicto = positivo` (la evidencia observada del detector).

- **Prior** `P(incidente_real) = 0.0562` (igual al de la Fase 2, misma base
  de datos filtrada).
- **Sensibilidad** `P(veredicto=positivo | incidente) = 0.9021` — el
  detector marca positivo el 90 % de las veces que hay un incidente real.
- **Tasa de falsos positivos** `P(veredicto=positivo | NO incidente) = 0.0654`.
- **Bayes:** `P(incidente | veredicto=positivo) = 0.451`, idéntico al valor
  calculado directo sobre los datos (diferencia ≈ 0) — confirma que la
  fórmula de Bayes es consistente con la evidencia empírica.
- `P(incidente | veredicto=negativo) = 0.0062`: un veredicto negativo baja
  la creencia de incidente por debajo del prior.
- **Interpretación:** el prior sube de `0.0562` a `0.451` al observar un
  veredicto positivo (×8), pero **sigue sin superar el 50 %** — un solo
  veredicto positivo no basta para "creer" que hay un incidente, porque el
  incidente real es raro (prior bajo) y el detector todavía genera falsos
  positivos.

### P(A|B) vs P(B|A) vs correlación

Usando `alerta` e `incidente_real` (de la Fase 2):

- `P(incidente_real | alerta=TRUE) = 0.3807`
- `P(alerta=TRUE | incidente_real) = 0.9130`
- `Correlación de Pearson(alerta, incidente_real) = 0.5567`

Los tres números son distintos y responden preguntas distintas: el primero
es "si hay alerta, ¿qué tan probable es que sea un incidente real?"
(relevante para decidir si investigar una alerta); el segundo es "si hay un
incidente real, ¿qué tan seguido se activó la alerta?" (relevante para medir
la cobertura del sistema); la correlación es una única medida simétrica de
asociación lineal que no distingue cuál variable "causa" o "predice" a la
otra.

### Análisis de sensibilidad del prior

Con la sensibilidad y la tasa de falsos positivos fijas (estimadas de los
datos), se recalculó el posterior `P(incidente | positivo)` variando el
prior entre 0.001 y 0.6 (`resultados/fase3_sensibilidad_prior.png`):

| prior | posterior |
|---|---|
| 0.01 | 0.122 |
| 0.02 | 0.220 |
| 0.0562 (observado) | 0.451 |
| 0.10 | 0.605 |
| 0.20 | 0.775 |
| 0.30 | 0.855 |
| 0.50 | 0.932 |

La curva es cóncava: el posterior es muy sensible a cambios en el prior
cuando este es bajo (el rango típico de incidentes reales), y se aplana a
medida que el prior crece. Esto muestra que la conclusión de Bayes depende
fuertemente de qué tan bien estimado esté el prior cuando los incidentes son
poco frecuentes.

## Fase 4 — Validación por simulación Monte Carlo

Script: [`scripts/04_montecarlo.R`](scripts/04_montecarlo.R) (requiere haber
corrido antes `03_bayes.R`, ya que reutiliza sus tasas estimadas y su valor
analítico de Bayes). Resultados en `resultados/reto4_*` y dos gráficos.

Se simulan casos con el mismo mecanismo asumido al aplicar Bayes: primero se
sortea si hay incidente (`Bernoulli(prior)`), y luego, condicionado a eso, si
el detector marca positivo (`Bernoulli(sensibilidad)` o
`Bernoulli(falsos positivos)`). La semilla fija (`2026`, definida en
`00_configuracion.R`) hace reproducible la simulación.

**Una corrida grande (N = 200 000):**

| cantidad | analítico | simulado | diferencia |
|---|---|---|---|
| P(incidente_real) | 0.0562 | 0.0561 | 0.0001 |
| P(veredicto = positivo) | 0.1124 | 0.1123 | 0.0002 |
| P(incidente \| positivo) | 0.4510 | 0.4520 | 0.0014 |
| P(incidente \| negativo) | 0.0062 | 0.0060 | 0.0002 |

Todas las diferencias son del orden de `10^-4`–`10^-3`, consistentes con el
error esperado de muestreo para ese tamaño de N.

**Convergencia:** graficando la estimación acumulada de
`P(incidente | positivo)` a medida que se acumulan casos simulados con
veredicto positivo, la curva se estabiliza rápido alrededor del valor
analítico (`resultados/reto4_convergencia.png`).

**Variabilidad del estimador (1000 réplicas de N = 2000 casos):**

- Media de las réplicas: `0.4508`; desviación estándar: `0.0324`.
- Intervalo 95 % (percentiles) de las réplicas: `[0.3854, 0.5128]`.
- El valor analítico (`0.4510`) cae dentro de ese intervalo, y
  `|media_réplicas − analítico| = 0.0002`, muy por debajo de `2×` el error
  estándar de la media (`0.0021`).
- `resultados/reto4_distribucion_replicas.png` muestra el histograma de las
  1000 réplicas, centrado casi exactamente en el valor analítico.

**Conclusión:** el modelo es **coherente y robusto** — la simulación Monte
Carlo reproduce los resultados del Teorema de Bayes de la Fase 3 dentro del
margen esperado por variabilidad de muestreo, tanto en una corrida grande
como en la distribución de muchas réplicas más pequeñas.

## Fase 5 — Informe final y preparación de la defensa

[`informes/informe_final.Rmd`](informes/informe_final.Rmd) consolida las
Fases 1-4 en un único documento reproducible (introducción, limpieza,
combinatoria, probabilidad, Bayes, Monte Carlo, conclusiones y un guion de
defensa con preguntas anticipadas). Lee los resultados ya generados en
`resultados/` y los datos limpios de `datos/procesados/`, así que hay que
correr los scripts 01-04 al menos una vez antes de renderizarlo.

Para generar el HTML:

```r
rmarkdown::render("informes/informe_final.Rmd")
```

(o el botón *Knit* en RStudio). Antes de entregar, reemplaza el marcador
`[Tu nombre completo aquí]` en el encabezado por tu nombre real.

Detalle completo de decisiones y preguntas en [`bitacora.md`](bitacora.md).

# Bitácora de prompts — Proyecto Integrador de Probabilidades

Registro cronológico de los prompts entregados a Claude Code durante el
desarrollo del proyecto, según lo exigido en `CLAUDE.md`.

---

## Prompt 1

**Prompt textual:**
> Realiza la fase 1 descrita en el claude.md, pregunta todo lo que necesites

**Número de prompt:** 1

**Fecha:** 2026-09-19

**Preguntas realizadas (y respuestas del usuario):**

1. *¿Qué estructura de carpetas prefieres para el proyecto en R?*
   → Convención en español (`datos/crudos`, `datos/procesados`, `scripts/`, `informes/`).
2. *¿Qué semilla aleatoria fija debo definir para todo el proyecto (reproducibilidad)?*
   → `2026` (año del dataset).
3. *La columna `veredicto` mezcla `clean`/`limpio`, `malware`/`MALWARE`, `positivo`, `negativo`, `+`, `-` y vacíos. ¿Cómo la mapeamos para las Fases 3 y 4 (Bayes)?*
   → Binaria: `positivo`/`negativo`.
4. *¿Ya tienes un repositorio remoto (GitHub/GitLab) para este proyecto?*
   → Sí: `https://github.com/frankodiazDev/ProyectoFV2`.

**Decisiones adicionales tomadas sin bloquear el avance (documentadas para revisión del usuario):**

- No se usó `renv`; las dependencias (`tidyverse`, `lubridate`) se documentan en `README.md`.
- `id_evento` no es único en los datos (139 filas con id repetido). Se optó por
  **no eliminar filas**, sino agregar una columna `id_duplicado` para que las
  fases de combinatoria/probabilidad decidan cómo tratarlas.
- `tam_commit` tiene, además de negativos, un valor centinela `999999` (17
  filas) que se trató también como dato atípico → `NA`.
- `t_respuesta_h` tiene 47 valores negativos (tiempo de respuesta no puede ser
  negativo): se marcaron como atípicos y se convirtieron a `NA`, aunque
  `CLAUDE.md` no lo pedía explícitamente para esta columna.

**Resumen de lo realizado (Fase 1):**

- Inspección exhaustiva de `eventos_seguridad.csv` (2670 filas, 8 columnas)
  antes de escribir el código de limpieza, para conocer los valores reales
  de cada columna (no solo los mencionados como ejemplo en `CLAUDE.md`).
- Estructura de carpetas creada: `datos/crudos/`, `datos/procesados/`,
  `scripts/`, `informes/`, `resultados/`.
- `datos/crudos/eventos_seguridad.csv`: dataset original copiado sin
  modificar (se corrigió solo el espacio sobrante en el nombre de archivo).
- [`scripts/00_configuracion.R`](scripts/00_configuracion.R): semilla fija
  (`SEMILLA_PROYECTO <- 2026`), carga de paquetes y rutas comunes del proyecto.
- [`scripts/01_limpieza_datos.R`](scripts/01_limpieza_datos.R): carga con
  `readr::read_csv()` y limpieza completa de las 8 columnas descritas en
  `CLAUDE.md` (fechas en 3 formatos, `modulo`, `alerta`, `incidente_real`,
  `veredicto`, `tam_commit`, `t_respuesta_h`), más las columnas auxiliares
  `id_duplicado`, `tam_commit_atipico` y `t_respuesta_h_atipico`.
- Verificación manual (con `cut`/`grep` sobre el CSV crudo) de que los
  conteos de `NA` producidos por el script coinciden exactamente con los
  valores faltantes/ambiguos reales del archivo original.
- `README.md` con la documentación de la estructura, cómo ejecutar los
  scripts y la tabla de decisiones de limpieza.
- `.gitignore` para archivos de sesión de R/RStudio.
- Repositorio Git inicializado en la raíz del proyecto, primer commit
  creado y remoto `origin` configurado apuntando a
  `https://github.com/frankodiazDev/ProyectoFV2` (sin hacer `push` todavía).

**Resultado de la limpieza (`datos/procesados/eventos_seguridad_limpio.csv`):**

- `modulo`: 4 categorías limpias (`api` 781, `auth` 930, `db` 535, `ui` 424), 0 `NA`.
- `veredicto`: `negativo` 2340, `positivo` 293, `NA` 37.
- `fecha`: 114 filas sin fecha (`NA`).
- `alerta`: 84 `NA`; `incidente_real`: 88 `NA`.
- `tam_commit`: 50 valores atípicos (negativos o `999999`) → `NA`.
- `t_respuesta_h`: 47 valores negativos → `NA`.
- `id_evento`: 139 filas con id duplicado (marcadas, no eliminadas).

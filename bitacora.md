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

---

## Prompt 2

**Prompt textual:**
> realiza la fase 2

**Número de prompt:** 2

**Fecha:** 2026-09-19

**Preguntas realizadas:** ninguna — el usuario no respondió la pregunta
pendiente sobre `git push` al cierre del Prompt 1 y pidió avanzar
directamente a la Fase 2, así que se interpretó como preferencia por avanzar
rápido. Las decisiones de diseño de esta fase (parámetros del espacio de
claves, tamaño de la muestra de auditoría) se tomaron de forma autónoma y se
documentan aquí y en `README.md` para que el usuario las revise y corrija si
lo desea.

**Decisiones/supuestos tomados sin bloquear el avance:**

- Reto 1a (espacio de claves): alfabeto alfanumérico `N = 62`, longitud
  `L = 8` (política de contraseñas típica, no viene del dataset).
- Reto 1a (enlace con los datos): se usó el tiempo medio de
  `t_respuesta_h` del módulo `auth` como tiempo ilustrativo por intento de
  fuerza bruta, dejando explícito que es un ejercicio de escala y no una
  medición real de ataque.
- Reto 1b (espacio de logs): se usó el módulo con más eventos (`auth`,
  n = 930) y un tamaño de muestra de auditoría `m = 3`, elegido como ejemplo
  razonable para ilustrar combinación vs. variación.
- Reto 2 (probabilidad total): se filtró a un único subconjunto sin `NA` en
  `modulo` ni `incidente_real` para calcular `P(modulo)` y
  `P(incidente | modulo)` sobre la misma base, de modo que la identidad de
  probabilidad total cuadre exactamente.

**Hallazgo y corrección durante esta fase:**

Al calcular el tiempo medio de `t_respuesta_h` para el Reto 1a se obtuvo una
media de 2143 horas, un valor incoherente con los datos crudos (que son de
una sola cifra). Se investigó y se encontró un **segundo valor centinela no
mencionado en `CLAUDE.md`**: `t_respuesta_h == 99999` (64 filas), análogo al
`999999` ya tratado en `tam_commit`. Se corrigió
`scripts/01_limpieza_datos.R` para tratarlo también como atípico → `NA`, se
volvió a ejecutar la Fase 1 completa y luego la Fase 2 con los datos
corregidos (tiempo medio de `auth` pasó de 2143 h a 6.33 h, un valor
coherente).

**Resumen de lo realizado (Fase 2):**

- [`scripts/02_combinatoria_probabilidad.R`](scripts/02_combinatoria_probabilidad.R):
  - Reto 1a: tamaño del espacio de claves (variación con repetición),
    probabilidad de acertar en un intento, y una estimación ilustrativa del
    tiempo para agotar el espacio usando el tiempo de respuesta real de
    `auth`.
  - Reto 1b: combinaciones y variaciones para una muestra de auditoría de
    logs del módulo con más eventos, con la probabilidad de obtener una
    muestra particular.
  - Reto 2: `P(incidente_real | alerta)` por cada valor de `alerta`, y
    probabilidad total de incidente particionando por `modulo`, verificada
    contra el cálculo directo.
- Resultados exportados a `resultados/reto1_combinatoria.csv`,
  `resultados/reto2_condicional_alerta.csv` y
  `resultados/reto2_probabilidad_total_modulo.csv`.
- README.md actualizado con la sección "Fase 2" documentando espacio
  muestral, técnica elegida, orden/reemplazo y la relación con la
  probabilidad para cada reto, según lo pedido en `CLAUDE.md`.

**Resultados numéricos clave:**

- `P(incidente_real | alerta = TRUE) = 0.3807`;
  `P(incidente_real | alerta = FALSE) = 0.0055`.
- `P(incidente)` por probabilidad total (partición por `modulo`) = `0.0562`,
  igual al cálculo directo.
- Espacio de claves `VR(62, 8) ≈ 2.18×10^14`; `C(930, 3) = 133 627 360`;
  `V(930, 3) = 801 764 160`.

---

## Prompt 3

**Prompt textual:**
> la fase 3

**Número de prompt:** 3

**Fecha:** 2026-09-19

**Preguntas realizadas:** ninguna. `CLAUDE.md` lista los sub-puntos de la
Fase 3 con contenido que en realidad corresponde a la Fase 2 (estimar
P(incidente|alerta), probabilidad total por módulo — ya hechos), y los
sub-puntos que describen Bayes y sensibilidad del prior aparecen bajo el
título "Fase 4". Se interpretó esto como un desfase de una fila en la lista
de sub-puntos del documento original (cada bloque de bullets quedó bajo el
título de la fase siguiente) y se usó el **título** de cada fase como fuente
de verdad: la Fase 3 se implementó como "Teorema de Bayes para actualizar
creencias según el veredicto del detector y análisis de sensibilidad del
prior", que es exactamente el título que le da `CLAUDE.md`. Se avanzó sin
preguntar, seguido de la preferencia de velocidad mostrada por el usuario en
el prompt anterior; si la interpretación no es la que el usuario/profesor
esperaba, es fácil de ajustar porque todo el cálculo ya está en el script.

**Resumen de lo realizado (Fase 3):**

- [`scripts/03_bayes.R`](scripts/03_bayes.R):
  - Tabla de confusión `incidente_real x veredicto` sobre las 2545 filas
    completas.
  - Estimación desde los datos de: prior `P(incidente)`, sensibilidad
    `P(positivo|incidente)` y tasa de falsos positivos `P(positivo|NO incidente)`.
  - Teorema de Bayes para `P(incidente|veredicto positivo)` y
    `P(incidente|veredicto negativo)`, cada uno verificado contra el cálculo
    directo sobre los datos (coinciden exactamente).
  - Sección explícita distinguiendo `P(incidente|alerta)` de
    `P(alerta|incidente)` y de la correlación de Pearson entre ambas
    variables, con explicación de por qué las tres difieren.
  - Análisis de sensibilidad del prior: tabla con 7 priors de referencia y
    gráfico (`resultados/fase3_sensibilidad_prior.png`) con el prior real
    marcado, mostrando que el posterior es más sensible al prior cuando este
    es bajo.
- Se corrigió un detalle visual del gráfico (etiqueta del prior se salía del
  área del panel por estar rotada) reposicionándola en horizontal.
- Resultados exportados a `resultados/reto3_tabla_confusion.csv`,
  `resultados/reto3_sensibilidad_prior.csv`, `resultados/reto3_resumen_bayes.csv`.
- README.md actualizado con la sección "Fase 3".

**Resultados numéricos clave:**

- Sensibilidad del detector = 0.9021; tasa de falsos positivos = 0.0654.
- `P(incidente | veredicto positivo) = 0.451` (vs. prior 0.0562, ×8).
- `P(incidente | veredicto negativo) = 0.0062`.
- `P(incidente|alerta) = 0.3807` ≠ `P(alerta|incidente) = 0.9130` ≠
  correlación `0.5567`.

---

## Prompt 4

**Prompt textual:**
> sí, avanza con la fase 4

**Número de prompt:** 4

**Fecha:** 2026-09-19

**Preguntas realizadas:** ninguna. Siguiendo la misma lógica de títulos
usada para la Fase 3, la Fase 4 se implementó como su título indica:
"Validación mediante simulación Monte Carlo en R contrastando los
resultados analíticos con la simulación" (los sub-puntos de simulación que
`CLAUDE.md` lista bajo "Fase 5" son, según esa misma interpretación de
desfase, el contenido real de esta fase).

**Resumen de lo realizado (Fase 4):**

- [`scripts/04_montecarlo.R`](scripts/04_montecarlo.R): lee las tasas y el
  valor analítico de Bayes desde `resultados/reto3_resumen_bayes.csv`
  (generado en la Fase 3) en vez de recalcularlos, para comparar siempre
  contra el mismo número ya documentado.
  - Simulación grande (N = 200 000) del mecanismo generador
    incidente → veredicto, comparando `P(incidente)`,
    `P(veredicto positivo)`, `P(incidente|positivo)` y
    `P(incidente|negativo)` simulados contra sus valores analíticos.
  - Gráfico de convergencia de la estimación acumulada de
    `P(incidente|positivo)` a medida que se acumulan casos simulados.
  - 1000 réplicas de N = 2000 casos para estimar la variabilidad del
    estimador Monte Carlo (media, desviación estándar, IC 95 %) y verificar
    formalmente que el valor analítico cae dentro del rango esperado por
    puro muestreo.
  - Conclusión automática (impresa en consola y guardada) de si el modelo es
    coherente, comparando la diferencia media-analítico contra 2 veces el
    error estándar de las réplicas.
- Resultados exportados a `resultados/reto4_comparacion_analitico_simulado.csv`,
  `resultados/reto4_resumen_replicas.csv`,
  `resultados/reto4_convergencia.png` y `resultados/reto4_distribucion_replicas.png`.
- README.md actualizado con la sección "Fase 4".

**Resultado:** las diferencias entre lo analítico y lo simulado fueron del
orden de `10^-4`–`10^-3`, y el valor analítico cayó dentro del intervalo de
95 % de las réplicas → el modelo se concluye **coherente y robusto**.

---

## Prompt 5

**Prompt textual:**
> avanza con la fase 5

**Número de prompt:** 5

**Fecha:** 2026-09-19

**Preguntas realizadas:** ninguna.

**Resumen de lo realizado (Fase 5):**

- [`informes/informe_final.Rmd`](informes/informe_final.Rmd): informe único
  en R Markdown que consolida introducción, Fase 1 (limpieza), Fase 2
  (combinatoria y probabilidad), Fase 3 (Bayes y sensibilidad del prior),
  Fase 4 (Monte Carlo), conclusiones generales, limitaciones/supuestos a
  defender, un **guion de defensa** con 4 preguntas anticipadas y sus
  respuestas, y la sección de reproducibilidad. Lee los resultados ya
  guardados en `resultados/*.csv` y las imágenes `resultados/*.png` en vez
  de recalcular todo, para que el informe siempre muestre exactamente los
  mismos números documentados en las fases anteriores.
- Se detectaron y corrigieron varios chunks de código R inline (`` `r ... ` ``)
  mal formados (texto literal mezclado dentro de los backticks del código),
  que habrían roto el render; se corrigieron y se verificó el HTML resultado
  con `grep` para confirmar que no quedaron fragmentos de código sin evaluar.
- Se verificó que el proyecto renderiza de extremo a extremo con
  `rmarkdown::render()` usando el pandoc incluido con la instalación local
  de RStudio (no fue necesario instalar nada adicional), generando
  `informes/informe_final.html`.
- README.md actualizado con la sección "Fase 5" y las instrucciones para
  renderizar el informe.

**Pendiente para el usuario antes de entregar:** reemplazar el marcador
`[Tu nombre completo aquí]` en el encabezado del `.Rmd` por el nombre real
del estudiante (no se adivinó un nombre a partir del usuario de Git/GitHub
para evitar poner un dato incorrecto en un documento académico).

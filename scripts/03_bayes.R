# Fase 3: Reto 3 - Teorema de Bayes para actualizar creencias segun el
# veredicto del detector, y analisis de sensibilidad del prior.
# Ejecutar desde la raiz del proyecto: Rscript scripts/03_bayes.R

source("scripts/00_configuracion.R")

datos <- read_rds(RUTA_DATOS_PROCESADOS_RDS)

# Se trabaja sobre el subconjunto sin NA en incidente_real ni veredicto, para
# que prior, sensibilidad, falsos positivos y el chequeo empirico final se
# calculen todos sobre la misma base (igual criterio que en la Fase 2).
datos_bayes <- datos |> filter(!is.na(incidente_real), !is.na(veredicto))

cat("Filas usadas para Bayes (incidente_real y veredicto no NA):", nrow(datos_bayes), "\n\n")

# =============================================================================
# 1. Estimacion de los parametros del detector a partir de la muestra
# =============================================================================
#   A = incidente_real (lo que se quiere saber)   -> creencia
#   B = veredicto == "positivo" (lo que se observa) -> evidencia del detector
#
#   Prior:        P(A)        = P(incidente_real)
#   Sensibilidad: P(B | A)    = P(veredicto = positivo | incidente_real = TRUE)
#   Falsos pos.:  P(B | !A)   = P(veredicto = positivo | incidente_real = FALSE)

tabla_confusion <- datos_bayes |> count(incidente_real, veredicto)
cat("=== Tabla de confusion incidente_real x veredicto ===\n")
print(tabla_confusion)

prior_incidente <- mean(datos_bayes$incidente_real)

sensibilidad <- datos_bayes |>
  filter(incidente_real) |>
  summarise(p = mean(veredicto == "positivo")) |>
  pull(p)

tasa_falsos_positivos <- datos_bayes |>
  filter(!incidente_real) |>
  summarise(p = mean(veredicto == "positivo")) |>
  pull(p)

cat("\nPrior P(incidente_real):", round(prior_incidente, 4), "\n")
cat("Sensibilidad P(veredicto = positivo | incidente):", round(sensibilidad, 4), "\n")
cat("Tasa de falsos positivos P(veredicto = positivo | NO incidente):", round(tasa_falsos_positivos, 4), "\n\n")

# =============================================================================
# 2. Teorema de Bayes: P(incidente | veredicto)
# =============================================================================
# P(positivo) por probabilidad total, particionando por incidente_real (TRUE/FALSE):
p_positivo <- sensibilidad * prior_incidente + tasa_falsos_positivos * (1 - prior_incidente)
p_negativo <- 1 - p_positivo

p_incidente_dado_positivo <- (sensibilidad * prior_incidente) / p_positivo
p_incidente_dado_negativo <- ((1 - sensibilidad) * prior_incidente) / p_negativo

# Chequeo: el mismo valor calculado de forma directa y empirica sobre los datos.
p_incidente_dado_positivo_directo <- datos_bayes |>
  filter(veredicto == "positivo") |>
  summarise(p = mean(incidente_real)) |>
  pull(p)

p_incidente_dado_negativo_directo <- datos_bayes |>
  filter(veredicto == "negativo") |>
  summarise(p = mean(incidente_real)) |>
  pull(p)

cat("=== Reto 3: Bayes ===\n")
cat("P(positivo) [prob. total]:", round(p_positivo, 4), "\n\n")
cat("P(incidente | veredicto = positivo) via Bayes:  ", round(p_incidente_dado_positivo, 4), "\n")
cat("P(incidente | veredicto = positivo) directo:    ", round(p_incidente_dado_positivo_directo, 4), "\n")
cat("Diferencia (debe ser ~0):", format(abs(p_incidente_dado_positivo - p_incidente_dado_positivo_directo), scientific = TRUE), "\n\n")

cat("P(incidente | veredicto = negativo) via Bayes:  ", round(p_incidente_dado_negativo, 4), "\n")
cat("P(incidente | veredicto = negativo) directo:    ", round(p_incidente_dado_negativo_directo, 4), "\n")
cat("Diferencia (debe ser ~0):", format(abs(p_incidente_dado_negativo - p_incidente_dado_negativo_directo), scientific = TRUE), "\n\n")

cat("Actualizacion de creencia: el prior P(incidente) =", round(prior_incidente, 4),
    "sube a", round(p_incidente_dado_positivo, 4), "al observar un veredicto positivo",
    "(multiplicador x", round(p_incidente_dado_positivo / prior_incidente, 1), ").\n\n")

# =============================================================================
# 3. P(A|B) vs P(B|A) vs correlacion simple (usando alerta e incidente_real)
# =============================================================================
# Se retoma la pareja alerta / incidente_real de la Fase 2 para mostrar que
# invertir el orden de condicionamiento da un numero distinto, y que ninguno
# de los dos coincide con un coeficiente de correlacion simple entre ambas
# variables binarias.

datos_alerta <- datos |> filter(!is.na(alerta), !is.na(incidente_real))

p_incidente_dado_alerta <- datos_alerta |>
  filter(alerta) |>
  summarise(p = mean(incidente_real)) |>
  pull(p)

p_alerta_dado_incidente <- datos_alerta |>
  filter(incidente_real) |>
  summarise(p = mean(alerta)) |>
  pull(p)

correlacion_alerta_incidente <- cor(as.numeric(datos_alerta$alerta), as.numeric(datos_alerta$incidente_real))

cat("=== P(A|B) vs P(B|A) vs correlacion ===\n")
cat("P(incidente_real | alerta = TRUE)   [A=incidente, B=alerta]:", round(p_incidente_dado_alerta, 4), "\n")
cat("P(alerta = TRUE   | incidente_real) [B=alerta, A=incidente]:", round(p_alerta_dado_incidente, 4), "\n")
cat("Correlacion (Pearson, variables 0/1) entre alerta e incidente_real:", round(correlacion_alerta_incidente, 4), "\n")
cat("Los 3 numeros son distintos: P(A|B) y P(B|A) responden preguntas\n",
    "diferentes (que tan confiable es la alerta vs. que tan seguido se activa\n",
    "ante un incidente real), y la correlacion es una unica medida simetrica\n",
    "de asociacion lineal que no distingue direccion de causalidad ni orden\n",
    "de condicionamiento.\n\n", sep = "")

# =============================================================================
# 4. Analisis de sensibilidad del prior
# =============================================================================
# Se fija sensibilidad y tasa de falsos positivos en los valores estimados de
# los datos, y se recalcula el posterior P(incidente | positivo) variando
# solo el prior P(incidente), para ver que tan sensible es la conclusion de
# Bayes a la creencia inicial.

posterior_dado_prior <- function(prior, sens = sensibilidad, fp = tasa_falsos_positivos) {
  p_pos <- sens * prior + fp * (1 - prior)
  (sens * prior) / p_pos
}

priors_referencia <- c(0.01, 0.02, round(prior_incidente, 4), 0.10, 0.20, 0.30, 0.50)
tabla_sensibilidad_prior <- tibble(
  prior = priors_referencia,
  posterior_incidente_dado_positivo = map_dbl(priors_referencia, posterior_dado_prior)
)

cat("=== Analisis de sensibilidad del prior ===\n")
print(tabla_sensibilidad_prior)
cat("\nCon sensibilidad y falsos positivos fijos (estimados de los datos),\n",
    "el posterior crece con el prior pero de forma NO proporcional: pasar\n",
    "de un prior de 0.01 a 0.50 (x50) no multiplica el posterior por 50,\n",
    "porque la tasa de falsos positivos domina cuando el prior es muy bajo.\n\n", sep = "")

# Grafico de sensibilidad para el informe final (Fase 5).
priors_grafico <- seq(0.001, 0.6, by = 0.001)
datos_grafico <- tibble(
  prior = priors_grafico,
  posterior = map_dbl(priors_grafico, posterior_dado_prior)
)

grafico_sensibilidad <- ggplot(datos_grafico, aes(x = prior, y = posterior)) +
  geom_line(linewidth = 1) +
  geom_vline(xintercept = prior_incidente, linetype = "dashed") +
  annotate(
    "text", x = prior_incidente + 0.015, y = 0.05,
    label = paste0("prior observado = ", round(prior_incidente, 4)),
    hjust = 0, size = 3.2
  ) +
  labs(
    title = "Sensibilidad del posterior P(incidente | veredicto positivo) al prior",
    subtitle = paste0(
      "Sensibilidad = ", round(sensibilidad, 3),
      ", tasa de falsos positivos = ", round(tasa_falsos_positivos, 3)
    ),
    x = "Prior P(incidente_real)",
    y = "Posterior P(incidente_real | veredicto positivo)"
  ) +
  theme_minimal()

ggsave("resultados/fase3_sensibilidad_prior.png", grafico_sensibilidad, width = 7, height = 5, dpi = 150)

# --- Guardado de resultados ---------------------------------------------------
write_csv(tabla_confusion, "resultados/reto3_tabla_confusion.csv")
write_csv(tabla_sensibilidad_prior, "resultados/reto3_sensibilidad_prior.csv")

resumen_bayes <- tibble(
  metrica = c(
    "prior_incidente", "sensibilidad", "tasa_falsos_positivos", "p_positivo",
    "p_incidente_dado_positivo_bayes", "p_incidente_dado_positivo_directo",
    "p_incidente_dado_negativo_bayes", "p_incidente_dado_negativo_directo",
    "p_incidente_dado_alerta", "p_alerta_dado_incidente", "correlacion_alerta_incidente"
  ),
  valor = c(
    prior_incidente, sensibilidad, tasa_falsos_positivos, p_positivo,
    p_incidente_dado_positivo, p_incidente_dado_positivo_directo,
    p_incidente_dado_negativo, p_incidente_dado_negativo_directo,
    p_incidente_dado_alerta, p_alerta_dado_incidente, correlacion_alerta_incidente
  )
)
write_csv(resumen_bayes, "resultados/reto3_resumen_bayes.csv")

cat("Resultados guardados en resultados/reto3_tabla_confusion.csv, ",
    "resultados/reto3_sensibilidad_prior.csv, ",
    "resultados/reto3_resumen_bayes.csv y ",
    "resultados/fase3_sensibilidad_prior.png\n", sep = "")

# Fase 4: validacion mediante simulacion Monte Carlo, contrastando los
# resultados analiticos de Bayes (Fase 3) con la simulacion.
# Ejecutar desde la raiz del proyecto, despues de scripts/03_bayes.R:
#   Rscript scripts/04_montecarlo.R

source("scripts/00_configuracion.R")

ruta_resumen_bayes <- "resultados/reto3_resumen_bayes.csv"
if (!file.exists(ruta_resumen_bayes)) {
  stop("Falta ", ruta_resumen_bayes, ". Ejecuta primero scripts/03_bayes.R.")
}

# Se reutilizan las tasas ya estimadas de los datos en la Fase 3 (prior,
# sensibilidad, falsos positivos) y los valores analiticos de Bayes, en vez
# de recalcularlos, para que la comparacion sea contra el MISMO numero
# analitico ya documentado en la bitacora/README.
resumen_bayes <- read_csv(ruta_resumen_bayes, show_col_types = FALSE)
obtener <- function(nombre) resumen_bayes$valor[resumen_bayes$metrica == nombre]

prior_incidente <- obtener("prior_incidente")
sensibilidad <- obtener("sensibilidad")
tasa_falsos_positivos <- obtener("tasa_falsos_positivos")
p_positivo_analitico <- obtener("p_positivo")
p_incidente_dado_positivo_analitico <- obtener("p_incidente_dado_positivo_bayes")
p_incidente_dado_negativo_analitico <- obtener("p_incidente_dado_negativo_bayes")

cat("Tasas usadas para simular (estimadas de los datos en la Fase 3):\n")
cat("  prior =", round(prior_incidente, 4),
    " sensibilidad =", round(sensibilidad, 4),
    " falsos_positivos =", round(tasa_falsos_positivos, 4), "\n\n")

# =============================================================================
# 1. Una simulacion grande: generar muchos casos con las tasas estimadas
# =============================================================================
# Cada caso simulado es independiente: primero se decide si hay incidente
# real (Bernoulli(prior)); luego, condicionado a eso, si el detector marca
# positivo (Bernoulli(sensibilidad) si hay incidente, Bernoulli(falsos
# positivos) si no lo hay). Esto reproduce exactamente el mismo mecanismo
# generador que se asumio al aplicar el teorema de Bayes en la Fase 3.
N_SIMULACION <- 200000L

incidente_sim <- rbinom(N_SIMULACION, 1, prior_incidente) == 1
prob_positivo_caso <- if_else(incidente_sim, sensibilidad, tasa_falsos_positivos)
veredicto_positivo_sim <- rbinom(N_SIMULACION, 1, prob_positivo_caso) == 1

p_incidente_sim <- mean(incidente_sim)
p_positivo_sim <- mean(veredicto_positivo_sim)
p_incidente_dado_positivo_sim <- mean(incidente_sim[veredicto_positivo_sim])
p_incidente_dado_negativo_sim <- mean(incidente_sim[!veredicto_positivo_sim])

tabla_comparacion <- tibble(
  cantidad = c(
    "P(incidente_real)",
    "P(veredicto = positivo)",
    "P(incidente_real | veredicto = positivo)",
    "P(incidente_real | veredicto = negativo)"
  ),
  analitico = c(
    prior_incidente, p_positivo_analitico,
    p_incidente_dado_positivo_analitico, p_incidente_dado_negativo_analitico
  ),
  simulado = c(
    p_incidente_sim, p_positivo_sim,
    p_incidente_dado_positivo_sim, p_incidente_dado_negativo_sim
  )
) |>
  mutate(diferencia_abs = abs(analitico - simulado))

cat("=== Reto 4: analitico vs. simulado (N =", N_SIMULACION, "casos) ===\n")
print(tabla_comparacion)
cat("\n")

# =============================================================================
# 2. Convergencia: como se estabiliza la estimacion simulada al acumular casos
# =============================================================================
# Se recorren los casos simulados en el orden en que "llegaron" y, entre los
# que el detector marco positivo, se calcula la proporcion acumulada de
# incidentes reales. Al inicio (pocos casos) la estimacion es ruidosa; a
# medida que se acumulan mas casos positivos, deberia estabilizarse cerca del
# valor analitico de Bayes.
idx_positivos <- which(veredicto_positivo_sim)
incidente_en_positivos <- incidente_sim[idx_positivos]

datos_convergencia <- tibble(
  n_positivos_acumulados = seq_along(incidente_en_positivos),
  estimacion_acumulada = cumsum(incidente_en_positivos) / seq_along(incidente_en_positivos)
)

grafico_convergencia <- ggplot(datos_convergencia, aes(x = n_positivos_acumulados, y = estimacion_acumulada)) +
  geom_line(linewidth = 0.6) +
  geom_hline(yintercept = p_incidente_dado_positivo_analitico, linetype = "dashed", color = "firebrick") +
  annotate(
    "text", x = max(datos_convergencia$n_positivos_acumulados), y = p_incidente_dado_positivo_analitico,
    label = paste0("Bayes analitico = ", round(p_incidente_dado_positivo_analitico, 4)),
    hjust = 1, vjust = -0.6, size = 3.2, color = "firebrick"
  ) +
  labs(
    title = "Convergencia de la simulacion a P(incidente | veredicto positivo)",
    x = "Casos simulados con veredicto positivo acumulados",
    y = "Estimacion acumulada de P(incidente | positivo)"
  ) +
  theme_minimal()

ggsave("resultados/reto4_convergencia.png", grafico_convergencia, width = 7, height = 5, dpi = 150)

# =============================================================================
# 3. Variabilidad del estimador Monte Carlo: muchas replicas mas pequenas
# =============================================================================
# En vez de una sola corrida grande, se repite la simulacion R_REPLICAS veces
# con un tamano de muestra mas realista (N_REPLICA), para ver que tan
# dispersa es la estimacion de una corrida "tipica" y si el valor analitico
# cae dentro del rango que produce el propio mecanismo simulado.
simular_p_incidente_dado_positivo <- function(n) {
  inc <- rbinom(n, 1, prior_incidente) == 1
  p_pos_caso <- if_else(inc, sensibilidad, tasa_falsos_positivos)
  ver_pos <- rbinom(n, 1, p_pos_caso) == 1
  if (sum(ver_pos) == 0) return(NA_real_)  # posible con N chico y prior bajo
  mean(inc[ver_pos])
}

N_REPLICA <- 2000L
R_REPLICAS <- 1000L
replicas <- map_dbl(seq_len(R_REPLICAS), ~ simular_p_incidente_dado_positivo(N_REPLICA))
replicas_validas <- replicas[!is.na(replicas)]

media_replicas <- mean(replicas_validas)
sd_replicas <- sd(replicas_validas)
error_estandar_media <- sd_replicas / sqrt(length(replicas_validas))
ic_95_replicas <- quantile(replicas_validas, c(0.025, 0.975))

cat("=== Distribucion del estimador Monte Carlo (", length(replicas_validas),
    " replicas validas de N =", N_REPLICA, " casos cada una) ===\n", sep = "")
cat("Media de las replicas:", round(media_replicas, 4), "\n")
cat("Desviacion estandar de las replicas:", round(sd_replicas, 4), "\n")
cat("Intervalo 95% (percentiles) de las replicas: [",
    round(ic_95_replicas[1], 4), ", ", round(ic_95_replicas[2], 4), "]\n", sep = "")
cat("Valor analitico de Bayes:", round(p_incidente_dado_positivo_analitico, 4), "\n")

analitico_dentro_del_ic <- p_incidente_dado_positivo_analitico >= ic_95_replicas[1] &&
  p_incidente_dado_positivo_analitico <= ic_95_replicas[2]
diferencia_media_analitico <- abs(media_replicas - p_incidente_dado_positivo_analitico)
coherente <- diferencia_media_analitico < 2 * error_estandar_media

cat("¿El valor analitico cae dentro del IC 95% de las replicas?", analitico_dentro_del_ic, "\n")
cat("|media de replicas - analitico| =", round(diferencia_media_analitico, 5),
    " vs. 2 x error estandar =", round(2 * error_estandar_media, 5), "\n")
cat("Conclusion: el modelo es", if (coherente) "COHERENTE" else "INCONSISTENTE",
    "entre la simulacion y el analisis de Bayes",
    "(la diferencia observada es", if (coherente) "menor" else "mayor",
    "a la esperada solo por variabilidad de muestreo Monte Carlo).\n\n")

grafico_replicas <- ggplot(tibble(estimacion = replicas_validas), aes(x = estimacion)) +
  geom_histogram(bins = 40, fill = "grey70", color = "white") +
  geom_vline(xintercept = p_incidente_dado_positivo_analitico, color = "firebrick", linewidth = 1) +
  annotate(
    "text", x = p_incidente_dado_positivo_analitico, y = 0,
    label = paste0("analitico = ", round(p_incidente_dado_positivo_analitico, 4)),
    hjust = -0.05, vjust = -1, size = 3.2, color = "firebrick"
  ) +
  labs(
    title = paste0("Distribucion de P(incidente | positivo) simulado en ", R_REPLICAS, " replicas"),
    subtitle = paste0("Cada replica: N = ", N_REPLICA, " casos simulados con las tasas estimadas"),
    x = "P(incidente | veredicto positivo) estimado en la replica",
    y = "Frecuencia"
  ) +
  theme_minimal()

ggsave("resultados/reto4_distribucion_replicas.png", grafico_replicas, width = 7, height = 5, dpi = 150)

# --- Guardado de resultados ---------------------------------------------------
write_csv(tabla_comparacion, "resultados/reto4_comparacion_analitico_simulado.csv")

resumen_replicas <- tibble(
  metrica = c(
    "n_simulacion_unica", "n_replica", "r_replicas",
    "media_replicas", "sd_replicas", "error_estandar_media",
    "ic95_inferior", "ic95_superior",
    "valor_analitico", "diferencia_media_analitico", "coherente"
  ),
  valor = c(
    N_SIMULACION, N_REPLICA, R_REPLICAS,
    media_replicas, sd_replicas, error_estandar_media,
    ic_95_replicas[1], ic_95_replicas[2],
    p_incidente_dado_positivo_analitico, diferencia_media_analitico, as.numeric(coherente)
  )
)
write_csv(resumen_replicas, "resultados/reto4_resumen_replicas.csv")

cat("Resultados guardados en resultados/reto4_comparacion_analitico_simulado.csv, ",
    "resultados/reto4_resumen_replicas.csv, ",
    "resultados/reto4_convergencia.png y ",
    "resultados/reto4_distribucion_replicas.png\n", sep = "")

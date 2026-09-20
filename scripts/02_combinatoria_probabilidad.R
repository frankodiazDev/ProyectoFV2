# Fase 2: Reto 1 (combinatoria para espacios de claves y logs) y
# Reto 2 (probabilidad condicional P(incidente | alerta) y probabilidad
# total por modulo).
# Ejecutar desde la raiz del proyecto: Rscript scripts/02_combinatoria_probabilidad.R

source("scripts/00_configuracion.R")

datos <- read_rds(RUTA_DATOS_PROCESADOS_RDS)

# =============================================================================
# RETO 1a. Espacio de claves (ataque de fuerza bruta contra el modulo `auth`)
# =============================================================================
#
# Espacio muestral: todas las contrasenas posibles de longitud L formadas con
#   un alfabeto de N caracteres (minusculas + mayusculas + digitos = 62).
#   Se cuenta "una contrasena" = una cadena ordenada de L caracteres.
# Tecnica: Variacion con repeticion (VR), porque:
#   - Importa el orden: "ab12" y "12ab" son contrasenas distintas.
#   - Hay reemplazo: un mismo caracter puede repetirse en varias posiciones
#     (ej. "aaaa1111" es una contrasena valida).
#   VR(n, r) = n^r
# Relacion con probabilidad: si un atacante prueba una clave al azar de forma
#   equiprobable, cada contrasena es un resultado igual de probable dentro del
#   espacio muestral, por lo que P(acertar en un intento) = 1 / VR(n, r).

ALFABETO_N <- 62L  # a-z, A-Z, 0-9 (supuesto: politica de contrasenas alfanumericas)
LONGITUD_L <- 8L   # longitud minima tipica de contrasena

espacio_claves <- ALFABETO_N^LONGITUD_L
p_acertar_un_intento <- 1 / espacio_claves

cat("=== Reto 1a: espacio de claves ===\n")
cat("Tamano del espacio de claves (VR):", format(espacio_claves, scientific = TRUE, digits = 4), "\n")
cat("P(acertar la clave en un intento al azar):", format(p_acertar_un_intento, scientific = TRUE, digits = 4), "\n")

# Enlace ilustrativo con los datos reales: si cada intento tardara lo mismo
# que el sistema tarda en promedio en procesar un evento del modulo `auth`
# (t_respuesta_h, ya limpio en Fase 1), ¿cuanto tardaria recorrer TODO el
# espacio de claves? No es una medicion real de fuerza bruta, es un ejercicio
# de escala para comparar el tamano del espacio de claves con un tiempo humano.
tiempo_medio_auth_h <- datos |>
  filter(modulo == "auth", !is.na(t_respuesta_h)) |>
  summarise(media = mean(t_respuesta_h)) |>
  pull(media)

horas_totales <- espacio_claves * tiempo_medio_auth_h
anios_totales <- horas_totales / 24 / 365.25

cat("Tiempo medio de respuesta observado en auth (horas):", round(tiempo_medio_auth_h, 2), "\n")
cat("Tiempo estimado (ilustrativo) para agotar el espacio de claves: ",
    format(anios_totales, scientific = TRUE, digits = 4), " anios\n\n", sep = "")

# =============================================================================
# RETO 1b. Espacio de logs (muestra de auditoria sobre el modulo con mas eventos)
# =============================================================================
#
# Espacio muestral: los subconjuntos de tamano m que se pueden formar a partir
#   de los n eventos (filas) registrados para el modulo con mas actividad.
#   Se cuenta "una muestra de auditoria" = un subconjunto de m eventos de log.
# Tecnica: Combinacion sin repeticion (C), porque:
#   - No importa el orden: la muestra {evento_5, evento_12, evento_30} es la
#     misma sin importar en que orden se seleccionen los eventos.
#   - No hay reemplazo: un mismo evento no puede auditarse dos veces.
#   C(n, m) = n! / (m! (n - m)!)
# Contraste: si en cambio se generara un reporte SECUENCIAL (orden de revision
#   importa) de los mismos m eventos, la tecnica correcta seria una variacion
#   sin repeticion V(n, m) = n! / (n - m)!.
# Relacion con probabilidad: al elegir una muestra de m eventos completamente
#   al azar, cada subconjunto es igual de probable, por lo que
#   P(obtener una muestra particular) = 1 / C(n, m).

conteo_por_modulo <- count(datos, modulo, sort = TRUE)
modulo_top <- conteo_por_modulo$modulo[1]
n_eventos <- conteo_por_modulo$n[1]
TAMANO_MUESTRA_M <- 3L

combinaciones <- choose(n_eventos, TAMANO_MUESTRA_M)
# V(n, m) = n * (n-1) * ... * (n-m+1). Se calcula como producto directo (no
# como factorial(n)/factorial(n-m)) porque para n ~ 900 el factorial completo
# desborda la precision numerica de double (Inf/Inf = NaN).
variaciones <- prod(n_eventos - seq_len(TAMANO_MUESTRA_M) + 1)
p_muestra_particular <- 1 / combinaciones

cat("=== Reto 1b: espacio de logs ===\n")
cat("Modulo con mas eventos:", as.character(modulo_top), "(n =", n_eventos, ")\n")
cat("Combinaciones posibles C(n, m) para m =", TAMANO_MUESTRA_M, ":",
    format(combinaciones, big.mark = ",", scientific = FALSE), "\n")
cat("Variaciones posibles V(n, m) (si importara el orden):",
    format(variaciones, big.mark = ",", scientific = FALSE), "\n")
cat("P(obtener una muestra de auditoria especifica al azar):",
    format(p_muestra_particular, scientific = TRUE, digits = 4), "\n\n")

# =============================================================================
# RETO 2. Probabilidad condicional P(incidente | alerta) y probabilidad
#         total de incidente por modulo
# =============================================================================

# --- P(incidente_real | alerta) ---------------------------------------------
# Se filtran a NA en alerta/incidente_real: no se puede condicionar sobre un
# valor desconocido.
datos_reto2_alerta <- datos |> filter(!is.na(alerta), !is.na(incidente_real))

tabla_condicional_alerta <- datos_reto2_alerta |>
  group_by(alerta) |>
  summarise(
    n = n(),
    p_incidente_dado_alerta = mean(incidente_real),
    .groups = "drop"
  )

cat("=== Reto 2: P(incidente_real | alerta) ===\n")
print(tabla_condicional_alerta)

p_incidente_si_alerta <- tabla_condicional_alerta$p_incidente_dado_alerta[tabla_condicional_alerta$alerta == TRUE]
p_incidente_no_alerta <- tabla_condicional_alerta$p_incidente_dado_alerta[tabla_condicional_alerta$alerta == FALSE]

cat("P(incidente_real | alerta = TRUE)  =", round(p_incidente_si_alerta, 4), "\n")
cat("P(incidente_real | alerta = FALSE) =", round(p_incidente_no_alerta, 4), "\n\n")

# --- Probabilidad total de incidente, partiendo por modulo -------------------
# Los 4 modulos (api, auth, db, ui) forman una particion del espacio muestral
# (todo evento pertenece a exactamente un modulo), condicion necesaria para
# aplicar el teorema de probabilidad total.
# Se usa el MISMO subconjunto filtrado tanto para P(modulo) como para
# P(incidente | modulo), para que la identidad de probabilidad total se
# cumpla de forma exacta (si se usaran subconjuntos distintos, con NA
# distintos en cada columna, la comparacion final no cuadraria).
datos_reto2_modulo <- datos |> filter(!is.na(modulo), !is.na(incidente_real))

p_modulo <- datos_reto2_modulo |>
  count(modulo) |>
  mutate(p_modulo = n / sum(n))

p_incidente_dado_modulo <- datos_reto2_modulo |>
  group_by(modulo) |>
  summarise(p_incidente_dado_modulo = mean(incidente_real), .groups = "drop")

tabla_prob_total <- p_modulo |>
  left_join(p_incidente_dado_modulo, by = "modulo") |>
  mutate(aporte = p_modulo * p_incidente_dado_modulo)

cat("=== Reto 2: probabilidad total de incidente por modulo ===\n")
print(tabla_prob_total)

p_incidente_total_calculado <- sum(tabla_prob_total$aporte)
p_incidente_directo <- mean(datos_reto2_modulo$incidente_real)

cat("P(incidente) via probabilidad total (suma por modulo):", round(p_incidente_total_calculado, 4), "\n")
cat("P(incidente) calculado directo sobre los mismos datos:  ", round(p_incidente_directo, 4), "\n")
cat("Diferencia (debe ser ~0):", format(abs(p_incidente_total_calculado - p_incidente_directo), scientific = TRUE), "\n\n")

# --- Guardado de resultados para el informe (Fase 5) -------------------------
write_csv(tabla_condicional_alerta, "resultados/reto2_condicional_alerta.csv")
write_csv(tabla_prob_total, "resultados/reto2_probabilidad_total_modulo.csv")

resumen_reto1 <- tibble(
  metrica = c(
    "alfabeto_N", "longitud_L", "espacio_claves_VR", "p_acertar_un_intento",
    "tiempo_medio_auth_h", "anios_estimados_fuerza_bruta",
    "modulo_top", "n_eventos_modulo_top", "tamano_muestra_m",
    "combinaciones_C", "variaciones_V", "p_muestra_particular"
  ),
  valor = c(
    ALFABETO_N, LONGITUD_L, espacio_claves, p_acertar_un_intento,
    tiempo_medio_auth_h, anios_totales,
    as.character(modulo_top), n_eventos, TAMANO_MUESTRA_M,
    combinaciones, variaciones, p_muestra_particular
  )
)
write_csv(resumen_reto1, "resultados/reto1_combinatoria.csv")

cat("Resultados guardados en resultados/reto1_combinatoria.csv, ",
    "resultados/reto2_condicional_alerta.csv y ",
    "resultados/reto2_probabilidad_total_modulo.csv\n", sep = "")

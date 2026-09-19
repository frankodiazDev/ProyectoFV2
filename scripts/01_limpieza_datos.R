# Carga y limpieza exhaustiva de eventos_seguridad.csv (Fase 1).
# Ejecutar desde la raiz del proyecto: Rscript scripts/01_limpieza_datos.R

source("scripts/00_configuracion.R")

# --- 1. Carga ---------------------------------------------------------------
# Marcadores de nulo detectados a mano en el CSV crudo (ademas de la celda vacia).
datos_crudos <- read_csv(
  RUTA_DATOS_CRUDOS,
  locale = locale(encoding = "UTF-8"),
  na = c("", "NA", "N/A", "?", "unknown"),
  col_types = cols(
    id_evento = col_integer(),
    fecha = col_character(),
    modulo = col_character(),
    alerta = col_character(),
    incidente_real = col_character(),
    veredicto = col_character(),
    tam_commit = col_double(),
    t_respuesta_h = col_character()
  )
)

cat("Filas leidas:", nrow(datos_crudos), "\n")

# --- 2. Funciones de limpieza por columna -----------------------------------

# fecha llega en 3 formatos mezclados: "YYYY/MM/DD HH:MM", "YYYY-MM-DD" y
# "DD/MM/YYYY". Cada parser solo tiene exito en su propio formato y devuelve
# NA en los demas casos, por lo que coalesce() se queda con el que si aplico.
parsear_fecha <- function(x) {
  coalesce(
    as_date(ymd_hm(x, quiet = TRUE)),
    as_date(ymd(x, quiet = TRUE)),
    as_date(dmy(x, quiet = TRUE))
  )
}

# alerta / incidente_real mezclan 0/1, si/no/sí, SI/NO, true/false, yes.
normalizar_booleano <- function(x) {
  x_norm <- str_squish(str_to_lower(x))
  case_when(
    x_norm %in% c("1", "si", "sí", "yes", "true") ~ TRUE,
    x_norm %in% c("0", "no", "false") ~ FALSE,
    TRUE ~ NA
  )
}

# modulo: unifica mayusculas/minusculas, espacios extra, sinonimos y errores
# de tipeo detectados en los datos ("athu", "ap i", "data base").
normalizar_modulo <- function(x) {
  x_norm <- str_squish(str_to_lower(x))
  case_when(
    x_norm %in% c("api", "ap i") ~ "api",
    x_norm %in% c("auth", "athu", "authentication") ~ "auth",
    x_norm %in% c("db", "database", "data base") ~ "db",
    x_norm == "ui" ~ "ui",
    TRUE ~ NA_character_
  )
}

# veredicto: se colapsa a binario positivo/negativo (decision documentada en
# bitacora.md) para poder usarlo directo como resultado del detector en las
# Fases 3-4 (Bayes: P(incidente | veredicto positivo)).
normalizar_veredicto <- function(x) {
  x_norm <- str_squish(str_to_lower(x))
  case_when(
    x_norm %in% c("malware", "+", "positivo") ~ "positivo",
    x_norm %in% c("clean", "limpio", "-", "negativo") ~ "negativo",
    TRUE ~ NA_character_
  )
}

# --- 3. Limpieza -------------------------------------------------------------

datos_limpios <- datos_crudos |>
  mutate(
    id_duplicado = id_evento %in% id_evento[duplicated(id_evento)],
    fecha = parsear_fecha(fecha),
    modulo = normalizar_modulo(modulo),
    alerta = normalizar_booleano(alerta),
    incidente_real = normalizar_booleano(incidente_real),
    veredicto = normalizar_veredicto(veredicto),
    # tam_commit negativo o igual a 999999 (valor centinela de error) no es un
    # tamano de commit valido: se marca como atipico y se convierte en NA.
    tam_commit_atipico = tam_commit < 0 | tam_commit == 999999,
    tam_commit = if_else(tam_commit_atipico, NA_real_, tam_commit),
    # t_respuesta_h llega como texto, a veces entre comillas con coma decimal
    # (ej. "3,9"). Un tiempo de respuesta negativo tampoco es valido.
    t_respuesta_h = as.numeric(str_replace(t_respuesta_h, ",", ".")),
    t_respuesta_h_atipico = t_respuesta_h < 0,
    t_respuesta_h = if_else(t_respuesta_h_atipico, NA_real_, t_respuesta_h)
  ) |>
  mutate(
    modulo = factor(modulo, levels = c("api", "auth", "db", "ui")),
    veredicto = factor(veredicto, levels = c("negativo", "positivo"))
  )

# --- 4. Reporte de calidad ---------------------------------------------------

cat("\n--- Resumen de valores faltantes (NA) tras la limpieza ---\n")
datos_limpios |>
  summarise(across(everything(), ~ sum(is.na(.)))) |>
  glimpse()

cat("\nid_evento duplicados (filas):", sum(datos_limpios$id_duplicado), "\n")
cat("tam_commit marcados como atipicos:", sum(datos_limpios$tam_commit_atipico, na.rm = TRUE), "\n")
cat("t_respuesta_h marcados como atipicos:", sum(datos_limpios$t_respuesta_h_atipico, na.rm = TRUE), "\n")

cat("\n--- Distribucion de modulo ---\n")
print(count(datos_limpios, modulo))

cat("\n--- Distribucion de veredicto ---\n")
print(count(datos_limpios, veredicto))

# --- 5. Guardado --------------------------------------------------------------

write_csv(datos_limpios, RUTA_DATOS_PROCESADOS_CSV)
write_rds(datos_limpios, RUTA_DATOS_PROCESADOS_RDS)

cat("\nDatos limpios guardados en:\n -", RUTA_DATOS_PROCESADOS_CSV, "\n -", RUTA_DATOS_PROCESADOS_RDS, "\n")

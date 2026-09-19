# Configuracion global del proyecto.
# Cargar siempre al inicio de cualquier script o Rmd/Qmd del proyecto:
#   source("scripts/00_configuracion.R")

# Semilla fija para que toda simulacion (Fase 4: Monte Carlo) sea reproducible.
SEMILLA_PROYECTO <- 2026
set.seed(SEMILLA_PROYECTO)

paquetes_requeridos <- c("tidyverse", "lubridate")
paquetes_faltantes <- setdiff(paquetes_requeridos, rownames(installed.packages()))
if (length(paquetes_faltantes) > 0) {
  stop(
    "Faltan paquetes por instalar: ", paste(paquetes_faltantes, collapse = ", "),
    ". Ejecuta install.packages(c(", paste0('"', paquetes_faltantes, '"', collapse = ", "), "))."
  )
}

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
})

# Rutas relativas a la raiz del proyecto (ejecutar los scripts desde ahi).
RUTA_DATOS_CRUDOS <- "datos/crudos/eventos_seguridad.csv"
RUTA_DATOS_PROCESADOS_CSV <- "datos/procesados/eventos_seguridad_limpio.csv"
RUTA_DATOS_PROCESADOS_RDS <- "datos/procesados/eventos_seguridad_limpio.rds"

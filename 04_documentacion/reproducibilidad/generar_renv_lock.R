# ============================================================
# GENERAR renv.lock DESDE EL ENTORNO R VALIDADO
# Proyecto: TESIS_SEQUIAS_UNCP_GITHUB
# ============================================================

obtener_directorio_script <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  arg_file <- grep("^--file=", args, value = TRUE)

  if (length(arg_file) > 0) {
    archivo <- sub("^--file=", "", arg_file[1])
    return(dirname(normalizePath(archivo, winslash = "/", mustWork = TRUE)))
  }

  getwd()
}

encontrar_raiz_proyecto <- function(inicio = obtener_directorio_script()) {
  marcadores <- c("01_datos", "02_scripts", "03_resultados", "04_documentacion")
  es_raiz <- function(x) all(dir.exists(file.path(x, marcadores)))

  ruta <- normalizePath(inicio, winslash = "/", mustWork = TRUE)

  repeat {
    if (es_raiz(ruta)) return(ruta)

    padre <- dirname(ruta)

    if (identical(padre, ruta)) {
      stop("No se encontró la raíz del proyecto.")
    }

    ruta <- padre
  }
}

ruta_base <- encontrar_raiz_proyecto()
setwd(ruta_base)

cat("Raíz del proyecto:", ruta_base, "\n")
cat("Versión de R:", R.version.string, "\n")
cat("Bibliotecas activas:\n")
cat(paste0(" - ", .libPaths(), collapse = "\n"), "\n\n")

if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv", repos = "https://cloud.r-project.org")
}

# Detectar dependencias usadas realmente en el repositorio.
dependencias <- renv::dependencies(
  path = ruta_base,
  progress = TRUE,
  errors = "reported"
)

paquetes <- sort(unique(na.omit(dependencias$Package)))
paquetes <- setdiff(
  paquetes,
  c(
    "base", "compiler", "datasets", "graphics", "grDevices",
    "grid", "methods", "parallel", "splines", "stats",
    "stats4", "tcltk", "tools", "utils"
  )
)

cat("\nPaquetes detectados por renv:\n")
cat(paste0(" - ", paquetes, collapse = "\n"), "\n\n")

instalados <- rownames(installed.packages())
faltantes <- setdiff(paquetes, instalados)

if (length(faltantes) > 0) {
  cat("ATENCIÓN: estos paquetes son usados por el proyecto pero no están instalados:\n")
  cat(paste0(" - ", faltantes, collapse = "\n"), "\n\n")
  stop(
    "No se generó renv.lock para evitar registrar un entorno incompleto. ",
    "Instale o ejecute primero los notebooks que requieren esos paquetes."
  )
}

# Copia de seguridad si ya existe un lockfile.
lockfile <- file.path(ruta_base, "renv.lock")

if (file.exists(lockfile)) {
  respaldo <- paste0(
    lockfile,
    ".bak_",
    format(Sys.time(), "%Y%m%d_%H%M%S")
  )
  file.copy(lockfile, respaldo, overwrite = FALSE)
  cat("Respaldo creado:", respaldo, "\n")
}

# Snapshot desde las bibliotecas R actuales.
# Esto conserva las versiones REALMENTE instaladas en el entorno validado.
renv::snapshot(
  project = ruta_base,
  library = .libPaths(),
  lockfile = lockfile,
  packages = paquetes,
  repos = getOption("repos"),
  prompt = FALSE,
  force = TRUE
)

cat("\n============================================\n")
cat("renv.lock GENERADO CORRECTAMENTE\n")
cat("============================================\n")
cat("Archivo:", lockfile, "\n")
cat("R:", R.version.string, "\n")
cat("Paquetes directos detectados:", length(paquetes), "\n")

# Verificación básica del lockfile.
lock <- renv::lockfile_read(lockfile)

cat("Paquetes registrados en lockfile:", length(lock$Packages), "\n")

if (length(lock$Packages) == 0) {
  stop("El lockfile se generó sin paquetes; revisar antes de publicarlo.")
}

cat("\nPara comprobar el estado posteriormente:\n")
cat('renv::status(project = ruta_base)\n')

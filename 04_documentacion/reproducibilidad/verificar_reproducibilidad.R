# ============================================================
# AUDITORÍA AUTOMÁTICA DE REPRODUCIBILIDAD
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

  raiz_env <- Sys.getenv("TESIS_SEQUIAS_ROOT", unset = "")
  if (nzchar(raiz_env)) {
    raiz_env <- normalizePath(raiz_env, winslash = "/", mustWork = FALSE)
    if (es_raiz(raiz_env)) return(raiz_env)
  }

  ruta <- normalizePath(inicio, winslash = "/", mustWork = TRUE)

  repeat {
    if (es_raiz(ruta)) return(ruta)

    padre <- dirname(ruta)
    if (identical(padre, ruta)) {
      stop(
        "No se encontró la raíz del proyecto. ",
        "Defina TESIS_SEQUIAS_ROOT si ejecuta el script fuera del repositorio."
      )
    }

    ruta <- padre
  }
}

ruta_base <- encontrar_raiz_proyecto()

norm <- function(...) {
  normalizePath(
    file.path(...),
    winslash = "/",
    mustWork = FALSE
  )
}

cat("Raíz del proyecto:", ruta_base, "\n\n")

# ------------------------------------------------------------
# 1. FUNCIONES AUXILIARES
# ------------------------------------------------------------

registrar <- function(
  bloque,
  categoria,
  descripcion,
  ruta_relativa,
  obligatorio = TRUE
) {
  data.frame(
    bloque = bloque,
    categoria = categoria,
    descripcion = descripcion,
    ruta_relativa = ruta_relativa,
    obligatorio = obligatorio,
    stringsAsFactors = FALSE
  )
}

registrar_alternativas <- function(
  bloque,
  categoria,
  descripcion,
  alternativas,
  obligatorio = TRUE
) {
  existe <- any(file.exists(file.path(ruta_base, alternativas)))
  elegida <- if (existe) {
    alternativas[which(file.exists(file.path(ruta_base, alternativas)))[1]]
  } else {
    paste(alternativas, collapse = " | ")
  }

  data.frame(
    bloque = bloque,
    categoria = categoria,
    descripcion = descripcion,
    ruta_relativa = elegida,
    obligatorio = obligatorio,
    existe_forzado = existe,
    stringsAsFactors = FALSE
  )
}

# ------------------------------------------------------------
# 2. INVENTARIO DE ARCHIVOS ESPERADOS
# ------------------------------------------------------------

esperados <- do.call(
  rbind,
  list(

    # Datos comunes
    registrar(
      "COMUN",
      "dato",
      "Base hidrometeorológica principal",
      "01_datos/raw/Base_Datos_Final_ETo_Pivot.csv"
    ),
    registrar(
      "COMUN",
      "dato",
      "Eventos nSPEI multiescala",
      "01_datos/procesados/eventos_nspei_todas_escalas.csv"
    ),

    # Bloque 01
    registrar(
      "01_regionalizacion",
      "notebook",
      "Regionalización hidroclimática",
      "02_scripts/01_regionalizacion/01_analisis_cluster_estaciones.ipynb"
    ),
    registrar(
      "01_regionalizacion",
      "evidencia",
      "Resumen histórico de clusters",
      "03_resultados/01_regionalizacion/tablas/resumen_clusters_ward_ORIGINAL.csv",
      FALSE
    ),
    registrar(
      "01_regionalizacion",
      "evidencia",
      "Asignación histórica de estaciones",
      "03_resultados/01_regionalizacion/tablas/estaciones_clusters_ORIGINAL.csv",
      FALSE
    ),

    # Bloque 03
    registrar(
      "03_marginales",
      "notebook",
      "Ajuste de marginales nSPEI-3",
      "02_scripts/03_marginales/03_ajuste_marginales_nspei3.ipynb"
    ),
    registrar(
      "03_marginales",
      "tabla",
      "Ajuste completo de marginales",
      "03_resultados/03_marginales/tablas/ajuste_marginales_nspei3_por_cluster.csv"
    ),
    registrar(
      "03_marginales",
      "tabla",
      "Mejores marginales",
      "03_resultados/03_marginales/tablas/mejores_marginales_nspei3_por_cluster.csv"
    ),
    registrar(
      "03_marginales",
      "tabla",
      "Tabla 10",
      "03_resultados/03_marginales/tablas/tabla_10_mejores_marginales_nspei3.csv"
    ),
    registrar(
      "03_marginales",
      "tabla",
      "Tabla 11",
      "03_resultados/03_marginales/tablas/tabla_11_marginales_duracion_nspei3.csv"
    ),
    registrar(
      "03_marginales",
      "tabla",
      "Tabla 12",
      "03_resultados/03_marginales/tablas/tabla_12_marginales_severidad_nspei3.csv"
    ),

    # Bloque 04
    registrar(
      "04_copulas",
      "notebook",
      "Ajuste de cópulas nSPEI-3",
      "02_scripts/04_copulas/04_ajuste_copulas_nspei3.ipynb"
    ),
    registrar(
      "04_copulas",
      "tabla",
      "Eventos usados en ajuste bivariado",
      "03_resultados/04_copulas/tablas/tabla_13_eventos_ajuste_bivariado_nspei3.csv"
    ),
    registrar(
      "04_copulas",
      "tabla",
      "Comparación de cópulas",
      "03_resultados/04_copulas/tablas/tabla_14_comparacion_copulas_nspei3.csv"
    ),
    registrar(
      "04_copulas",
      "tabla",
      "Cópulas seleccionadas",
      "03_resultados/04_copulas/tablas/tabla_15_copulas_seleccionadas_nspei3.csv"
    ),
    registrar(
      "04_copulas",
      "tabla",
      "Ajuste completo",
      "03_resultados/04_copulas/tablas/ajuste_copulas_nspei3_por_cluster.csv"
    ),
    registrar(
      "04_copulas",
      "tabla",
      "Mejores cópulas",
      "03_resultados/04_copulas/tablas/mejores_copulas_nspei3_por_cluster.csv"
    ),
    registrar(
      "04_copulas",
      "figura",
      "Pseudo-observaciones",
      "03_resultados/04_copulas/figuras/figura_15_pseudo_observaciones_nspei3.png"
    ),
    registrar(
      "04_copulas",
      "figura",
      "Superficies Gumbel 2D",
      "03_resultados/04_copulas/figuras/figura_16_superficies_gumbel_2d_nspei3.png"
    ),
    registrar(
      "04_copulas",
      "figura",
      "Superficie Gumbel 3D cluster 1",
      "03_resultados/04_copulas/figuras/figura_17_gumbel_3d_cluster1.html"
    ),
    registrar(
      "04_copulas",
      "figura",
      "Superficie Gumbel 3D cluster 2",
      "03_resultados/04_copulas/figuras/figura_18_gumbel_3d_cluster2.html"
    ),
    registrar(
      "04_copulas",
      "figura",
      "Superficie Gumbel 3D cluster 3",
      "03_resultados/04_copulas/figuras/figura_19_gumbel_3d_cluster3.html"
    ),

    # Bloque 05
    registrar(
      "05_periodos_retorno",
      "notebook",
      "Periodos de retorno AND/OR",
      "02_scripts/05_periodos_retorno/05_periodos_retorno_and_or_nspei3.ipynb"
    ),
    registrar(
      "05_periodos_retorno",
      "tabla",
      "Retornos completos",
      "03_resultados/05_periodos_retorno/tablas/retornos_and_or_nspei3_tres_clusters.csv"
    ),
    registrar(
      "05_periodos_retorno",
      "tabla",
      "Escenarios representativos",
      "03_resultados/05_periodos_retorno/tablas/tabla_14_escenarios_representativos_retornos.csv"
    ),
    registrar(
      "05_periodos_retorno",
      "tabla",
      "Definición probabilística",
      "03_resultados/05_periodos_retorno/tablas/tabla_15_definicion_probabilistica_retornos.csv"
    ),
    registrar(
      "05_periodos_retorno",
      "figura",
      "Retornos cluster 1",
      "03_resultados/05_periodos_retorno/figuras/figura_17_retornos_and_or_cluster1.png"
    ),
    registrar(
      "05_periodos_retorno",
      "figura",
      "Retornos cluster 2",
      "03_resultados/05_periodos_retorno/figuras/figura_18_retornos_and_or_cluster2.png"
    ),
    registrar(
      "05_periodos_retorno",
      "figura",
      "Retornos cluster 3",
      "03_resultados/05_periodos_retorno/figuras/figura_19_retornos_and_or_cluster3.png"
    ),

    # Bloque 06
    registrar(
      "06_riesgo_condicional",
      "notebook",
      "Riesgo condicional",
      "02_scripts/06_riesgo_condicional/06_riesgo_condicional_nspei3.ipynb"
    ),
    registrar(
      "06_riesgo_condicional",
      "tabla",
      "Riesgo condicional completo",
      "03_resultados/06_riesgo_condicional/tablas/riesgo_condicional_nspei3_tres_clusters.csv"
    ),
    registrar(
      "06_riesgo_condicional",
      "tabla",
      "Escenarios representativos",
      "03_resultados/06_riesgo_condicional/tablas/tabla_16_escenarios_riesgo_condicional.csv"
    ),
    registrar(
      "06_riesgo_condicional",
      "tabla",
      "Definición de probabilidades",
      "03_resultados/06_riesgo_condicional/tablas/tabla_17_definicion_probabilidades_condicionales.csv"
    ),
    registrar(
      "06_riesgo_condicional",
      "tabla",
      "Comparación de probabilidades",
      "03_resultados/06_riesgo_condicional/tablas/tabla_18_comparacion_probabilidades_condicionales.csv"
    ),
    registrar(
      "06_riesgo_condicional",
      "figura",
      "Riesgo condicional cluster 1",
      "03_resultados/06_riesgo_condicional/figuras/figura_20_riesgo_condicional_cluster1.png"
    ),
    registrar(
      "06_riesgo_condicional",
      "figura",
      "Riesgo condicional cluster 2",
      "03_resultados/06_riesgo_condicional/figuras/figura_21_riesgo_condicional_cluster2.png"
    ),
    registrar(
      "06_riesgo_condicional",
      "figura",
      "Riesgo condicional cluster 3",
      "03_resultados/06_riesgo_condicional/figuras/figura_22_riesgo_condicional_cluster3.png"
    ),

    # Bloque 07
    registrar(
      "07_montecarlo",
      "notebook",
      "Predicción Monte Carlo",
      "02_scripts/07_montecarlo/07_prediccion_montecarlo_nspei3.ipynb"
    ),
    registrar(
      "07_montecarlo",
      "tabla",
      "Base completa de simulación",
      "03_resultados/07_montecarlo/tablas/simulacion_montecarlo_nspei3_tres_clusters.csv"
    ),
    registrar(
      "07_montecarlo",
      "tabla",
      "Resumen estadístico",
      "03_resultados/07_montecarlo/tablas/tabla_19_resumen_estadistico_montecarlo.csv"
    ),
    registrar(
      "07_montecarlo",
      "tabla",
      "Probabilidades de excedencia",
      "03_resultados/07_montecarlo/tablas/tabla_20_probabilidades_excedencia_montecarlo.csv"
    ),
    registrar(
      "07_montecarlo",
      "tabla",
      "Clasificación de escenarios",
      "03_resultados/07_montecarlo/tablas/tabla_21_clasificacion_escenarios_montecarlo.csv"
    ),
    registrar(
      "07_montecarlo",
      "figura",
      "Distribución de duración",
      "03_resultados/07_montecarlo/figuras/figura_23_distribucion_duracion_montecarlo.png"
    ),
    registrar(
      "07_montecarlo",
      "figura",
      "Distribución de severidad",
      "03_resultados/07_montecarlo/figuras/figura_24_distribucion_severidad_montecarlo.png"
    ),
    registrar(
      "07_montecarlo",
      "figura",
      "Proporción de escenarios",
      "03_resultados/07_montecarlo/figuras/figura_25_proporcion_escenarios_montecarlo.png"
    ),
    registrar(
      "07_montecarlo",
      "figura",
      "Escenarios sintéticos",
      "03_resultados/07_montecarlo/figuras/figura_26_escenarios_sinteticos_montecarlo.png"
    )
  )
)

# Bloque 02: se permiten dos nombres durante la transición.
b2 <- registrar_alternativas(
  "02_nspei_eventos",
  "notebook",
  "nSPEI multiescala y eventos",
  c(
    "02_scripts/02_nspei_eventos/02_nspei_eventos_por_estacion_y_cluster.ipynb",
    "02_scripts/02_nspei_eventos/02_nspei_eventos_por_estacion_y_cluster_TESIS.ipynb"
  )
)

# Asegurar columna auxiliar homogénea.
esperados$existe_forzado <- NA
esperados <- rbind(esperados, b2)

# ------------------------------------------------------------
# 3. COMPROBAR EXISTENCIA
# ------------------------------------------------------------

esperados$ruta_absoluta <- file.path(ruta_base, esperados$ruta_relativa)

esperados$existe <- ifelse(
  is.na(esperados$existe_forzado),
  file.exists(esperados$ruta_absoluta),
  esperados$existe_forzado
)

esperados$tamano_bytes <- ifelse(
  esperados$existe & file.exists(esperados$ruta_absoluta),
  file.info(esperados$ruta_absoluta)$size,
  NA_real_
)

esperados$estado <- ifelse(
  esperados$existe,
  "OK",
  ifelse(esperados$obligatorio, "FALTA", "OPCIONAL_NO_ENCONTRADO")
)

# ------------------------------------------------------------
# 4. INVENTARIO DE RESULTADOS EXISTENTES
# ------------------------------------------------------------

rutas_resultados <- c(
  "03_resultados/01_regionalizacion",
  "03_resultados/02_nspei_eventos",
  "03_resultados/03_marginales",
  "03_resultados/04_copulas",
  "03_resultados/05_periodos_retorno",
  "03_resultados/06_riesgo_condicional",
  "03_resultados/07_montecarlo"
)

inventario_lista <- lapply(rutas_resultados, function(rel) {
  ruta <- file.path(ruta_base, rel)

  if (!dir.exists(ruta)) {
    return(data.frame(
      bloque = basename(rel),
      archivo = NA_character_,
      extension = NA_character_,
      tamano_bytes = NA_real_,
      stringsAsFactors = FALSE
    ))
  }

  arch <- list.files(
    ruta,
    recursive = TRUE,
    full.names = TRUE
  )

  if (length(arch) == 0) {
    return(data.frame(
      bloque = basename(rel),
      archivo = NA_character_,
      extension = NA_character_,
      tamano_bytes = NA_real_,
      stringsAsFactors = FALSE
    ))
  }

  info <- file.info(arch)

  data.frame(
    bloque = basename(rel),
    archivo = substring(
      normalizePath(arch, winslash = "/", mustWork = FALSE),
      nchar(normalizePath(ruta, winslash = "/", mustWork = FALSE)) + 2
    ),
    extension = tools::file_ext(arch),
    tamano_bytes = info$size,
    stringsAsFactors = FALSE
  )
})

inventario <- do.call(rbind, inventario_lista)

# ------------------------------------------------------------
# 5. RESUMEN
# ------------------------------------------------------------

obligatorios <- esperados[esperados$obligatorio, , drop = FALSE]
faltantes <- obligatorios[!obligatorios$existe, , drop = FALSE]

resumen_bloques <- aggregate(
  existe ~ bloque,
  data = obligatorios,
  FUN = function(x) c(
    verificados = sum(x),
    presentes = sum(x),
    faltantes = sum(!x)
  )
)

# Resumen más simple para consola.
bloques <- unique(obligatorios$bloque)

cat("============================================\n")
cat("AUDITORÍA DE ARCHIVOS OBLIGATORIOS\n")
cat("============================================\n")

for (b in bloques) {
  sub <- obligatorios[obligatorios$bloque == b, ]
  cat(
    sprintf(
      "%-24s  %3d/%3d presentes\n",
      b,
      sum(sub$existe),
      nrow(sub)
    )
  )
}

cat("--------------------------------------------\n")
cat("Total obligatorio:", nrow(obligatorios), "\n")
cat("Presentes:", sum(obligatorios$existe), "\n")
cat("Faltantes:", nrow(faltantes), "\n")

if (nrow(faltantes) == 0) {
  cat("\nRESULTADO: AUDITORÍA ESTRUCTURAL APROBADA\n")
} else {
  cat("\nRESULTADO: AUDITORÍA ESTRUCTURAL PENDIENTE\n")
  cat("\nArchivos faltantes:\n")
  print(
    faltantes[, c(
      "bloque",
      "categoria",
      "descripcion",
      "ruta_relativa"
    )],
    row.names = FALSE
  )
}

# ------------------------------------------------------------
# 6. GUARDAR REPORTES
# ------------------------------------------------------------

ruta_auditoria <- file.path(
  ruta_base,
  "04_documentacion",
  "reproducibilidad"
)

dir.create(
  ruta_auditoria,
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  esperados[, c(
    "bloque",
    "categoria",
    "descripcion",
    "ruta_relativa",
    "obligatorio",
    "existe",
    "tamano_bytes",
    "estado"
  )],
  file.path(ruta_auditoria, "AUDITORIA_ARCHIVOS.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  inventario,
  file.path(
    ruta_auditoria,
    "AUDITORIA_INVENTARIO_RESULTADOS.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

lineas_resumen <- c(
  "AUDITORÍA FINAL DE REPRODUCIBILIDAD",
  paste("Fecha:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "Raíz: detectada automáticamente",
  "",
  paste("Archivos obligatorios:", nrow(obligatorios)),
  paste("Presentes:", sum(obligatorios$existe)),
  paste("Faltantes:", nrow(faltantes)),
  "",
  if (nrow(faltantes) == 0) {
    "RESULTADO: AUDITORÍA ESTRUCTURAL APROBADA"
  } else {
    "RESULTADO: AUDITORÍA ESTRUCTURAL PENDIENTE"
  }
)

if (nrow(faltantes) > 0) {
  lineas_resumen <- c(
    lineas_resumen,
    "",
    "FALTANTES:",
    paste0(
      faltantes$bloque,
      " | ",
      faltantes$descripcion,
      " | ",
      faltantes$ruta_relativa
    )
  )
}

writeLines(
  lineas_resumen,
  con = file.path(ruta_auditoria, "AUDITORIA_RESUMEN.txt"),
  useBytes = TRUE
)

cat("\nReportes guardados en:\n")
cat(ruta_auditoria, "\n")

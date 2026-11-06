if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  tidyverse,
  janitor,
  lmomco,
  copula,
  VineCopula,
  ggpubr
)
ruta_base <- "/Volumes/USB/PROYECTO_SEQUIAS_COPULAS_UNCP"

ruta_procesados <- file.path(ruta_base, "DATOS", "PROCESADOS")
ruta_tablas     <- file.path(ruta_base, "RESULTADOS", "TABLAS")
ruta_figuras    <- file.path(ruta_base, "RESULTADOS", "FIGURAS")

archivo_eventos <- file.path(ruta_procesados, "eventos_nspei_todas_escalas_clasificados.csv")
eventos <- read.csv(archivo_eventos, stringsAsFactors = FALSE) %>%
  clean_names() %>%
  mutate(
    fecha_inicio = as.Date(fecha_inicio),
    fecha_fin = as.Date(fecha_fin),
    cluster_ward = as.factor(cluster_ward)
  )

eventos_3 <- eventos %>%
  filter(escala == "nspei_3")

table(eventos_3$cluster_ward)
pseudo_obs_marginales <- function(datos, dist_d, dist_s) {
  
  d <- as.numeric(datos$duracion)
  s <- as.numeric(datos$severidad)
  
  d <- d[is.finite(d) & d > 0]
  s <- s[is.finite(s) & s > 0]
  
  if (length(d) != length(s)) {
    stop("DuraciÃ³n y severidad no tienen la misma longitud.")
  }
  
  lmr_d <- lmoms(d)
  lmr_s <- lmoms(s)
  
  par_d <- lmom2par(lmr_d, type = dist_d)
  par_s <- lmom2par(lmr_s, type = dist_s)
  
  u <- plmomco(d, par_d)
  v <- plmomco(s, par_s)
  
  u <- pmin(pmax(u, 1e-6), 1 - 1e-6)
  v <- pmin(pmax(v, 1e-6), 1 - 1e-6)
  
  tibble(
    duracion = d,
    severidad = s,
    u = u,
    v = v
  )
}
ajustar_copulas_candidatas <- function(u, v) {
  
  uv <- cbind(u, v)
  
  resultados <- tibble()
  modelos <- list()
  
  # Clayton
  try({
    fit <- fitCopula(claytonCopula(dim = 2), uv, method = "ml")
    loglik <- as.numeric(logLik(fit))
    k <- length(coef(fit))
    resultados <- bind_rows(resultados, tibble(
      familia = "Clayton",
      loglik = loglik,
      AIC = 2*k - 2*loglik,
      BIC = log(nrow(uv))*k - 2*loglik,
      parametro = paste(round(coef(fit), 4), collapse = ", ")
    ))
    modelos[["Clayton"]] <- fit
  }, silent = TRUE)
  
  # Frank
  try({
    fit <- fitCopula(frankCopula(dim = 2), uv, method = "ml")
    loglik <- as.numeric(logLik(fit))
    k <- length(coef(fit))
    resultados <- bind_rows(resultados, tibble(
      familia = "Frank",
      loglik = loglik,
      AIC = 2*k - 2*loglik,
      BIC = log(nrow(uv))*k - 2*loglik,
      parametro = paste(round(coef(fit), 4), collapse = ", ")
    ))
    modelos[["Frank"]] <- fit
  }, silent = TRUE)
  
  # Gumbel
  try({
    fit <- fitCopula(gumbelCopula(dim = 2), uv, method = "ml")
    loglik <- as.numeric(logLik(fit))
    k <- length(coef(fit))
    resultados <- bind_rows(resultados, tibble(
      familia = "Gumbel",
      loglik = loglik,
      AIC = 2*k - 2*loglik,
      BIC = log(nrow(uv))*k - 2*loglik,
      parametro = paste(round(coef(fit), 4), collapse = ", ")
    ))
    modelos[["Gumbel"]] <- fit
  }, silent = TRUE)
  
  # Gaussian
  try({
    fit <- fitCopula(normalCopula(dim = 2), uv, method = "ml")
    loglik <- as.numeric(logLik(fit))
    k <- length(coef(fit))
    resultados <- bind_rows(resultados, tibble(
      familia = "Gaussian",
      loglik = loglik,
      AIC = 2*k - 2*loglik,
      BIC = log(nrow(uv))*k - 2*loglik,
      parametro = paste(round(coef(fit), 4), collapse = ", ")
    ))
    modelos[["Gaussian"]] <- fit
  }, silent = TRUE)
  
  # t-Student
  try({
    fit <- fitCopula(tCopula(dim = 2, dispstr = "un"), uv, method = "ml")
    loglik <- as.numeric(logLik(fit))
    k <- length(coef(fit))
    resultados <- bind_rows(resultados, tibble(
      familia = "t-Student",
      loglik = loglik,
      AIC = 2*k - 2*loglik,
      BIC = log(nrow(uv))*k - 2*loglik,
      parametro = paste(round(coef(fit), 4), collapse = ", ")
    ))
    modelos[["t-Student"]] <- fit
  }, silent = TRUE)
  
  resultados <- resultados %>% arrange(AIC)
  
  list(tabla = resultados, modelos = modelos)
}
datos_c1 <- eventos_3 %>%
  filter(as.character(cluster_ward) == "1")

pseudo_c1 <- pseudo_obs_marginales(
  datos = datos_c1,
  dist_d = "wei", # la wei quiere decir que la duraciÃ³n se ajusta a una distribuciÃ³n Weibull
  dist_s = "pe3" # pe3 quiere decir que la severidad se ajusta a una distribuciÃ³n Pearson tipo III
)

head(pseudo_c1)
ggplot(pseudo_c1, aes(x = u, y = v)) +
  geom_point(alpha = 0.5) +
  theme_minimal() +
  labs(
    title = "Pseudo-observaciones - Cluster 1",
    x = "u = F_D(d)",
    y = "v = F_S(s)"
  )
cop_c1 <- ajustar_copulas_candidatas(pseudo_c1$u, pseudo_c1$v)
cop_c1$tabla




datos_c2 <- eventos_3 %>%
  filter(as.character(cluster_ward) == "2")

pseudo_c2 <- pseudo_obs_marginales(
  datos = datos_c2,
  dist_d = "wei",
  dist_s = "pe3"
)

dim(pseudo_c2)
head(pseudo_c2)
cop_c2 <- ajustar_copulas_candidatas(pseudo_c2$u, pseudo_c2$v)
cop_c2$tabla
ggplot(pseudo_c2, aes(x = u, y = v)) +
  geom_point(alpha = 0.5) +
  theme_minimal() +
  labs(
    title = "Pseudo-observaciones - Cluster 2",
    x = "u = F_D(d)",
    y = "v = F_S(s)"
  )
write.csv(
  cop_c2$tabla,
  file.path(ruta_tablas, "ajuste_copulas_cluster2_nspei3.csv"),
  row.names = FALSE
)
p_pseudo_c2 <- ggplot(pseudo_c2, aes(x = u, y = v)) +
  geom_point(alpha = 0.5) +
  theme_minimal() +
  labs(
    title = "Pseudo-observaciones - Cluster 2",
    x = "u = F_D(d)",
    y = "v = F_S(s)"
  )

ggsave(
  file.path(ruta_figuras, "pseudo_obs_cluster2_nspei3.png"),
  plot = p_pseudo_c2,
  width = 7,
  height = 6,
  dpi = 300
)
summary(pseudo_c2$u)
summary(pseudo_c2$v)
sum(is.na(pseudo_c2$u))
sum(is.na(pseudo_c2$v))
datos_c3 <- eventos_3 %>%
  filter(as.character(cluster_ward) == "3")

pseudo_c3 <- pseudo_obs_marginales(
  datos = datos_c3,
  dist_d = "pe3",
  dist_s = "pe3"
)

head(pseudo_c3)
dim(pseudo_c3)
summary(pseudo_c3$u)
summary(pseudo_c3$v)
sum(is.na(pseudo_c3$u))
sum(is.na(pseudo_c3$v))
p_pseudo_c3 <- ggplot(pseudo_c3, aes(x = u, y = v)) +
  geom_point(alpha = 0.5) +
  theme_minimal() +
  labs(
    title = "Pseudo-observaciones - Cluster 3",
    x = "u = F_D(d)",
    y = "v = F_S(s)"
  )

p_pseudo_c3
cop_c3 <- ajustar_copulas_candidatas(pseudo_c3$u, pseudo_c3$v)

if (is.null(cop_c3) || nrow(cop_c3$tabla) == 0) {
  stop("No se pudo ajustar ninguna cÃ³pula para Cluster 3.")
}

cop_c3$tabla
mejor_cop_c3 <- cop_c3$tabla %>%
  slice_min(order_by = AIC, n = 1, with_ties = FALSE)

mejor_cop_c3
write.csv(
  cop_c3$tabla,
  file.path(ruta_tablas, "ajuste_copulas_cluster3_nspei3.csv"),
  row.names = FALSE
)

ggsave(
  file.path(ruta_figuras, "pseudo_obs_cluster3_nspei3.png"),
  plot = p_pseudo_c3,
  width = 7,
  height = 6,
  dpi = 300
)
tabla_copulas <- bind_rows(
  cop_c1$tabla %>% mutate(cluster = "1"),
  cop_c2$tabla %>% mutate(cluster = "2"),
  cop_c3$tabla %>% mutate(cluster = "3")
) %>%
  select(cluster, everything()) %>%
  arrange(cluster, AIC)

tabla_copulas
mejores_copulas <- tabla_copulas %>%
  group_by(cluster) %>%
  slice_min(order_by = AIC, n = 1, with_ties = FALSE) %>%
  ungroup()

mejores_copulas
write.csv(
  tabla_copulas,
  file.path(ruta_tablas, "ajuste_copulas_nspei3_por_cluster.csv"),
  row.names = FALSE
)

write.csv(
  mejores_copulas,
  file.path(ruta_tablas, "mejores_copulas_nspei3_por_cluster.csv"),
  row.names = FALSE
)
ggplot(tabla_copulas, aes(x = familia, y = AIC, fill = cluster)) +
  geom_col(position = "dodge") +
  theme_minimal() +
  labs(
    title = "ComparaciÃ³n de AIC por familia de cÃ³pula y cluster",
    x = "Familia de cÃ³pula",
    y = "AIC",
    fill = "Cluster"
  )
ggsave(
  file.path(ruta_figuras, "comparacion_aic_copulas_por_cluster.png"),
  width = 10,
  height = 6,
  dpi = 300
)
library(copula)
library(tidyverse)

W_frechet <- function(u, v) pmax(u + v - 1, 0)
M_frechet <- function(u, v) pmin(u, v)
Pi_indep   <- function(u, v) u * v

gumbel_fun <- function(u, v, theta) {
  exp(-(((-log(u))^theta + (-log(v))^theta)^(1/theta)))
}
grid_uv <- expand.grid(
  u = seq(0.001, 0.999, length.out = 100),
  v = seq(0.001, 0.999, length.out = 100)
)
theta_c1 <- 2.8444

grid_c1 <- grid_uv %>%
  mutate(
    W = W_frechet(u, v),
    M = M_frechet(u, v),
    Pi = Pi_indep(u, v),
    Gumbel = gumbel_fun(u, v, theta_c1)
  )
ggplot(grid_c1, aes(x = u, y = v)) +
  geom_contour(aes(z = W, color = "Cota inferior W"), bins = 8, linewidth = 0.7) +
  geom_contour(aes(z = Pi, color = "Independencia Î "), bins = 8, linewidth = 0.7) +
  geom_contour(aes(z = M, color = "Cota superior M"), bins = 8, linewidth = 0.7) +
  geom_contour(aes(z = Gumbel, color = "Gumbel ajustada"), bins = 8, linewidth = 1) +
  theme_minimal() +
  labs(
    title = "Cluster 1: CÃ³pula de Gumbel y cotas de FrÃ©chetâ€“Hoeffding",
    subtitle = "Î¸ = 2.8444",
    x = "u",
    y = "v",
    color = "Superficie"
  )
theta_c2 <- 2.8306

grid_c2 <- grid_uv %>%
  mutate(
    W = W_frechet(u, v),
    M = M_frechet(u, v),
    Pi = Pi_indep(u, v),
    Gumbel = gumbel_fun(u, v, theta_c2)
  )
ggplot(grid_c2, aes(x = u, y = v)) +
  geom_contour(aes(z = W, color = "Cota inferior W"), bins = 8, linewidth = 0.7) +
  geom_contour(aes(z = Pi, color = "Independencia Î "), bins = 8, linewidth = 0.7) +
  geom_contour(aes(z = M, color = "Cota superior M"), bins = 8, linewidth = 0.7) +
  geom_contour(aes(z = Gumbel, color = "Gumbel ajustada"), bins = 8, linewidth = 1) +
  theme_minimal() +
  labs(
    title = "Cluster 2: CÃ³pula de Gumbel y cotas de FrÃ©chetâ€“Hoeffding",
    subtitle = "Î¸ = 2.8306",
    x = "u",
    y = "v",
    color = "Superficie"
  )
theta_c3 <- 3.3715

grid_c3 <- grid_uv %>%
  mutate(
    W = W_frechet(u, v),
    M = M_frechet(u, v),
    Pi = Pi_indep(u, v),
    Gumbel = gumbel_fun(u, v, theta_c3)
  )
ggplot(grid_c3, aes(x = u, y = v)) +
  geom_contour(aes(z = W, color = "Cota inferior W"), bins = 8, linewidth = 0.7) +
  geom_contour(aes(z = Pi, color = "Independencia Î "), bins = 8, linewidth = 0.7) +
  geom_contour(aes(z = M, color = "Cota superior M"), bins = 8, linewidth = 0.7) +
  geom_contour(aes(z = Gumbel, color = "Gumbel ajustada"), bins = 8, linewidth = 1) +
  theme_minimal() +
  labs(
    title = "Cluster 3: CÃ³pula de Gumbel y cotas de FrÃ©chetâ€“Hoeffding",
    subtitle = "Î¸ = 3.3715",
    x = "u",
    y = "v",
    color = "Superficie"
  )
grid_all <- bind_rows(
  grid_c1 %>% mutate(cluster = "Cluster 1 (Î¸ = 2.8444)"),
  grid_c2 %>% mutate(cluster = "Cluster 2 (Î¸ = 2.8306)"),
  grid_c3 %>% mutate(cluster = "Cluster 3 (Î¸ = 3.3715)")
)
ggplot(grid_all, aes(x = u, y = v)) +
  geom_contour(aes(z = W, color = "Cota inferior W"), bins = 8, linewidth = 0.6) +
  geom_contour(aes(z = Pi, color = "Independencia Î "), bins = 8, linewidth = 0.6) +
  geom_contour(aes(z = M, color = "Cota superior M"), bins = 8, linewidth = 0.6) +
  geom_contour(aes(z = Gumbel, color = "Gumbel ajustada"), bins = 8, linewidth = 0.9) +
  facet_wrap(~cluster, ncol = 3) +
  theme_minimal() +
  labs(
    title = "ComparaciÃ³n de la cÃ³pula de Gumbel ajustada con las cotas de FrÃ©chetâ€“Hoeffding",
    x = "u",
    y = "v",
    color = "Superficie"
  )
library(tidyverse)
library(ggplot2)

gumbel_fun <- function(u, v, theta) {
  exp(-(((-log(u))^theta + (-log(v))^theta)^(1/theta)))
}

crear_superficie_gumbel <- function(theta, cluster_label) {
  expand.grid(
    u = seq(0.001, 0.999, length.out = 150),
    v = seq(0.001, 0.999, length.out = 150)
  ) %>%
    as_tibble() %>%
    mutate(
      C = gumbel_fun(u, v, theta),
      cluster = cluster_label
    )
}
surf_c1 <- crear_superficie_gumbel(2.8444, "Cluster 1")
surf_c2 <- crear_superficie_gumbel(2.8306, "Cluster 2")
surf_c3 <- crear_superficie_gumbel(3.3715, "Cluster 3")

surf_all <- bind_rows(surf_c1, surf_c2, surf_c3)

pseudo_all <- bind_rows(
  pseudo_c1 %>% mutate(cluster = "Cluster 1"),
  pseudo_c2 %>% mutate(cluster = "Cluster 2"),
  pseudo_c3 %>% mutate(cluster = "Cluster 3")
)
p_gumbel_pseudo <- ggplot() +
  geom_raster(
    data = surf_all,
    aes(x = u, y = v, fill = C),
    interpolate = TRUE,
    alpha = 0.9
  ) +
  geom_contour(
    data = surf_all,
    aes(x = u, y = v, z = C),
    color = "white",
    bins = 6,
    linewidth = 0.35,
    alpha = 0.8
  ) +
  geom_point(
    data = pseudo_all,
    aes(x = u, y = v),
    color = "black",
    alpha = 0.35,
    size = 0.9
  ) +
  facet_wrap(~cluster, ncol = 3) +
  coord_equal() +
  scale_fill_viridis_c(option = "C", name = "C(u,v)") +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold"),
    legend.position = "right"
  ) +
  labs(
    title = "CÃ³pula de Gumbel ajustada y pseudo-observaciones por cluster",
    subtitle = "Escala nSPEI-3",
    x = "u = F_D(d)",
    y = "v = F_S(s)"
  )

p_gumbel_pseudo
# =========================================================
# FIGURAS PROFESIONALES 2D Y 3D DE LA CÃ“PULA DE GUMBEL
# =========================================================

# ---------------------------
# 1. LIBRERÃAS
# ---------------------------
if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  tidyverse,
  patchwork,
  plotly,
  htmlwidgets,
  viridisLite
)

# ---------------------------
# 2. FUNCIONES AUXILIARES
# ---------------------------
gumbel_fun <- function(u, v, theta) {
  exp(-(((-log(u))^theta + (-log(v))^theta)^(1/theta)))
}

crear_superficie_gumbel <- function(theta, cluster_label, n_grid = 180) {
  expand.grid(
    u = seq(0.001, 0.999, length.out = n_grid),
    v = seq(0.001, 0.999, length.out = n_grid)
  ) %>%
    as_tibble() %>%
    mutate(
      C = gumbel_fun(u, v, theta),
      cluster = cluster_label
    )
}

# Tema elegante tipo paper
theme_q1 <- function() {
  theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(face = "bold", size = 18, hjust = 0.5),
      plot.subtitle = element_text(size = 12, hjust = 0.5, colour = "#444444"),
      strip.text = element_text(face = "bold", size = 13),
      axis.title = element_text(face = "bold", size = 13),
      axis.text = element_text(size = 11, colour = "#333333"),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "#D9D9D9", linewidth = 0.25),
      panel.background = element_rect(fill = "white", colour = NA),
      plot.background = element_rect(fill = "white", colour = NA),
      legend.position = "right",
      legend.title = element_text(face = "bold", size = 12),
      legend.text = element_text(size = 11),
      strip.background = element_rect(fill = "#F3F3F3", colour = NA)
    )
}

# Figura 2D individual por cluster
plot_copula_2d <- function(surface_df, pseudo_df, theta, cluster_label) {
  ggplot() +
    geom_raster(
      data = surface_df,
      aes(x = u, y = v, fill = C),
      interpolate = TRUE
    ) +
    geom_contour(
      data = surface_df,
      aes(x = u, y = v, z = C),
      colour = "white",
      bins = 7,
      linewidth = 0.45,
      alpha = 0.9
    ) +
    geom_point(
      data = pseudo_df,
      aes(x = u, y = v),
      shape = 21,
      size = 1.7,
      stroke = 0.25,
      fill = "black",
      colour = "black",
      alpha = 0.40
    ) +
    coord_equal(expand = FALSE) +
    scale_fill_gradientn(
      colours = rev(viridisLite::magma(256)),
      name = expression(C(u,v)),
      breaks = c(0.25, 0.50, 0.75),
      labels = c("0.25", "0.50", "0.75")
    ) +
    labs(
      title = cluster_label,
      subtitle = paste0(expression(theta), " = ", round(theta, 4)),
      x = "u = F[D](d)",
      y = "v = F[S](s)"
    ) +
    theme_q1() +
    theme(
      legend.position = "none",
      plot.title = element_text(size = 15),
      plot.subtitle = element_text(size = 11)
    )
}

# Figura 3D individual por cluster
plot_copula_3d <- function(surface_df, pseudo_df, theta, cluster_label) {
  # malla para plotly
  u_vals <- sort(unique(surface_df$u))
  v_vals <- sort(unique(surface_df$v))
  z_mat  <- matrix(surface_df$C, nrow = length(u_vals), ncol = length(v_vals), byrow = FALSE)
  
  # z observada de los puntos sobre la superficie teÃ³rica
  pseudo_df <- pseudo_df %>%
    mutate(z = gumbel_fun(u, v, theta))
  
  plot_ly() %>%
    add_surface(
      x = ~u_vals,
      y = ~v_vals,
      z = ~z_mat,
      colorscale = "Magma",
      opacity = 0.92,
      showscale = TRUE,
      colorbar = list(title = "C(u,v)")
    ) %>%
    add_markers(
      data = pseudo_df,
      x = ~u,
      y = ~v,
      z = ~z,
      marker = list(
        size = 2.5,
        color = "black",
        opacity = 0.55
      ),
      name = "Pseudo-observaciones"
    ) %>%
    layout(
      title = list(
        text = paste0(cluster_label, " | CÃ³pula de Gumbel (Î¸ = ", round(theta, 4), ")"),
        x = 0.5
      ),
      scene = list(
        xaxis = list(title = "u = F_D(d)", backgroundcolor = "rgb(245,245,245)", gridcolor = "white"),
        yaxis = list(title = "v = F_S(s)", backgroundcolor = "rgb(245,245,245)", gridcolor = "white"),
        zaxis = list(title = "C(u,v)",     backgroundcolor = "rgb(245,245,245)", gridcolor = "white"),
        camera = list(
          eye = list(x = 1.65, y = 1.55, z = 1.10)
        )
      ),
      margin = list(l = 0, r = 0, b = 0, t = 55)
    )
}

# ---------------------------
# 3. PARÃMETROS Y DATOS
# ---------------------------
theta_c1 <- 2.8444
theta_c2 <- 2.8306
theta_c3 <- 3.3715

surf_c1 <- crear_superficie_gumbel(theta_c1, "Cluster 1")
surf_c2 <- crear_superficie_gumbel(theta_c2, "Cluster 2")
surf_c3 <- crear_superficie_gumbel(theta_c3, "Cluster 3")

# Asegurar nombres de cluster para tÃ­tulos
pseudo_c1_plot <- pseudo_c1 %>% mutate(cluster = "Cluster 1")
pseudo_c2_plot <- pseudo_c2 %>% mutate(cluster = "Cluster 2")
pseudo_c3_plot <- pseudo_c3 %>% mutate(cluster = "Cluster 3")

# ---------------------------
# 4. FIGURAS 2D INDIVIDUALES
# ---------------------------
p2d_c1 <- plot_copula_2d(surf_c1, pseudo_c1_plot, theta_c1, "Cluster 1")
p2d_c2 <- plot_copula_2d(surf_c2, pseudo_c2_plot, theta_c2, "Cluster 2")
p2d_c3 <- plot_copula_2d(surf_c3, pseudo_c3_plot, theta_c3, "Cluster 3")

# Mostrar individuales
p2d_c1
p2d_c2
p2d_c3

# Guardar individuales
ggsave(
  file.path(ruta_figuras, "copula_gumbel_2d_cluster1.png"),
  p2d_c1, width = 6.3, height = 5.6, dpi = 400, bg = "white"
)

ggsave(
  file.path(ruta_figuras, "copula_gumbel_2d_cluster2.png"),
  p2d_c2, width = 6.3, height = 5.6, dpi = 400, bg = "white"
)

ggsave(
  file.path(ruta_figuras, "copula_gumbel_2d_cluster3.png"),
  p2d_c3, width = 6.3, height = 5.6, dpi = 400, bg = "white"
)

# ---------------------------
# 5. FIGURA 2D COMPUESTA FINAL
# ---------------------------
# Creamos una leyenda comÃºn elegante
surf_all <- bind_rows(surf_c1, surf_c2, surf_c3)
pseudo_all <- bind_rows(pseudo_c1_plot, pseudo_c2_plot, pseudo_c3_plot)

p_legend <- ggplot() +
  geom_raster(
    data = surf_all,
    aes(x = u, y = v, fill = C),
    interpolate = TRUE
  ) +
  scale_fill_gradientn(
    colours = rev(viridisLite::magma(256)),
    name = expression(C(u,v)),
    breaks = c(0.25, 0.50, 0.75),
    labels = c("0.25", "0.50", "0.75")
  ) +
  theme_void() +
  theme(legend.position = "right")

legend_only <- patchwork::wrap_elements(
  cowplot::get_legend(p_legend + theme(legend.position = "right"))
)

# Figura compuesta sin espacio muerto
p2d_final <- (p2d_c1 | p2d_c2 | p2d_c3 | legend_only) +
  plot_layout(widths = c(1, 1, 1, 0.18)) +
  plot_annotation(
    title = "CÃ³pula de Gumbel ajustada para duraciÃ³n y severidad de sequÃ­as",
    subtitle = "Pseudo-observaciones y superficies bidimensionales por cluster | Escala nSPEI-3",
    theme = theme(
      plot.title = element_text(face = "bold", size = 19, hjust = 0.5),
      plot.subtitle = element_text(size = 12, hjust = 0.5)
    )
  )

p2d_final

ggsave(
  file.path(ruta_figuras, "copula_gumbel_2d_final_clusters.png"),
  p2d_final, width = 15.5, height = 5.7, dpi = 450, bg = "white"
)

# ---------------------------
# 6. FIGURAS 3D SEPARADAS
# ---------------------------
p3d_c1 <- plot_copula_3d(surf_c1, pseudo_c1_plot, theta_c1, "Cluster 1")
p3d_c2 <- plot_copula_3d(surf_c2, pseudo_c2_plot, theta_c2, "Cluster 2")
p3d_c3 <- plot_copula_3d(surf_c3, pseudo_c3_plot, theta_c3, "Cluster 3")

# Mostrar en notebook
p3d_c1
p3d_c2
p3d_c3

# Guardar como HTML interactivo
htmlwidgets::saveWidget(
  as_widget(p3d_c1),
  file.path(ruta_figuras, "copula_gumbel_3d_cluster1.html"),
  selfcontained = TRUE
)

htmlwidgets::saveWidget(
  as_widget(p3d_c2),
  file.path(ruta_figuras, "copula_gumbel_3d_cluster2.html"),
  selfcontained = TRUE
)

htmlwidgets::saveWidget(
  as_widget(p3d_c3),
  file.path(ruta_figuras, "copula_gumbel_3d_cluster3.html"),
  selfcontained = TRUE
)

# ---------------------------
# 7. OPCIONAL: EXPORTAR UNA TABLA RESUMEN
# ---------------------------
tabla_parametros_copula <- tibble(
  cluster = c("Cluster 1", "Cluster 2", "Cluster 3"),
  theta = c(theta_c1, theta_c2, theta_c3),
  n = c(nrow(pseudo_c1_plot), nrow(pseudo_c2_plot), nrow(pseudo_c3_plot))
)

write.csv(
  tabla_parametros_copula,
  file.path(ruta_tablas, "parametros_gumbel_por_cluster.csv"),
  row.names = FALSE
)
# =========================================================
# FIGURAS PROFESIONALES 3D DE LA CÃ“PULA DE GUMBEL (JUPYTER)
# =========================================================

# Ajuste de tamaÃ±o para Jupyter
options(repr.plot.width = 15, repr.plot.height = 10)

# ---------------------------
# 1. FUNCIÃ“N 3D MEJORADA
# ---------------------------
plot_copula_3d_pro <- function(surface_df, pseudo_df, theta, cluster_label) {
  
  # Preparar matriz de superficie
  u_vals <- sort(unique(surface_df$u))
  v_vals <- sort(unique(surface_df$v))
  z_mat  <- matrix(surface_df$C, nrow = length(u_vals), ncol = length(v_vals), byrow = FALSE)
  
  # Proyectar puntos sobre la superficie teÃ³rica
  pseudo_df <- pseudo_df %>%
    mutate(z = gumbel_fun(u, v, theta))
  
  plot_ly() %>%
    # Superficie de la CÃ³pula
    add_surface(
      x = ~u_vals,
      y = ~v_vals,
      z = ~z_mat,
      colorscale = list(c(0, 1), c("#fcfdbf", "#000004")), # Magma custom
      reversescale = TRUE,
      opacity = 0.85,
      showscale = TRUE,
      colorbar = list(title = "C(u,v)", x = 0.9)
    ) %>%
    # Pseudo-observaciones (Puntos negros)
    add_markers(
      data = pseudo_df,
      x = ~u,
      y = ~v,
      z = ~z,
      marker = list(
        size = 3,
        color = "black",
        symbol = "circle",
        opacity = 0.7,
        line = list(color = "white", width = 0.5)
      ),
      name = "Puntos"
    ) %>%
    layout(
      title = list(
        text = paste0("<b>", cluster_label, "</b><br>CÃ³pula de Gumbel (Î¸ = ", round(theta, 4), ")"),
        y = 0.95
      ),
      scene = list(
        xaxis = list(title = "u = F[D](d)", gridcolor = "white"),
        yaxis = list(title = "v = F[S](s)", gridcolor = "white"),
        zaxis = list(title = "C(u,v)",     gridcolor = "white"),
        camera = list(
          eye = list(x = 1.8, y = 1.8, z = 1.2)
        ),
        aspectratio = list(x = 1, y = 1, z = 0.8)
      ),
      margin = list(l = 0, r = 0, b = 0, t = 80)
    )
}

# ---------------------------
# 2. GENERACIÃ“N DE GRÃFICOS
# ---------------------------

# Generar para los 3 clusters
p3d_c1 <- plot_copula_3d_pro(surf_c1, pseudo_c1_plot, theta_c1, "Cluster 1")
p3d_c2 <- plot_copula_3d_pro(surf_c2, pseudo_c2_plot, theta_c2, "Cluster 2")
p3d_c3 <- plot_copula_3d_pro(surf_c3, pseudo_c3_plot, theta_c3, "Cluster 3")

# Mostrar (Ejecuta uno por celda o seguidos para verlos en Jupyter)
p3d_c1
# =========================================================
# FIGURAS PROFESIONALES 2D Y 3D DE LA CÃ“PULA DE GUMBEL
# =========================================================

# ---------------------------
# 1. LIBRERÃAS
# ---------------------------
if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  tidyverse,
  patchwork,
  plotly,
  htmlwidgets,
  viridisLite,
  cowplot
)

# ---------------------------
# 2. FUNCIONES AUXILIARES
# ---------------------------
gumbel_fun <- function(u, v, theta) {
  exp(-(((-log(u))^theta + (-log(v))^theta)^(1/theta)))
}

crear_superficie_gumbel <- function(theta, cluster_label, n_grid = 180) {
  expand.grid(
    u = seq(0.001, 0.999, length.out = n_grid),
    v = seq(0.001, 0.999, length.out = n_grid)
  ) %>%
    as_tibble() %>%
    mutate(
      C = gumbel_fun(u, v, theta),
      cluster = cluster_label
    )
}

theme_q1 <- function() {
  theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(face = "bold", size = 18, hjust = 0.5),
      plot.subtitle = element_text(size = 12, hjust = 0.5, colour = "#444444"),
      strip.text = element_text(face = "bold", size = 13),
      axis.title = element_text(face = "bold", size = 13),
      axis.text = element_text(size = 11, colour = "#333333"),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "#D9D9D9", linewidth = 0.25),
      panel.background = element_rect(fill = "white", colour = NA),
      plot.background = element_rect(fill = "white", colour = NA),
      legend.position = "right",
      legend.title = element_text(face = "bold", size = 12),
      legend.text = element_text(size = 11),
      strip.background = element_rect(fill = "#F3F3F3", colour = NA)
    )
}

# ---------------------------
# 3. FIGURA 2D INDIVIDUAL
# ---------------------------
plot_copula_2d <- function(surface_df, pseudo_df, theta, cluster_label) {
  ggplot() +
    geom_raster(
      data = surface_df,
      aes(x = u, y = v, fill = C),
      interpolate = TRUE
    ) +
    geom_contour(
      data = surface_df,
      aes(x = u, y = v, z = C),
      colour = "white",
      bins = 7,
      linewidth = 0.45,
      alpha = 0.9
    ) +
    geom_point(
      data = pseudo_df,
      aes(x = u, y = v),
      shape = 21,
      size = 1.7,
      stroke = 0.20,
      fill = "black",
      colour = "black",
      alpha = 0.40
    ) +
    coord_equal(expand = FALSE) +
    scale_fill_gradientn(
      colours = rev(viridisLite::magma(256)),
      name = expression(C(u,v)),
      breaks = c(0.25, 0.50, 0.75),
      labels = c("0.25", "0.50", "0.75")
    ) +
    labs(
      title = cluster_label,
      subtitle = paste0("Î¸ = ", round(theta, 4)),
      x = "u = F_D(d)",
      y = "v = F_S(s)"
    ) +
    theme_q1() +
    theme(
      legend.position = "none",
      plot.title = element_text(size = 15),
      plot.subtitle = element_text(size = 11)
    )
}

# ---------------------------
# 4. FIGURA 3D INDIVIDUAL
# ---------------------------
plot_copula_3d <- function(surface_df, pseudo_df, theta, cluster_label) {
  
  u_vals <- sort(unique(surface_df$u))
  v_vals <- sort(unique(surface_df$v))
  z_mat  <- matrix(surface_df$C, nrow = length(u_vals), ncol = length(v_vals), byrow = FALSE)
  
  pseudo_df <- pseudo_df %>%
    mutate(z = gumbel_fun(u, v, theta))
  
  plot_ly() %>%
    add_surface(
      x = ~u_vals,
      y = ~v_vals,
      z = ~z_mat,
      colorscale = "Magma",
      opacity = 0.92,
      showscale = TRUE,
      colorbar = list(title = "C(u,v)"),
      name = "Superficie"
    ) %>%
    add_markers(
      data = pseudo_df,
      x = ~u,
      y = ~v,
      z = ~z,
      marker = list(
        size = 2.5,
        color = "black",
        opacity = 0.55
      ),
      name = "Pseudo-observaciones"
    ) %>%
    layout(
      title = list(
        text = paste0(cluster_label, " | CÃ³pula de Gumbel (Î¸ = ", round(theta, 4), ")"),
        x = 0.5
      ),
      scene = list(
        xaxis = list(title = "u = F_D(d)", backgroundcolor = "rgb(245,245,245)", gridcolor = "white"),
        yaxis = list(title = "v = F_S(s)", backgroundcolor = "rgb(245,245,245)", gridcolor = "white"),
        zaxis = list(title = "C(u,v)", backgroundcolor = "rgb(245,245,245)", gridcolor = "white"),
        camera = list(
          eye = list(x = 1.65, y = 1.55, z = 1.10)
        )
      ),
      margin = list(l = 0, r = 0, b = 0, t = 55)
    )
}

# ---------------------------
# 5. PARÃMETROS Y DATOS
# ---------------------------
theta_c1 <- 2.8444
theta_c2 <- 2.8306
theta_c3 <- 3.3715

surf_c1 <- crear_superficie_gumbel(theta_c1, "Cluster 1")
surf_c2 <- crear_superficie_gumbel(theta_c2, "Cluster 2")
surf_c3 <- crear_superficie_gumbel(theta_c3, "Cluster 3")

pseudo_c1_plot <- pseudo_c1 %>% mutate(cluster = "Cluster 1")
pseudo_c2_plot <- pseudo_c2 %>% mutate(cluster = "Cluster 2")
pseudo_c3_plot <- pseudo_c3 %>% mutate(cluster = "Cluster 3")

# ---------------------------
# 6. FIGURAS 2D INDIVIDUALES
# ---------------------------
p2d_c1 <- plot_copula_2d(surf_c1, pseudo_c1_plot, theta_c1, "Cluster 1")
p2d_c2 <- plot_copula_2d(surf_c2, pseudo_c2_plot, theta_c2, "Cluster 2")
p2d_c3 <- plot_copula_2d(surf_c3, pseudo_c3_plot, theta_c3, "Cluster 3")

p2d_c1
p2d_c2
p2d_c3

ggsave(
  file.path(ruta_figuras, "copula_gumbel_2d_cluster1.png"),
  p2d_c1, width = 6.3, height = 5.6, dpi = 400, bg = "white"
)

ggsave(
  file.path(ruta_figuras, "copula_gumbel_2d_cluster2.png"),
  p2d_c2, width = 6.3, height = 5.6, dpi = 400, bg = "white"
)

ggsave(
  file.path(ruta_figuras, "copula_gumbel_2d_cluster3.png"),
  p2d_c3, width = 6.3, height = 5.6, dpi = 400, bg = "white"
)

# ---------------------------
# 7. FIGURA 2D COMPUESTA FINAL
# ---------------------------
surf_all <- bind_rows(surf_c1, surf_c2, surf_c3)

p_legend <- ggplot() +
  geom_raster(
    data = surf_all,
    aes(x = u, y = v, fill = C),
    interpolate = TRUE
  ) +
  scale_fill_gradientn(
    colours = rev(viridisLite::magma(256)),
    name = expression(C(u,v)),
    breaks = c(0.25, 0.50, 0.75),
    labels = c("0.25", "0.50", "0.75")
  ) +
  theme_void() +
  theme(legend.position = "right")

legend_only <- patchwork::wrap_elements(
  cowplot::get_legend(p_legend + theme(legend.position = "right"))
)

p2d_final <- (p2d_c1 | p2d_c2 | p2d_c3 | legend_only) +
  plot_layout(widths = c(1, 1, 1, 0.18)) +
  plot_annotation(
    title = "CÃ³pula de Gumbel ajustada para duraciÃ³n y severidad de sequÃ­as",
    subtitle = "Pseudo-observaciones y superficies bidimensionales por cluster | Escala nSPEI-3",
    theme = theme(
      plot.title = element_text(face = "bold", size = 19, hjust = 0.5),
      plot.subtitle = element_text(size = 12, hjust = 0.5)
    )
  )

p2d_final

ggsave(
  file.path(ruta_figuras, "copula_gumbel_2d_final_clusters.png"),
  p2d_final, width = 15.5, height = 5.7, dpi = 450, bg = "white"
)

# ---------------------------
# 8. FIGURAS 3D SEPARADAS
# ---------------------------
p3d_c1 <- plot_copula_3d(surf_c1, pseudo_c1_plot, theta_c1, "Cluster 1")
p3d_c2 <- plot_copula_3d(surf_c2, pseudo_c2_plot, theta_c2, "Cluster 2")
p3d_c3 <- plot_copula_3d(surf_c3, pseudo_c3_plot, theta_c3, "Cluster 3")

p3d_c1
p3d_c2
p3d_c3

# Guardar sin pandoc
htmlwidgets::saveWidget(
  as_widget(p3d_c1),
  file.path(ruta_figuras, "copula_gumbel_3d_cluster1.html"),
  selfcontained = FALSE
)

htmlwidgets::saveWidget(
  as_widget(p3d_c2),
  file.path(ruta_figuras, "copula_gumbel_3d_cluster2.html"),
  selfcontained = FALSE
)

htmlwidgets::saveWidget(
  as_widget(p3d_c3),
  file.path(ruta_figuras, "copula_gumbel_3d_cluster3.html"),
  selfcontained = FALSE
)

# ---------------------------
# 9. TABLA RESUMEN
# ---------------------------
tabla_parametros_copula <- tibble(
  cluster = c("Cluster 1", "Cluster 2", "Cluster 3"),
  theta = c(theta_c1, theta_c2, theta_c3),
  n = c(nrow(pseudo_c1_plot), nrow(pseudo_c2_plot), nrow(pseudo_c3_plot))
)

write.csv(
  tabla_parametros_copula,
  file.path(ruta_tablas, "parametros_gumbel_por_cluster.csv"),
  row.names = FALSE
)


# =============================================================================
# ANALISIS ESTADISTICO DE PRECIOS DE LA TORTILLA EN MEXICO
# Script consolidado para Google Colab (o cualquier entorno R)
# =============================================================================
#
# CONTENIDO:
#   0. Instalacion de paquetes y carga de datos
#   1. Analisis exploratorio y limpieza (EDA)
#   2. Regresion y correlacion lineal simple y multiple
#   3. Regresion logistica (logit/probit) y regresion robusta
#   4. Regresion suavizada (LOESS), GAM y arboles CART
#   5. Modelos lineales mixtos generalizados (bloques aleatorios)
#   6. Modelos SARIMA de series temporales
#
# COMO USAR EN GOOGLE COLAB:
#   1. Ve a https://colab.research.google.com/ -> "Archivo" -> "Nuevo notebook"
#   2. Cambia el entorno de ejecucion a R:
#        Entorno de ejecucion > Cambiar tipo de entorno de ejecucion > R
#   3. Sube el archivo "tortilla_prices.csv" con el icono de carpeta (izquierda)
#      -> "Subir" (o arrastralo directo al panel de archivos).
#   4. Copia y pega TODO este script en una celda y ejecutala (Shift+Enter).
#      El script detecta automaticamente la ruta del archivo subido.
#
# Si vas a correrlo fuera de Colab, solo ajusta `data_path` mas abajo.
# =============================================================================


# -----------------------------------------------------------------------
# 0.1 Instalacion y carga de paquetes
# -----------------------------------------------------------------------
paquetes_necesarios <- c("dplyr", "ggplot2", "lubridate", "MASS", "mgcv",
                          "rpart", "lme4", "forecast", "tseries")

paquetes_faltantes <- paquetes_necesarios[
  !(paquetes_necesarios %in% installed.packages()[, "Package"])
]
if (length(paquetes_faltantes) > 0) {
  install.packages(paquetes_faltantes, repos = "https://cloud.r-project.org")
}

suppressMessages({
  library(dplyr)
  library(ggplot2)
  library(lubridate)
  library(MASS)      # regresion robusta (rlm)
  library(mgcv)      # GAM
  library(rpart)     # arboles CART
  library(lme4)      # modelos mixtos
  library(forecast)  # SARIMA
  library(tseries)   # pruebas de estacionariedad
})

dir.create("output", showWarnings = FALSE)

# -----------------------------------------------------------------------
# 0.2 Carga de datos
# -----------------------------------------------------------------------
# Busca el archivo automaticamente en ubicaciones comunes de Colab/local.
posibles_rutas <- c(
  "tortilla_prices.csv",
  "/content/tortilla_prices.csv",
  "/mnt/user-data/uploads/tortilla_prices.csv"
)
data_path <- posibles_rutas[file.exists(posibles_rutas)][1]

if (is.na(data_path)) {
  stop(paste(
    "No se encontro 'tortilla_prices.csv'.",
    "Sube el archivo a Colab (icono de carpeta a la izquierda -> Subir)",
    "o ajusta manualmente la variable 'data_path'."
  ))
}

cat("Leyendo datos desde:", data_path, "\n")
df <- read.csv(data_path, stringsAsFactors = FALSE, encoding = "UTF-8")

# Corregir espacios non-breaking (U+00A0) presentes en el CSV original
df$State <- gsub("\u00a0", " ", df$State, fixed = TRUE)
df$City  <- gsub("\u00a0", " ", df$City,  fixed = TRUE)
df$Store.type <- gsub("\u00a0", " ", df$Store.type, fixed = TRUE)

cat("Dimensiones originales:", dim(df), "\n")
str(df)


# =============================================================================
# 1. ANALISIS EXPLORATORIO Y LIMPIEZA DE DATOS (EDA)
# =============================================================================
cat("\n\n#####################################################\n")
cat("# 1. ANALISIS EXPLORATORIO Y LIMPIEZA\n")
cat("#####################################################\n")

df$Date <- as.Date(sprintf("%04d-%02d-%02d", df$Year, df$Month, df$Day))
df$Store.type <- factor(df$Store.type, levels = c("Mom and Pop Store", "Big Retail Store"))
df$State <- factor(df$State)
df$City  <- factor(df$City)
df$Price <- df$Price.per.kilogram

cat("\n--- Valores faltantes por columna ---\n")
print(colSums(is.na(df)))
cat("\n% de NA en Price:", round(mean(is.na(df$Price)) * 100, 2), "%\n")

# Deteccion de outliers via IQR (regla de Tukey) -- solo para diagnostico inicial
Q1 <- quantile(df$Price, 0.25, na.rm = TRUE)
Q3 <- quantile(df$Price, 0.75, na.rm = TRUE)
IQR_val <- Q3 - Q1
lower <- Q1 - 1.5 * IQR_val
upper <- Q3 + 1.5 * IQR_val
cat("\nLimites Tukey -> inferior:", round(lower, 2), " superior:", round(upper, 2), "\n")
outliers <- df %>% filter(!is.na(Price) & (Price < lower | Price > upper))
cat("Numero de 'outliers' detectados (regla 1.5*IQR):", nrow(outliers), "\n")
cat("(Este metodo es ingenuo: no toma en cuenta la tendencia temporal.\n")
cat(" Se retoma con un metodo correcto en la seccion 3.)\n")

# Limpieza: eliminamos NAs y el precio 0 (dato erroneo, no economico)
df <- df %>%
  filter(!is.na(Price)) %>%
  filter(Price > 1)

cat("\nFilas tras limpieza:", nrow(df), "\n")

cat("\n--- Resumen general del precio ---\n")
print(summary(df$Price))
cat("Desviacion estandar:", round(sd(df$Price), 3), "\n")

cat("\n--- Precio promedio por tipo de tienda ---\n")
print(df %>% group_by(Store.type) %>% summarise(media = mean(Price), sd = sd(Price), n = n()))

cat("\n--- Top 5 estados mas caros ---\n")
print(df %>% group_by(State) %>% summarise(media = mean(Price)) %>% arrange(desc(media)) %>% head(5))
cat("\n--- Top 5 estados mas baratos ---\n")
print(df %>% group_by(State) %>% summarise(media = mean(Price)) %>% arrange(media) %>% head(5))

# Graficos exploratorios
serie_mensual <- df %>%
  mutate(YearMonth = floor_date(Date, "month")) %>%
  group_by(YearMonth) %>%
  summarise(media = mean(Price))

p1 <- ggplot(serie_mensual, aes(x = YearMonth, y = media)) +
  geom_line(color = "#B22222", linewidth = 0.8) +
  labs(title = "Precio promedio nacional de la tortilla por mes (2007-2026)",
       x = "Fecha", y = "Precio (MXN/kg)") +
  theme_minimal(base_size = 13)
print(p1)
ggsave("output/01_serie_tiempo_nacional.png", p1, width = 10, height = 5, dpi = 150)

p2 <- ggplot(df, aes(x = Store.type, y = Price, fill = Store.type)) +
  geom_boxplot(alpha = 0.7, outlier.alpha = 0.15) +
  scale_fill_manual(values = c("#4682B4", "#B22222")) +
  labs(title = "Distribucion de precios por tipo de tienda", x = "", y = "Precio (MXN/kg)") +
  theme_minimal(base_size = 13) + theme(legend.position = "none")
print(p2)
ggsave("output/02_boxplot_tipo_tienda.png", p2, width = 7, height = 5, dpi = 150)

p4 <- ggplot(df, aes(x = Price)) +
  geom_histogram(bins = 60, fill = "#4682B4", alpha = 0.8) +
  geom_vline(xintercept = c(lower, upper), color = "red", linetype = "dashed") +
  labs(title = "Histograma de precios con limites de outliers (Tukey)",
       x = "Precio (MXN/kg)", y = "Frecuencia") +
  theme_minimal(base_size = 13)
print(p4)
ggsave("output/04_histograma_precio.png", p4, width = 8, height = 5, dpi = 150)


# =============================================================================
# 2. REGRESION Y CORRELACION LINEAL SIMPLE Y MULTIPLE
# =============================================================================
cat("\n\n#####################################################\n")
cat("# 2. REGRESION Y CORRELACION LINEAL\n")
cat("#####################################################\n")

df$t <- as.numeric(df$Date - min(df$Date))
df$Month_f <- factor(df$Month)

# --- A. Regresion lineal simple ---
cat("\n--- A. Regresion lineal simple (Precio ~ tiempo) ---\n")
modelo_simple <- lm(Price ~ t, data = df)
print(summary(modelo_simple))
cat("Correlacion de Pearson (Precio, tiempo):",
    round(cor(df$Price, df$t, use = "complete.obs"), 4), "\n")

p_simple <- ggplot(df, aes(x = Date, y = Price)) +
  geom_point(alpha = 0.02, color = "steelblue") +
  geom_smooth(method = "lm", color = "red", se = TRUE) +
  labs(title = "Regresion lineal simple: Precio vs Tiempo",
       subtitle = paste0("R\u00b2 = ", round(summary(modelo_simple)$r.squared, 3)),
       x = "Fecha", y = "Precio (MXN/kg)") +
  theme_minimal(base_size = 13)
print(p_simple)
ggsave("output/05_regresion_simple.png", p_simple, width = 9, height = 5, dpi = 150)

par(mfrow = c(2, 2)); plot(modelo_simple); par(mfrow = c(1, 1))

# --- B. Regresion lineal multiple ---
cat("\n--- B. Regresion lineal multiple ---\n")
modelo_multiple <- lm(Price ~ t + Store.type + Month_f, data = df)
print(summary(modelo_multiple))
cat("\nComparacion R2 simple vs multiple:\n")
cat("  Simple  :", round(summary(modelo_simple)$r.squared, 4), "\n")
cat("  Multiple:", round(summary(modelo_multiple)$r.squared, 4), "\n")
cat("\n--- ANOVA: comparacion de modelos anidados ---\n")
print(anova(modelo_simple, modelo_multiple))

# --- C. Correlacion multiple ---
cat("\n--- C. Correlacion multiple ---\n")
R_multiple <- sqrt(summary(modelo_multiple)$r.squared)
cat("Coeficiente de correlacion multiple R:", round(R_multiple, 4), "\n")


# =============================================================================
# 3. REGRESION LOGISTICA (LOGIT/PROBIT) Y REGRESION ROBUSTA
# =============================================================================
cat("\n\n#####################################################\n")
cat("# 3. REGRESION LOGISTICA Y TRATAMIENTO DE ANOMALIAS\n")
cat("#####################################################\n")

# --- A. Regresion robusta (tecnicas actuales / datos anomalos) ---
cat("\n--- A. Regresion robusta (M-estimador de Huber) vs OLS ---\n")
modelo_robusto <- rlm(Price ~ t, data = df, psi = psi.huber)
cat("Comparacion de coeficientes OLS vs Robusta:\n")
print(data.frame(Parametro = c("Intercepto", "Pendiente (t)"),
                  OLS = coef(modelo_simple), Robusta = coef(modelo_robusto)))

df$resid_robusto <- residuals(modelo_robusto)
df$resid_estandar <- df$resid_robusto / mad(df$resid_robusto)
anomalos <- df %>% filter(abs(resid_estandar) > 3.5)
cat("\nAnomalias reales detectadas (residual robusto > 3.5):", nrow(anomalos), "\n")
cat("(vs. las", nrow(outliers), "marcadas por el metodo IQR ingenuo en la seccion 1)\n")

p_robusta <- ggplot(df, aes(x = Date, y = Price)) +
  geom_point(alpha = 0.02, color = "grey50") +
  geom_point(data = anomalos, aes(x = Date, y = Price), color = "red", size = 0.8) +
  labs(title = "Deteccion de anomalias condicionada al tiempo (regresion robusta)",
       subtitle = "Puntos rojos = residual estandarizado robusto > 3.5",
       x = "Fecha", y = "Precio (MXN/kg)") +
  theme_minimal(base_size = 13)
print(p_robusta)
ggsave("output/07_anomalias_robustas.png", p_robusta, width = 9, height = 5, dpi = 150)

# --- B. Logit y Probit ---
cat("\n--- B. Regresion logistica: LOGIT y PROBIT ---\n")
df$y_bigretail <- ifelse(df$Store.type == "Big Retail Store", 1, 0)

set.seed(123)
n <- nrow(df)
idx_train <- sample(seq_len(n), size = 0.8 * n)
train <- df[idx_train, ]
test  <- df[-idx_train, ]

modelo_logit  <- glm(y_bigretail ~ Price + t, data = train, family = binomial(link = "logit"))
modelo_probit <- glm(y_bigretail ~ Price + t, data = train, family = binomial(link = "probit"))

cat("\n--- Modelo LOGIT ---\n"); print(summary(modelo_logit))
cat("\n--- Modelo PROBIT ---\n"); print(summary(modelo_probit))
cat("\nOdds ratios (logit):\n"); print(exp(coef(modelo_logit)))

pred_logit_p  <- predict(modelo_logit,  newdata = test, type = "response")
pred_probit_p <- predict(modelo_probit, newdata = test, type = "response")
acc_logit  <- mean(ifelse(pred_logit_p  > 0.5, 1, 0) == test$y_bigretail)
acc_probit <- mean(ifelse(pred_probit_p > 0.5, 1, 0) == test$y_bigretail)
cat("\nExactitud (test set) -> Logit:", round(acc_logit, 4), " Probit:", round(acc_probit, 4), "\n")

t_mediana <- median(df$t)
rango_precio <- seq(min(df$Price), max(df$Price), length.out = 200)
curva <- data.frame(Price = rango_precio, t = t_mediana)
curva$p_logit  <- predict(modelo_logit,  newdata = curva, type = "response")
curva$p_probit <- predict(modelo_probit, newdata = curva, type = "response")

p_curvas <- ggplot(curva, aes(x = Price)) +
  geom_line(aes(y = p_logit, color = "Logit"), linewidth = 1) +
  geom_line(aes(y = p_probit, color = "Probit"), linewidth = 1, linetype = "dashed") +
  labs(title = "Probabilidad estimada de ser 'Big Retail Store' segun precio",
       x = "Precio (MXN/kg)", y = "P(Big Retail Store)", color = "Modelo") +
  theme_minimal(base_size = 13)
print(p_curvas)
ggsave("output/08_logit_probit_curvas.png", p_curvas, width = 8, height = 5, dpi = 150)


# =============================================================================
# 4. REGRESION SUAVIZADA (LOESS), GAM Y ARBOLES CART
# =============================================================================
cat("\n\n#####################################################\n")
cat("# 4. SUAVIZADO, GAM Y ARBOLES CART\n")
cat("#####################################################\n")

# --- A. LOESS ---
cat("\n--- A. Regresion suavizada (LOESS) ---\n")
set.seed(123)
df_muestra <- df[sample(nrow(df), 20000), ]
modelo_loess <- loess(Price ~ t, data = df_muestra, span = 0.3)
print(summary(modelo_loess))

p_loess <- ggplot(df_muestra, aes(x = Date, y = Price)) +
  geom_point(alpha = 0.05, color = "grey40") +
  geom_smooth(method = "loess", span = 0.3, color = "darkgreen", se = TRUE) +
  geom_smooth(method = "lm", color = "red", se = FALSE, linetype = "dashed") +
  labs(title = "Regresion suavizada LOESS vs Regresion lineal (rojo, punteada)",
       x = "Fecha", y = "Precio (MXN/kg)") +
  theme_minimal(base_size = 13)
print(p_loess)
ggsave("output/09_loess.png", p_loess, width = 9, height = 5, dpi = 150)

# --- B. GAM ---
cat("\n--- B. Modelos aditivos generalizados (GAM) ---\n")
modelo_gam <- gam(Price ~ s(t, k = 20) + Store.type + s(Month, bs = "cc", k = 12),
                   data = df, method = "REML")
print(summary(modelo_gam))
cat("\nComparacion R2 ajustado: Lineal multiple = 0.790 | GAM =",
    round(summary(modelo_gam)$r.sq, 4), "\n")

par(mfrow = c(1, 2)); plot(modelo_gam, shade = TRUE); par(mfrow = c(1, 1))

df$pred_gam <- predict(modelo_gam, newdata = df)
resumen_gam <- df %>%
  mutate(YearMonth = floor_date(Date, "month")) %>%
  group_by(YearMonth) %>%
  summarise(precio_real = mean(Price), precio_gam = mean(pred_gam))

p_gam_fit <- ggplot(resumen_gam, aes(x = YearMonth)) +
  geom_line(aes(y = precio_real, color = "Observado"), linewidth = 0.8) +
  geom_line(aes(y = precio_gam, color = "Ajustado por GAM"), linewidth = 0.8) +
  scale_color_manual(values = c("Observado" = "grey40", "Ajustado por GAM" = "darkgreen")) +
  labs(title = "Ajuste del modelo GAM vs precio observado", x = "Fecha", y = "Precio (MXN/kg)", color = "") +
  theme_minimal(base_size = 13)
print(p_gam_fit)
ggsave("output/11_gam_ajuste.png", p_gam_fit, width = 9, height = 5, dpi = 150)

# --- C. Arboles CART ---
cat("\n--- C. Arboles de regresion y clasificacion (CART) ---\n")
arbol_regresion <- rpart(Price ~ t + Store.type + Month + State, data = df,
                          method = "anova", control = rpart.control(cp = 0.002, maxdepth = 5))
print(arbol_regresion)
cat("\nImportancia de variables:\n"); print(arbol_regresion$variable.importance)

plot(arbol_regresion, uniform = TRUE, margin = 0.1, main = "Arbol de regresion: Precio de la tortilla")
text(arbol_regresion, use.n = TRUE, cex = 0.7, all = FALSE)

pred_arbol <- predict(arbol_regresion)
r2_arbol <- 1 - sum((df$Price - pred_arbol)^2) / sum((df$Price - mean(df$Price))^2)
cat("\nR-cuadrado del arbol de regresion:", round(r2_arbol, 4), "\n")

arbol_clas <- rpart(Store.type ~ Price + t + Month, data = df,
                     method = "class", control = rpart.control(cp = 0.002, maxdepth = 5))
print(arbol_clas)

plot(arbol_clas, uniform = TRUE, margin = 0.1, main = "Arbol de clasificacion: Tipo de tienda")
text(arbol_clas, use.n = TRUE, cex = 0.7, all = FALSE)

pred_clas <- predict(arbol_clas, type = "class")
acc_arbol <- mean(pred_clas == df$Store.type)
cat("\nExactitud del arbol de clasificacion (train):", round(acc_arbol, 4), "\n")


# =============================================================================
# 5. MODELOS LINEALES MIXTOS GENERALIZADOS (BLOQUES ALEATORIOS = ESTADO)
# =============================================================================
cat("\n\n#####################################################\n")
cat("# 5. MODELOS LINEALES MIXTOS (GLMM)\n")
cat("#####################################################\n")

df$t_anio <- df$t / 365.25

modelo_mixto_int <- lmer(Price ~ t_anio + Store.type + (1 | State), data = df)
cat("\n--- Modelo A: intercepto aleatorio por Estado ---\n")
print(summary(modelo_mixto_int))

modelo_mixto_pend <- lmer(Price ~ t_anio + Store.type + (1 + t_anio | State), data = df)
cat("\n--- Modelo B: intercepto + pendiente aleatoria por Estado ---\n")
print(summary(modelo_mixto_pend))

cat("\n--- Comparacion de modelos anidados (LRT) ---\n")
print(anova(modelo_mixto_int, modelo_mixto_pend))

ranef_estado <- ranef(modelo_mixto_pend)$State
ranef_estado$State <- rownames(ranef_estado)
colnames(ranef_estado) <- c("Intercepto_aleatorio", "Pendiente_aleatoria", "State")
ranef_estado <- ranef_estado %>% arrange(desc(Pendiente_aleatoria))
cat("\n--- Estados que suben de precio MAS RAPIDO que el promedio ---\n")
print(head(ranef_estado, 5))
cat("\n--- Estados que suben de precio MAS LENTO que el promedio ---\n")
print(tail(ranef_estado, 5))

p_ranef <- ggplot(ranef_estado, aes(x = reorder(State, Pendiente_aleatoria), y = Pendiente_aleatoria)) +
  geom_point(color = "#B22222", size = 2) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey40") +
  coord_flip() +
  labs(title = "Desviacion de cada Estado respecto a la tendencia nacional",
       x = "", y = "Desviacion de pendiente (MXN/kg por año)") +
  theme_minimal(base_size = 10)
print(p_ranef)
ggsave("output/14_efectos_aleatorios_estado.png", p_ranef, width = 7, height = 9, dpi = 150)

var_componentes <- as.data.frame(VarCorr(modelo_mixto_int))
icc <- var_componentes$vcov[1] / sum(var_componentes$vcov)
cat("\nCoeficiente de correlacion intraclase (ICC) por Estado:", round(icc, 4), "\n")


# =============================================================================
# 6. MODELOS SARIMA DE SERIES TEMPORALES
# =============================================================================
cat("\n\n#####################################################\n")
cat("# 6. MODELOS SARIMA\n")
cat("#####################################################\n")

serie_mensual2 <- df %>%
  mutate(YearMonth = floor_date(Date, "month")) %>%
  group_by(YearMonth) %>%
  summarise(precio = mean(Price)) %>%
  arrange(YearMonth)

ts_precio <- ts(serie_mensual2$precio,
                 start = c(year(min(serie_mensual2$YearMonth)), month(min(serie_mensual2$YearMonth))),
                 frequency = 12)

cat("\n--- Estacionariedad ---\n")
adf_nivel <- adf.test(ts_precio)
cat("ADF en nivel: estadistico =", round(adf_nivel$statistic, 3),
    " p-valor =", round(adf_nivel$p.value, 4),
    " ->", ifelse(adf_nivel$p.value < 0.05, "ESTACIONARIA", "NO estacionaria"), "\n")

ts_diff1 <- diff(ts_precio)
adf_diff1 <- adf.test(ts_diff1)
cat("ADF en 1a diferencia: estadistico =", round(adf_diff1$statistic, 3),
    " p-valor =", round(adf_diff1$p.value, 4),
    " ->", ifelse(adf_diff1$p.value < 0.05, "ESTACIONARIA", "NO estacionaria"), "\n")

descomp <- stl(ts_precio, s.window = "periodic")
plot(descomp, main = "Descomposicion STL: Precio de la tortilla")

par(mfrow = c(1, 2))
acf(ts_diff1, main = "ACF (serie diferenciada)", lag.max = 36)
pacf(ts_diff1, main = "PACF (serie diferenciada)", lag.max = 36)
par(mfrow = c(1, 1))

cat("\n--- Ajuste del modelo (validacion con ultimos 12 meses) ---\n")
n_total <- length(ts_precio)
n_test <- 12
train_ts <- window(ts_precio, end = time(ts_precio)[n_total - n_test])
test_ts  <- window(ts_precio, start = time(ts_precio)[n_total - n_test + 1])

modelo_sarima <- auto.arima(train_ts, seasonal = TRUE, stepwise = FALSE, approximation = FALSE)
print(modelo_sarima)

checkresiduals(modelo_sarima)
cat("\n--- Test de Ljung-Box ---\n")
print(Box.test(residuals(modelo_sarima), lag = 12, type = "Ljung-Box"))

pronostico <- forecast(modelo_sarima, h = n_test)
mae  <- mean(abs(pronostico$mean - test_ts))
rmse <- sqrt(mean((pronostico$mean - test_ts)^2))
mape <- mean(abs((pronostico$mean - test_ts) / test_ts)) * 100
cat("\nDesempeño del pronostico (12 meses fuera de muestra):\n")
cat("  MAE :", round(mae, 3), "MXN/kg\n")
cat("  RMSE:", round(rmse, 3), "MXN/kg\n")
cat("  MAPE:", round(mape, 2), "%\n")

plot(pronostico, main = "Pronostico SARIMA vs valores reales (ultimos 12 meses)")
lines(test_ts, col = "red", lwd = 2)
legend("topleft", legend = c("Pronostico", "Real"), col = c("blue", "red"), lty = 1, lwd = 2)

cat("\n--- Pronostico a futuro (12 meses) con todos los datos ---\n")
modelo_final <- auto.arima(ts_precio, seasonal = TRUE, stepwise = FALSE, approximation = FALSE)
print(modelo_final)
pronostico_futuro <- forecast(modelo_final, h = 12)
print(pronostico_futuro)
plot(pronostico_futuro, main = "Pronostico SARIMA: Precio de la tortilla, proximos 12 meses")


# =============================================================================
# FIN DEL ANALISIS
# =============================================================================
cat("\n\n#####################################################\n")
cat("# ANALISIS COMPLETO\n")
cat("#####################################################\n")
cat("Todos los graficos generados con ggplot2 se guardaron en la carpeta 'output/'.\n")
cat("Objetos principales disponibles en el entorno de R:\n")
cat("  df                 -> datos limpios con todas las columnas derivadas\n")
cat("  modelo_simple, modelo_multiple      -> regresion lineal\n")
cat("  modelo_robusto                      -> regresion robusta (Huber)\n")
cat("  modelo_logit, modelo_probit         -> regresion logistica\n")
cat("  modelo_loess, modelo_gam            -> suavizado y GAM\n")
cat("  arbol_regresion, arbol_clas         -> arboles CART\n")
cat("  modelo_mixto_int, modelo_mixto_pend -> modelos mixtos (GLMM)\n")
cat("  modelo_sarima, modelo_final         -> modelos SARIMA\n")

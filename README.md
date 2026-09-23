# 🌮 Precio de la tortilla en México: tendencia, diferencias regionales y pronóstico (2007–2026)

**Resultado principal:** [COMPLETAR: ej. "El precio por kilo pasó de $X a $Y MXN; el modelo SARIMA pronostica los últimos 12 meses con un error promedio (MAPE) de Z%."]

---

## 🎯 Problema
La tortilla es el alimento básico con mayor peso en el gasto de los hogares mexicanos. Este análisis responde tres preguntas:
1. ¿Cómo ha evolucionado su precio desde 2007?
2. ¿Qué tanto cambia según el tipo de tienda (tortillería de barrio vs. supermercado) y el estado?
3. ¿Se puede pronosticar su precio a 12 meses?

## 📁 Datos
- **Fuente:** [Tortilla Prices in Mexico](https://www.kaggle.com/datasets/richave/tortilla-prices-in-mexico) (Kaggle), con datos del Sistema Nacional de Información e Integración de Mercados (SNIIM).
- Precios por kilogramo por fecha, estado, ciudad y tipo de tienda.
- **Limpieza:** corrección de caracteres especiales, eliminación de valores faltantes y de precios erróneos (≤ $1 MXN). Filas finales: [COMPLETAR].

## 🔍 Metodología
| Etapa | Técnica | Pregunta que responde |
|---|---|---|
| Exploración | Estadística descriptiva, boxplots, regla IQR de Tukey | ¿Cómo se distribuyen los precios? |
| Tendencia | Regresión lineal simple y múltiple (tiempo + tipo de tienda + mes), comparación con ANOVA | ¿Cuánto sube el precio por año? |
| Anomalías | Regresión robusta (M-estimador de Huber) | ¿Qué precios son realmente atípicos considerando la tendencia? |
| Clasificación | Logit y probit con partición 80/20 entrenamiento/prueba | ¿El precio distingue una tortillería de un supermercado? |
| No linealidad | LOESS, GAM con estacionalidad cíclica y árboles CART | ¿La tendencia es lineal? ¿Qué variables pesan más? |
| Diferencias regionales | Modelos lineales mixtos con efectos aleatorios por estado, ICC | ¿Qué estados encarecen más rápido que el promedio nacional? |
| Pronóstico | SARIMA (prueba ADF, descomposición STL, ACF/PACF, Ljung-Box), validado con los últimos 12 meses | ¿Cuánto costará en los próximos 12 meses? |

## 📈 Resultados
| Análisis | Resultado |
|---|---|
| Regresión lineal múltiple | R² ajustado = 0.79 |
| GAM | R² ajustado = [COMPLETAR] |
| Precio promedio: tortillería vs. supermercado | [COMPLETAR] vs. [COMPLETAR] MXN/kg |
| Estados más caros / más baratos | [COMPLETAR] |
| Estados que encarecen más rápido | [COMPLETAR] |
| ICC por estado | [COMPLETAR] (% de la variación explicada por el estado) |
| Pronóstico SARIMA fuera de muestra (12 meses) | MAE = [ ] MXN/kg · RMSE = [ ] · MAPE = [ ]% |

![Serie de tiempo nacional](imagenes/01_serie_tiempo_nacional.png)

## 🛠️ Herramientas
R: dplyr, ggplot2, lubridate, MASS, mgcv, rpart, lme4, forecast, tseries

## ▶️ Cómo reproducirlo
1. Descarga `tortilla_prices.csv` desde Kaggle.
2. En Google Colab: *Entorno de ejecución → Cambiar tipo → R*, sube el CSV y ejecuta `analisis_precio_tortilla.R`.
3. Las gráficas se guardan en la carpeta `output/`.

---
Proyecto del Diplomado en Ciencia de Datos, Facultad de Química, UNAM (2026).
**Autor:** Miguel Ángel Guillén Hernández · [LinkedIn](https://linkedin.com/in/miguel-angel-guillen-hernandez)

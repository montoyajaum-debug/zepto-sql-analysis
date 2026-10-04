# Análisis de inventario de Zepto con SQL (PostgreSQL)

Proyecto de análisis exploratorio, limpieza y respuesta a preguntas de negocio sobre el catálogo de **Zepto**, una plataforma de *quick-commerce* de la India. Todo el trabajo se hace en **PostgreSQL**.

## Objetivo

Simular el flujo de trabajo de un analista de datos en un e-commerce: cargar un catálogo crudo, validar su calidad, corregir problemas y extraer métricas útiles para decisiones de precios, inventario y surtido.

## Dataset

- Archivo: [`data/zepto_v2.csv`](data/zepto_v2.csv)
- 3.732 filas (SKUs) × 9 columnas, 14 categorías.
- Precios originales en *paise* (1 rupia = 100 paise).

| Columna | Descripción |
|---|---|
| `category` | Categoría del producto |
| `name` | Nombre del producto |
| `mrp` | Precio máximo de venta (Maximum Retail Price) |
| `discountPercent` | Porcentaje de descuento |
| `availableQuantity` | Unidades disponibles en inventario |
| `discountedSellingPrice` | Precio final con descuento |
| `weightInGms` | Peso en gramos |
| `outOfStock` | `TRUE` si está agotado |
| `quantity` | Cantidad o tamaño del empaque |

## Estructura del repositorio

```
zepto-sql-analysis/
├── data/
│   └── zepto_v2.csv
├── sql/
│   └── zepto_analysis.sql
└── README.md
```

## Cómo ejecutarlo

1. Clonar el repositorio:
   ```bash
   git clone https://github.com/montoyajaum-debug/zepto-sql-analysis.git
   cd zepto-sql-analysis
   ```
2. Ejecutar el script con `psql` desde la raíz del repo (crea la tabla, carga el CSV y corre todas las consultas):
   ```bash
   psql -U postgres -d tu_base -f sql/zepto_analysis.sql
   ```
   Si usas **pgAdmin**, crea la tabla con el bloque 0 del script e importa el CSV con *Import/Export Data* (CSV, Header = Yes, UTF8, sin la columna `sku_id`).

## Flujo del análisis

**1. Exploración**
- Conteo de filas y muestra de datos.
- Detección de valores nulos.
- Categorías existentes, productos en stock vs. agotados y nombres repetidos en varios SKUs.

**2. Limpieza**
- Eliminación de registros con precio = 0.
- Conversión de precios de *paise* a rupias.

**3. Preguntas de negocio**

| # | Pregunta | Técnica SQL |
|---|---|---|
| P1 | Top 10 productos con mayor descuento | `ORDER BY` + `LIMIT` |
| P2 | Productos caros (MRP > ₹300) agotados | Filtros con `WHERE` |
| P3 | Ingreso potencial por categoría | `SUM` + `GROUP BY` |
| P4 | Productos con MRP > ₹500 y descuento < 10% | Filtros compuestos |
| P5 | Top 5 categorías con mayor descuento promedio | `AVG` + `ROUND` |
| P6 | Precio por gramo (≥ 100 g) | Métrica calculada |
| P7 | Segmentación por peso: Low / Medium / Bulk | `CASE WHEN` |
| P8 | Peso total del inventario por categoría | Agregación ponderada |

## Hallazgos principales

- **453 de 3.731 SKUs (≈12%) están agotados**, lo que representa ventas potenciales perdidas.
- **Fruits & Vegetables** tiene el descuento promedio más alto (≈15,5%), seguida de **Meats, Fish & Eggs** (≈11%).
- **Cooking Essentials** y **Munchies** concentran el mayor ingreso potencial en inventario (≈₹337 mil cada una).
- Se encontró **1 registro con precio 0**, que se eliminó.

## Limitaciones del dataset

- Varias categorías tienen exactamente el mismo número de filas e ingreso (p. ej. Cooking Essentials y Munchies), lo que sugiere productos duplicados entre categorías en la fuente original. Conviene tenerlo en cuenta antes de sacar conclusiones por categoría.
- El “ingreso estimado” es un ingreso **potencial** (precio × stock disponible), no ventas reales.

## Herramientas

PostgreSQL 16 · pgAdmin · SQL (DDL, DML, agregaciones, `CASE`, filtros)

## Autor

**Jhon Alexander Urrea Montoya** — Especialista en Analítica de Datos
[LinkedIn](https://www.linkedin.com/in/jhon-urrea-data) · [GitHub](https://github.com/montoyajaum-debug)

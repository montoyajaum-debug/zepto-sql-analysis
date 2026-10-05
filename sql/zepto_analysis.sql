-- =====================================================================
-- Proyecto: Análisis de inventario de Zepto (quick-commerce, India)
-- Motor:    PostgreSQL 16
-- Autor:    Jhon Alexander Urrea Montoya
-- Base:     dataset y preguntas P1–P8 del proyecto guiado de Amlan Mohanty
--           (github.com/amlanmohanty1/zepto-SQL-data-analysis-project).
-- Aportes propios: diagnóstico y tratamiento de duplicados (sección 3),
--           recálculo de P1–P8 sin duplicados y consultas avanzadas (sección 6).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. CREACIÓN DE LA TABLA
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS zepto_por_categoria;
DROP TABLE IF EXISTS zepto_productos;
DROP TABLE IF EXISTS zepto;

CREATE TABLE zepto (
    sku_id                 SERIAL PRIMARY KEY,
    category               VARCHAR(120),
    name                   VARCHAR(150) NOT NULL,
    mrp                    NUMERIC(8,2),
    discountPercent        NUMERIC(5,2),
    availableQuantity      INTEGER,
    discountedSellingPrice NUMERIC(8,2),
    weightInGms            INTEGER,
    outOfStock             BOOLEAN,
    quantity               INTEGER
);

-- ---------------------------------------------------------------------
-- 1. CARGA DE DATOS
-- Opción A (psql): ejecutar desde la raíz del repositorio.
-- Opción B (pgAdmin): Import/Export Data, CSV, Header = Yes, UTF8, sin sku_id.
-- ---------------------------------------------------------------------
\copy zepto(category, name, mrp, discountPercent, availableQuantity, discountedSellingPrice, weightInGms, outOfStock, quantity) FROM 'data/zepto_v2.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- ---------------------------------------------------------------------
-- 2. EXPLORACIÓN
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS filas FROM zepto;

SELECT * FROM zepto LIMIT 10;

-- Valores nulos
SELECT COUNT(*) AS filas_con_nulos
FROM zepto
WHERE name IS NULL OR category IS NULL OR mrp IS NULL OR discountPercent IS NULL
   OR discountedSellingPrice IS NULL OR weightInGms IS NULL
   OR availableQuantity IS NULL OR outOfStock IS NULL OR quantity IS NULL;

SELECT DISTINCT category FROM zepto ORDER BY category;

-- ---------------------------------------------------------------------
-- 3. DIAGNÓSTICO DE DUPLICADOS (aporte propio)
-- Un mismo producto (mismo nombre, precio, peso y stock) aparece listado
-- en varias categorías. Sumar por fila cuenta el mismo inventario varias veces.
-- ---------------------------------------------------------------------

-- 3.1 Filas vs. productos únicos
SELECT COUNT(*) AS filas,
       COUNT(DISTINCT (name, mrp, discountPercent, availableQuantity,
                       discountedSellingPrice, weightInGms, outOfStock, quantity)) AS productos_unicos
FROM zepto;

-- 3.2 ¿En cuántas categorías aparece cada producto?
WITH presencia AS (
    SELECT name, mrp, discountPercent, availableQuantity, discountedSellingPrice,
           weightInGms, outOfStock, quantity,
           COUNT(DISTINCT category) AS n_categorias
    FROM zepto
    GROUP BY name, mrp, discountPercent, availableQuantity, discountedSellingPrice,
             weightInGms, outOfStock, quantity
)
SELECT n_categorias, COUNT(*) AS productos
FROM presencia
GROUP BY n_categorias
ORDER BY n_categorias;

-- 3.3 Evidencia: categorías con totales idénticos
SELECT category, COUNT(*) AS filas, SUM(availableQuantity) AS unidades
FROM zepto
GROUP BY category
ORDER BY filas DESC;

-- 3.4 Categorías con exactamente el mismo catálogo de productos
--     (firma = hash de la lista ordenada de productos de cada categoría)
WITH firmas AS (
    SELECT category,
           COUNT(*) AS productos,
           MD5(STRING_AGG(name || '|' || mrp || '|' || weightInGms || '|' || availableQuantity, '#'
                          ORDER BY name, mrp, weightInGms, availableQuantity)) AS firma
    FROM zepto
    GROUP BY category
)
SELECT STRING_AGG(category, ' | ' ORDER BY category) AS categorias_identicas,
       MAX(productos) AS productos,
       COUNT(*)       AS n_categorias
FROM firmas
GROUP BY firma
HAVING COUNT(*) > 1
ORDER BY productos DESC;

-- ---------------------------------------------------------------------
-- 4. LIMPIEZA
-- ---------------------------------------------------------------------

-- 4.1 Registros con precio 0
SELECT * FROM zepto WHERE mrp = 0 OR discountedSellingPrice = 0;
DELETE FROM zepto WHERE mrp = 0 OR discountedSellingPrice = 0;

-- 4.2 Paise a rupias
UPDATE zepto
SET mrp                    = mrp / 100.0,
    discountedSellingPrice = discountedSellingPrice / 100.0;

-- 4.3 Tabla de productos únicos (una fila por producto, con sus categorías)
CREATE TABLE zepto_productos AS
SELECT ROW_NUMBER() OVER (ORDER BY name, mrp, weightInGms) AS producto_id,
       name, mrp, discountPercent, availableQuantity, discountedSellingPrice,
       weightInGms, outOfStock, quantity,
       COUNT(DISTINCT category)                         AS n_categorias,
       STRING_AGG(DISTINCT category, ' | ')             AS categorias
FROM zepto
GROUP BY name, mrp, discountPercent, availableQuantity, discountedSellingPrice,
         weightInGms, outOfStock, quantity;

-- Verificación: debe devolver 1.800 productos
SELECT COUNT(*) AS productos_unicos FROM zepto_productos;

-- 4.4 Asignación de cada fila (producto-categoría) con peso 1/n_categorias,
--     para repartir métricas por categoría sin contar dos veces el inventario.
CREATE OR REPLACE VIEW zepto_por_categoria AS
SELECT z.category, p.producto_id, p.name, p.mrp, p.discountPercent,
       p.availableQuantity, p.discountedSellingPrice, p.weightInGms, p.outOfStock,
       1.0 / p.n_categorias AS peso
FROM zepto z
JOIN zepto_productos p
  ON  z.name = p.name AND z.mrp = p.mrp AND z.discountPercent = p.discountPercent
  AND z.availableQuantity = p.availableQuantity
  AND z.discountedSellingPrice = p.discountedSellingPrice
  AND z.weightInGms = p.weightInGms AND z.outOfStock = p.outOfStock
  AND z.quantity = p.quantity;

-- ---------------------------------------------------------------------
-- 5. PREGUNTAS DE NEGOCIO (sobre productos únicos)
-- ---------------------------------------------------------------------

-- P1. Top 10 productos con mayor descuento
SELECT name, mrp, discountPercent
FROM zepto_productos
ORDER BY discountPercent DESC, mrp DESC
LIMIT 10;

-- P2. Productos con MRP > ₹300 agotados
SELECT name, mrp
FROM zepto_productos
WHERE outOfStock AND mrp > 300
ORDER BY mrp DESC;

-- P3. Ingreso potencial total (precio con descuento × stock), sin duplicados
SELECT ROUND(SUM(discountedSellingPrice * availableQuantity), 0) AS ingreso_potencial_total
FROM zepto_productos;

-- P3b. Ingreso potencial por categoría con asignación proporcional
--      y participación sobre el total (SUM() OVER()).
SELECT category,
       ROUND(SUM(discountedSellingPrice * availableQuantity * peso), 0) AS ingreso_asignado,
       ROUND(100.0 * SUM(discountedSellingPrice * availableQuantity * peso)
             / SUM(SUM(discountedSellingPrice * availableQuantity * peso)) OVER (), 1) AS pct_total
FROM zepto_por_categoria
GROUP BY category
ORDER BY ingreso_asignado DESC;

-- P4. MRP > ₹500 con descuento < 10%
SELECT name, mrp, discountPercent
FROM zepto_productos
WHERE mrp > 500 AND discountPercent < 10
ORDER BY mrp DESC, discountPercent DESC;

-- P5. Top 5 categorías por descuento promedio (cada producto cuenta una vez por categoría)
SELECT category, ROUND(AVG(discountPercent), 2) AS descuento_promedio
FROM zepto_por_categoria
GROUP BY category
ORDER BY descuento_promedio DESC
LIMIT 5;

-- P6. Precio por gramo (≥ 100 g), mejor valor primero
SELECT name, weightInGms, discountedSellingPrice,
       ROUND(discountedSellingPrice / weightInGms, 4) AS precio_por_gramo
FROM zepto_productos
WHERE weightInGms >= 100
ORDER BY precio_por_gramo
LIMIT 20;

-- P7. Segmentación por peso
SELECT CASE WHEN weightInGms < 1000 THEN 'Low'
            WHEN weightInGms < 5000 THEN 'Medium'
            ELSE 'Bulk' END AS segmento_peso,
       COUNT(*) AS productos
FROM zepto_productos
GROUP BY 1
ORDER BY productos DESC;

-- P8. Peso total del inventario por categoría (asignación proporcional, en kg)
SELECT category,
       ROUND(SUM(weightInGms * availableQuantity * peso) / 1000.0, 1) AS peso_total_kg
FROM zepto_por_categoria
GROUP BY category
ORDER BY peso_total_kg DESC;

-- ---------------------------------------------------------------------
-- 6. CONSULTAS AVANZADAS (aporte propio)
-- ---------------------------------------------------------------------

-- A1. Top 3 productos por ingreso potencial dentro de cada categoría (RANK con empates)
WITH ranking AS (
    SELECT category, name,
           ROUND(discountedSellingPrice * availableQuantity, 0) AS ingreso_potencial,
           RANK() OVER (PARTITION BY category
                        ORDER BY discountedSellingPrice * availableQuantity DESC) AS posicion
    FROM zepto_por_categoria
)
SELECT category, posicion, name, ingreso_potencial
FROM ranking
WHERE posicion <= 3
ORDER BY category, posicion;

-- A2. Tasa de agotados por categoría y su posición
WITH agotados AS (
    SELECT category,
           SUM(peso)                                   AS productos,
           SUM(CASE WHEN outOfStock THEN peso ELSE 0 END) AS agotados
    FROM zepto_por_categoria
    GROUP BY category
)
SELECT category,
       ROUND(100.0 * agotados / productos, 1)            AS pct_agotados,
       RANK() OVER (ORDER BY agotados / productos DESC)  AS posicion
FROM agotados
ORDER BY posicion;

-- A3. ¿Los productos más caros tienen más descuento? Quintiles de MRP (NTILE)
WITH quintiles AS (
    SELECT mrp, discountPercent,
           NTILE(5) OVER (ORDER BY mrp) AS quintil_precio
    FROM zepto_productos
)
SELECT quintil_precio,
       MIN(mrp) AS mrp_min, MAX(mrp) AS mrp_max,
       ROUND(AVG(discountPercent), 2) AS descuento_promedio,
       COUNT(*) AS productos
FROM quintiles
GROUP BY quintil_precio
ORDER BY quintil_precio;

-- A4. Validación: precio final inconsistente con MRP y % de descuento (> ₹1)
SELECT COUNT(*) AS productos_inconsistentes,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM zepto_productos), 1) AS pct
FROM zepto_productos
WHERE ABS(mrp * (1 - discountPercent / 100.0) - discountedSellingPrice) > 1;

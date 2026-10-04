-- =====================================================================
-- Proyecto: Análisis de inventario de Zepto (e-commerce quick-commerce, India)
-- Motor:    PostgreSQL
-- Autor:    Jhon Alexander Urrea Montoya
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. CREACIÓN DE LA TABLA
-- ---------------------------------------------------------------------
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
-- Opción A (psql): ejecutar desde la raíz del repositorio
-- Opción B (pgAdmin): clic derecho en la tabla > Import/Export Data,
--   formato CSV, Header = Yes, encoding UTF8, excluyendo la columna sku_id.
-- ---------------------------------------------------------------------
\copy zepto(category, name, mrp, discountPercent, availableQuantity, discountedSellingPrice, weightInGms, outOfStock, quantity) FROM 'data/zepto_v2.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- ---------------------------------------------------------------------
-- 2. EXPLORACIÓN DE LOS DATOS
-- ---------------------------------------------------------------------

-- Conteo de filas
SELECT COUNT(*) FROM zepto;

-- Muestra de los datos
SELECT * FROM zepto
LIMIT 10;

-- Valores nulos
SELECT * FROM zepto
WHERE name IS NULL
   OR category IS NULL
   OR mrp IS NULL
   OR discountPercent IS NULL
   OR discountedSellingPrice IS NULL
   OR weightInGms IS NULL
   OR availableQuantity IS NULL
   OR outOfStock IS NULL
   OR quantity IS NULL;

-- Categorías de productos
SELECT DISTINCT category
FROM zepto
ORDER BY category;

-- Productos en stock vs. agotados
SELECT outOfStock, COUNT(sku_id) AS total_skus
FROM zepto
GROUP BY outOfStock;

-- Productos que aparecen con más de un SKU
SELECT name, COUNT(sku_id) AS "Number of SKUs"
FROM zepto
GROUP BY name
HAVING COUNT(sku_id) > 1
ORDER BY COUNT(sku_id) DESC;

-- ---------------------------------------------------------------------
-- 3. LIMPIEZA DE DATOS
-- ---------------------------------------------------------------------

-- Productos con precio = 0
SELECT * FROM zepto
WHERE mrp = 0 OR discountedSellingPrice = 0;

DELETE FROM zepto
WHERE mrp = 0 OR discountedSellingPrice = 0;

-- Convertir paise a rupias (los precios vienen multiplicados por 100)
UPDATE zepto
SET mrp                    = mrp / 100.0,
    discountedSellingPrice = discountedSellingPrice / 100.0;

SELECT mrp, discountedSellingPrice FROM zepto
LIMIT 10;

-- ---------------------------------------------------------------------
-- 4. PREGUNTAS DE NEGOCIO
-- ---------------------------------------------------------------------

-- P1. Top 10 productos con mayor porcentaje de descuento.
SELECT DISTINCT name, mrp, discountPercent
FROM zepto
ORDER BY discountPercent DESC
LIMIT 10;

-- P2. Productos con MRP alto (> ₹300) que están agotados.
SELECT DISTINCT name, mrp
FROM zepto
WHERE outOfStock = TRUE AND mrp > 300
ORDER BY mrp DESC;

-- P3. Ingreso potencial estimado por categoría (precio con descuento × stock disponible).
SELECT category,
       SUM(discountedSellingPrice * availableQuantity) AS total_revenue
FROM zepto
GROUP BY category
ORDER BY total_revenue DESC;

-- P4. Productos con MRP > ₹500 y descuento < 10%.
SELECT DISTINCT name, mrp, discountPercent
FROM zepto
WHERE mrp > 500 AND discountPercent < 10
ORDER BY mrp DESC, discountPercent DESC;

-- P5. Top 5 categorías con mayor descuento promedio.
SELECT category,
       ROUND(AVG(discountPercent), 2) AS avg_discount
FROM zepto
GROUP BY category
ORDER BY avg_discount DESC
LIMIT 5;

-- P6. Precio por gramo de productos de 100 g o más, ordenados por mejor valor.
SELECT DISTINCT name, weightInGms, discountedSellingPrice,
       ROUND(discountedSellingPrice / weightInGms, 2) AS price_per_gram
FROM zepto
WHERE weightInGms >= 100
ORDER BY price_per_gram;

-- P7. Segmentación de productos por peso: Low, Medium, Bulk.
SELECT DISTINCT name, weightInGms,
       CASE WHEN weightInGms < 1000 THEN 'Low'
            WHEN weightInGms < 5000 THEN 'Medium'
            ELSE 'Bulk'
       END AS weight_category
FROM zepto;

-- P8. Peso total del inventario por categoría.
SELECT category,
       SUM(weightInGms * availableQuantity) AS total_weight
FROM zepto
GROUP BY category
ORDER BY total_weight DESC;

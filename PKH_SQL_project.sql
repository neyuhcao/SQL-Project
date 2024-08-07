
--Lấy ra top 100 sản phẩm đang tồn ít nhất theo mỗi quốc gia .
--Hiển thị ra kết quả gồm: Quốc gia, Mã sản phẩm, Tên sản phẩm, tên kho tồn,  
--tổng sl tồn tại kho


WITH TT AS
(
SELECT CO.COUNTRY_NAME TEN_QUOC_GIA,
        P.PRODUCT_ID MA_SP,
        P.PRODUCT_NAME TEN_SP,
        WH.WAREHOUSE_NAME TEN_KHO_TON,
        SUM(INV.QUANTITY) TONG_SL_TON,
        ROW_NUMBER() over (partition by CO.COUNTRY_ID order by SUM(INV.QUANTITY) ASC) Xep_hang
FROM PRODUCTS P, INVENTORIES INV, WAREHOUSES WH, LOCATIONS LO, COUNTRIES CO
WHERE 1 = 1
    AND P.PRODUCT_ID = INV.PRODUCT_ID
    AND INV.WAREHOUSE_ID = WH.WAREHOUSE_ID
    AND WH.LOCATION_ID = LO.LOCATION_ID
    AND LO.COUNTRY_ID = CO.COUNTRY_ID
GROUP BY CO.COUNTRY_NAME,
        CO.COUNTRY_ID,
        P.PRODUCT_ID,
        P.PRODUCT_NAME,
        WH.WAREHOUSE_NAME
ORDER BY TONG_SL_TON ASC
)
SELECT TEN_QUOC_GIA,
        MA_SP,
        TEN_SP,
        TEN_KHO_TON,
        TONG_SL_TON
FROM TT
WHERE Xep_hang <= 100
ORDER BY TEN_QUOC_GIA ASC, TONG_SL_TON ASC


--Cho 1 ngày bất kỳ gọi là P_Date. 
--Với tốc độ bán hàng trong 30 ngày gần nhất so với P_Date 
--(tức là từ ngày P_Date-30 đến ngày P_date) thì bao ngày nữa sẽ hết hàng trong kho.


WITH SPEED1 AS
(
    SELECT P.PRODUCT_ID,
            ROUND(SUM(OI.QUANTITY / 30),2) SPEED
    FROM ORDERS O
    JOIN ORDER_ITEMS OI
        ON O.ORDER_ID = OI.ORDER_ID
    JOIN PRODUCTS P
        ON OI.PRODUCT_ID = P.PRODUCT_ID
    WHERE 1=1
        AND ORDER_DATE BETWEEN TO_DATE('01/01/2017','DD/MM/YYYY') - 30 AND TO_DATE('01/01/2017','DD/MM/YYYY')
    GROUP BY P.PRODUCT_ID
)

SELECT 4WH.WAREHOUSE_NAME KHO,
        P.PRODUCT_NAME TEN_SP,
        ROUND(INV.QUANTITY / SPEED) SO_NGAY
FROM SPEED1
JOIN INVENTORIES INV
    ON SPEED1.PRODUCT_ID = INV.PRODUCT_ID
JOIN PRODUCTS P
    ON INV.PRODUCT_ID = P.PRODUCT_ID
JOIN WAREHOUSES WH
    ON INV.WAREHOUSE_ID = WH.WAREHOUSE_ID


--Đưa ra danh sách Khách hàng  (ID, Tên khách hàng, doanh số của khách hàng) 
--đóng góp vào 80 % doanh thu của công ty, sắp xếp từ cao xuống thấp theo doanh số

WITH DTSP AS
(
    SELECT
        C.CUSTOMER_ID ID,
        C.NAME TEN_KH,
        SUM(OI.QUANTITY * OI.UNIT_PRICE) DT_SP
    FROM CUSTOMERS C, ORDERS O, ORDER_ITEMS OI
    WHERE 1=1
        AND C.CUSTOMER_ID = O.CUSTOMER_ID
        AND O.ORDER_ID = OI.ORDER_ID
    GROUP BY C.CUSTOMER_ID, C.NAME
),
DTCT AS
(
    SELECT 
        SUM(DT_SP) TONG_DT_CT
    FROM DTSP
),
DTTL AS
(
    SELECT ID, 
            TEN_KH,
            DT_SP,
            SUM(DT_SP) OVER (ORDER BY DT_SP DESC) DTTL1
    FROM DTSP
)
SELECT ID, TEN_KH,
        DT_SP
FROM DTTL, DTCT
WHERE 1=1
    AND DTTL1 <= 0.8 * TONG_DT_CT
ORDER BY ID ASC, DT_SP DESC


--Đưa ra báo cáo như sau: Nhóm sản phẩm, sản phẩm, doanh thu năm hiện tại, doanh thu năm trước, tăng trưởng. 
--Với mỗi nhóm sẽ có dòng tổng doanh thu của nhóm. 
--Cuối cùng thêm 1 dòng tổng cộng


WITH CTE AS 
(
	SELECT 
		PC.CATEGORY_NAME NHOM_SP,
        P.PRODUCT_NAME TEN_SP,
        SUM(OI.QUANTITY*OI.UNIT_PRICE) DOANH_THU_HIEN_TAI,
        EXTRACT(YEAR FROM O.ORDER_DATE) YEAR,
		LAG(SUM(OI.QUANTITY*OI.UNIT_PRICE)) OVER (ORDER BY EXTRACT(YEAR FROM O.ORDER_DATE)) DOANH_THU_NAM_TRUOC
	FROM ORDERS O
    JOIN ORDER_ITEMS OI
        ON O.ORDER_ID = OI.ORDER_ID
    JOIN PRODUCTS P
        ON OI.PRODUCT_ID = P.PRODUCT_ID
    JOIN PRODUCT_CATEGORIES PC
        ON P.CATEGORY_ID = PC.CATEGORY_ID
--    WHERE EXTRACT(YEAR FROM O.ORDER_DATE) = 2017
	GROUP BY PC.CATEGORY_NAME, P.PRODUCT_NAME, EXTRACT(YEAR FROM O.ORDER_DATE)
--    ORDER BY YEAR
)
SELECT 
	NHOM_SP,
    TEN_SP,
    DOANH_THU_HIEN_TAI,
	DOANH_THU_NAM_TRUOC,
	CASE 
    	 WHEN DOANH_THU_NAM_TRUOC IS NULL THEN 'N/A'
  	ELSE
    	 TO_CHAR((DOANH_THU_HIEN_TAI - DOANH_THU_NAM_TRUOC) * 100 / DOANH_THU_NAM_TRUOC,'999999.99') || '%'
  	END "% Tăng trưởng"
FROM 
	CTE
UNION ALL
SELECT 'Tổng cộng' AS NHOM_SP,
        NULL AS TEN_SP,
        SUM(DOANH_THU_HIEN_TAI) AS DOANH_THU_HIEN_TAI,
        SUM(DOANH_THU_NAM_TRUOC) AS DOANH_THU_NAM_TRUOC,
        NULL AS "% Tăng trưởng"
FROM CTE;


--Đưa ra báo cáo như sau: Tháng, Doanh thu của tháng, doanh thu lũy kế từ đầu năm

WITH TT AS
(
SELECT TO_CHAR(O.ORDER_DATE, 'YYYYMM') AS THANG,
        PC.CATEGORY_NAME NHOM_SP,
        SUM(OI.QUANTITY*OI.UNIT_PRICE) DOANH_THU,
        SUM(SUM(OI.QUANTITY*OI.UNIT_PRICE)) OVER(PARTITION BY PC.CATEGORY_NAME ORDER BY TO_CHAR(O.ORDER_DATE, 'YYYYMM')) AS DOANH_THU_LUY_KE
FROM ORDERS O
JOIN ORDER_ITEMS OI
    ON O.ORDER_ID = OI.ORDER_ID
JOIN PRODUCTS P
    ON OI.PRODUCT_ID = P.PRODUCT_ID
JOIN PRODUCT_CATEGORIES PC
    ON P.CATEGORY_ID = PC.CATEGORY_ID
--WHERE EXTRACT(YEAR FROM ORDER_DATE) = 2017
GROUP BY O.ORDER_DATE, PC.CATEGORY_NAME, TO_CHAR(O.ORDER_DATE, 'YYYYMM')
ORDER BY THANG ASC
)
SELECT THANG,
        NHOM_SP,
        DOANH_THU,
        DOANH_THU_LUY_KE
FROM TT

--1
ALTER TABLE DETAILRENTAL
ADD DAYS_LATE NUMBER(4) NULL;


--2
ALTER TABLE GAMECOPY
ADD GA_STATUS CHAR(4) NOT NULL;

UPDATE GAMECOPY
SET GA_STATUS = 'IN'
WHERE GA_STATUS IS NULL;

ALTER TABLE GAMECOPY
MODIFY GA_STATUS DEFAULT 'IN';

ALTER TABLE GAMECOPY
ADD CONSTRAINT chk_ga_status
CHECK (GA_STATUS IN ('IN', 'OUT', 'LOST'));

--3
UPDATE GAMECOPY
SET GA_STATUS = 'OUT'
WHERE GC_NUM IN (
    SELECT GC_NUM
    FROM DETAILRENTAL
    WHERE RETURN_DATE IS NULL
);

--4
ALTER TABLE PRICE
ADD RENT_DAYS NUMBER(2) NULL;

UPDATE PRICE
SET RENT_DAYS = 3
WHERE RENT_DAYS IS NULL;

ALTER TABLE PRICE
MODIFY RENT_DAYS DEFAULT 3;

ALTER TABLE PRICE
MODIFY RENT_DAYS NUMBER(2) NOT NULL;

--5
UPDATE PRICE
SET RENT_DAYS = CASE
    WHEN PRICE_CODE = 1 THEN 5
    WHEN PRICE_CODE = 2 THEN 3
    WHEN PRICE_CODE = 3 THEN 5
    WHEN PRICE_CODE = 4 THEN 7
    ELSE 3
END;

--6
SELECT 
    G.GA_NUM AS "Game Number",
    G.TITLE AS "Title",
    COUNT(GC.GA_NUM) AS "Number of Copies"
FROM 
    GAME G
LEFT JOIN 
    GAMECOPY GC ON G.GA_NUM = GC.GA_NUM
GROUP BY 
    G.GA_NUM, G.TITLE
ORDER BY 
    G.GA_NUM;

--7
SELECT 
    G.GA_NUM AS "Game Number",
    G.TITLE AS "Title",
    COUNT(GC.GC_NUM) AS "Available Copies"
FROM 
    GAME G
LEFT JOIN 
    GAMECOPY GC ON G.GA_NUM = GC.GA_NUM
LEFT JOIN 
    DETAILRENTAL D ON GC.GC_NUM = D.GC_NUM AND D.RETURN_DATE IS NULL
WHERE 
    D.RENT_NUM IS NULL
GROUP BY 
    G.GA_NUM, G.TITLE
ORDER BY 
    G.GA_NUM;

--8
CREATE SEQUENCE SEQ_GAME_COPY
START WITH 70000
INCREMENT BY 1
NOCACHE;

CREATE SEQUENCE SEQ_RENT_NUM
START WITH 1200
INCREMENT BY 1
NOCACHE;

--9
CREATE OR REPLACE PROCEDURE PRC_ADD_GAMECOPY (
    p_game_num GAME.GA_NUM%TYPE
)
IS
    v_game_count INTEGER;
    v_gc_num GAMECOPY.GC_NUM%TYPE;
    v_title GAME.TITLE%TYPE;
    no_ga_num EXCEPTION;
BEGIN
    SELECT COUNT(*)
    INTO v_game_count
    FROM GAME 
    WHERE GA_NUM = p_game_num;

    IF v_game_count = 0 THEN
        RAISE no_ga_num;
    ELSE
        SELECT TITLE
        INTO v_title
        FROM GAME
        WHERE GA_NUM = p_game_num;

        SELECT SEQ_GAME_COPY.NEXTVAL INTO v_gc_num FROM DUAL;

        INSERT INTO GAMECOPY (GC_NUM, INDATE, GA_NUM, GA_STATUS)
        VALUES (v_gc_num, SYSDATE, p_game_num, 'IN');

        DBMS_OUTPUT.PUT_LINE('ADDED COPY NUMBER: ' || v_gc_num || ' for game - ' || v_title);
    END IF;
EXCEPTION
    WHEN no_ga_num THEN
        DBMS_OUTPUT.PUT_LINE('Game number ' || p_game_num || ' does not exist.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: An unknown error has occurred' || SQLERRM);
END;
/

Call PRC_ADD_GAMECOPY(1246);

--10
CREATE OR REPLACE PROCEDURE PRC_MEM_INFO (
    p_mem_num MEMBERSHIP.MEM_NUM%TYPE
)
IS
    v_mem_count NUMBER;
    v_last_name MEMBERSHIP.LNAME%TYPE;
    v_first_name MEMBERSHIP.FNAME%TYPE;
    v_street MEMBERSHIP.STREET%TYPE;
    v_postal_code MEMBERSHIP.POSTAL%TYPE;
BEGIN
    SELECT COUNT(*)
    INTO v_mem_count
    FROM MEMBERSHIP 
    WHERE MEM_NUM = p_mem_num;

    IF v_mem_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ORA-20011: NO MATCHING MEMBERSHIP ID FOR ' || p_mem_num);
    ELSE
        SELECT LNAME, FNAME, STREET, POSTAL
        INTO v_last_name, v_first_name, v_street, v_postal_code
        FROM MEMBERSHIP
        WHERE MEM_NUM = p_mem_num;
    
        DBMS_OUTPUT.PUT_LINE(v_last_name || ', ' || v_first_name);
        DBMS_OUTPUT.PUT_LINE(v_street || '    ' || v_postal_code);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: An unknown error has occurred: ' || SQLERRM);
END;
/

CALL PRC_MEM_INFO(111);
CALL PRC_MEM_INFO(411);

--11
CREATE OR REPLACE PROCEDURE PRC_NEW_RENTAL (
    p_mem_num MEMBERSHIP.MEM_NUM%TYPE
)
IS
    v_last_name MEMBERSHIP.LNAME%TYPE;
    v_first_name MEMBERSHIP.FNAME%TYPE;
    v_street MEMBERSHIP.STREET%TYPE;
    v_postal_code MEMBERSHIP.POSTAL%TYPE;
    v_balance MEMBERSHIP.BALANCE%TYPE;
    v_rent_num RENTAL.RENT_NUM%TYPE;
    mem_not_found BOOLEAN := FALSE;
BEGIN

    BEGIN
        SELECT LNAME, FNAME, STREET, POSTAL, BALANCE
        INTO v_last_name, v_first_name, v_street, v_postal_code, v_balance
        FROM MEMBERSHIP
        WHERE MEM_NUM = p_mem_num;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            mem_not_found := TRUE;
            DBMS_OUTPUT.PUT_LINE('ORA-20021: NO MATCHING MEMBERSHIP ID FOR ' || p_mem_num || ' ... NO RENTAL INFO STORED.');
    END;

    IF NOT mem_not_found THEN
        DBMS_OUTPUT.PUT_LINE(v_last_name || ', ' || v_first_name);
        DBMS_OUTPUT.PUT_LINE(v_street || '    ' || v_postal_code);
        DBMS_OUTPUT.PUT_LINE('Balance: $' || TO_CHAR(v_balance, 'FM9999.00'));

        SELECT SEQ_RENT_NUM.NEXTVAL INTO v_rent_num FROM DUAL;

        INSERT INTO RENTAL (RENT_NUM, RENT_DATE, MEM_NUM)
        VALUES (v_rent_num, SYSDATE, p_mem_num);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: An unknown error has occurred: ' || SQLERRM);
END;
/

CALL PRC_NEW_RENTAL(111);
CALL PRC_NEW_RENTAL(411);
--12
CREATE OR REPLACE PROCEDURE PRC_NEW_DETAIL (
    p_game_num GAME.GA_NUM%TYPE
)
IS
    v_game_count INTEGER;
    v_gc_num GAMECOPY.GC_NUM%TYPE;
    v_rent_num RENTAL.RENT_NUM%TYPE;
    v_rent_fee PRICE.RENT_FEE%TYPE;
    v_daily_late_fee PRICE.DAILY_LATE_FEE%TYPE;
    v_rent_days PRICE.RENT_DAYS%TYPE;
    v_due_date DATE;
    v_title GAME.TITLE%TYPE;
    no_game EXCEPTION;
    no_copies EXCEPTION;
BEGIN
 
    SELECT COUNT(*)
    INTO v_game_count
    FROM GAME 
    WHERE GA_NUM = p_game_num;

    IF v_game_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ORA-20032: NO MATCHING GAME ID FOR ' || p_game_num);
    ELSE
      
        BEGIN
            SELECT GC.GC_NUM, G.TITLE
            INTO v_gc_num, v_title
            FROM GAMECOPY GC
            INNER JOIN GAME G ON GC.GA_NUM = G.GA_NUM
            WHERE G.GA_NUM = p_game_num AND GC.GA_STATUS = 'IN'
            AND ROWNUM = 1;

            SELECT P.RENT_FEE, P.DAILY_LATE_FEE, P.RENT_DAYS
            INTO v_rent_fee, v_daily_late_fee, v_rent_days
            FROM PRICE P
            INNER JOIN GAME G ON P.PRICE_CODE = G.PRICE_CODE
            WHERE G.GA_NUM = p_game_num;

            v_due_date := SYSDATE + v_rent_days;

            INSERT INTO DETAILRENTAL (RENT_NUM, GC_NUM, FEE, DUE_DATE, DAILY_LATE_FEE, RETURN_DATE)
            VALUES (SEQ_RENT_NUM.CURRVAL, v_gc_num, v_rent_fee, v_due_date, v_daily_late_fee, NULL);

            UPDATE GAMECOPY
            SET GA_STATUS = 'OUT'
            WHERE GC_NUM = v_gc_num;

            DBMS_OUTPUT.PUT_LINE('RENTAL NUMBER: #' || SEQ_RENT_NUM.CURRVAL);
            DBMS_OUTPUT.PUT_LINE('GAME COPY #' || v_gc_num || '   TITLE: ' || v_title);
            DBMS_OUTPUT.PUT_LINE('RENTAL FEE $' || TO_CHAR(v_rent_fee, 'FM9999.00') || '    LATE FEE $' || TO_CHAR(v_daily_late_fee, 'FM9999.00'));
            DBMS_OUTPUT.PUT_LINE('DUE BACK IN ' || v_rent_days || ' DAYS - ' || TO_CHAR(v_due_date, 'YYYY-MON-DD'));
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('NO GAME CURRENTLY AVAILABLE FOR RENT UNTIL: ' || TO_CHAR(v_due_date, 'MON-DD-YYYY') || '   MESSAGE NUMBER -20031');
        END;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: An unknown error has occurred: ' || SQLERRM);
END;
/

CALL PRC_NEW_DETAIL(1246);
CALL PRC_NEW_DETAIL(1222);

--14
CREATE OR REPLACE PROCEDURE PRC_NEW_DETAIL_V2 (
    p_game_num1 GAME.GA_NUM%TYPE,
    p_game_num2 GAME.GA_NUM%TYPE DEFAULT NULL,
    p_game_num3 GAME.GA_NUM%TYPE DEFAULT NULL
)
IS
    v_game_count INTEGER;
    v_gc_num GAMECOPY.GC_NUM%TYPE;
    v_rent_num RENTAL.RENT_NUM%TYPE;
    v_rent_fee PRICE.RENT_FEE%TYPE;
    v_daily_late_fee PRICE.DAILY_LATE_FEE%TYPE;
    v_rent_days PRICE.RENT_DAYS%TYPE;
    v_due_date DATE;
    v_title GAME.TITLE%TYPE;
    v_total_rent_fee NUMBER := 0;
    v_due_date_if_available DATE;

    PROCEDURE handle_game_rental(p_game_num GAME.GA_NUM%TYPE) IS
    BEGIN
        -- Verify if the game number exists in the GAME table
        SELECT COUNT(*)
        INTO v_game_count
        FROM GAME 
        WHERE GA_NUM = p_game_num;

        IF v_game_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('ORA-20032: NO MATCHING GAME ID FOR ' || p_game_num);
        ELSE
            BEGIN
                -- Retrieve a single corresponding GC_NUM with GA_STATUS 'IN'
                BEGIN
                    SELECT GC.GC_NUM, G.TITLE
                    INTO v_gc_num, v_title
                    FROM GAMECOPY GC
                    INNER JOIN GAME G ON GC.GA_NUM = G.GA_NUM
                    WHERE G.GA_NUM = p_game_num AND GC.GA_STATUS = 'IN'
                    AND ROWNUM = 1;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        v_gc_num := NULL;
                        v_title := NULL;
                END;

                IF v_gc_num IS NOT NULL THEN
                    -- Retrieve RENT_FEE, DAILY_LATE_FEE, and RENT_DAYS from the PRICE table
                    SELECT P.RENT_FEE, P.DAILY_LATE_FEE, P.RENT_DAYS
                    INTO v_rent_fee, v_daily_late_fee, v_rent_days
                    FROM PRICE P
                    INNER JOIN GAME G ON P.PRICE_CODE = G.PRICE_CODE
                    WHERE G.GA_NUM = p_game_num;

                    -- Calculate the due date
                    v_due_date := SYSDATE + v_rent_days;

                    -- Insert new row in the DETAILRENTAL table
                    INSERT INTO DETAILRENTAL (RENT_NUM, GC_NUM, FEE, DUE_DATE, DAILY_LATE_FEE, RETURN_DATE)
                    VALUES (SEQ_RENT_NUM.CURRVAL, v_gc_num, v_rent_fee, v_due_date, v_daily_late_fee, NULL);

                    -- Change the game copy's status to 'OUT'
                    UPDATE GAMECOPY
                    SET GA_STATUS = 'OUT'
                    WHERE GC_NUM = v_gc_num;

                    -- Display rental details with currency formatting
                    DBMS_OUTPUT.PUT_LINE('RENTAL NUMBER: #' || SEQ_RENT_NUM.CURRVAL);
                    DBMS_OUTPUT.PUT_LINE('GAME COPY #' || v_gc_num || '   TITLE: ' || v_title);
                    DBMS_OUTPUT.PUT_LINE('RENTAL FEE $' || TO_CHAR(v_rent_fee, 'FM9999.00') || '    LATE FEE $' || TO_CHAR(v_daily_late_fee, 'FM9999.00'));
                    DBMS_OUTPUT.PUT_LINE('DUE BACK IN ' || v_rent_days || ' DAYS - ' || TO_CHAR(v_due_date, 'YYYY-MON-DD'));

                    -- Add the rental fee to the total
                    v_total_rent_fee := v_total_rent_fee + v_rent_fee;
                ELSE
                    -- Find the next available due date
                    BEGIN
                        SELECT MIN(DUE_DATE)
                        INTO v_due_date_if_available
                        FROM DETAILRENTAL
                        WHERE GC_NUM IN (SELECT GC_NUM FROM GAMECOPY WHERE GA_NUM = p_game_num AND GA_STATUS = 'OUT');
                        DBMS_OUTPUT.PUT_LINE('NO GAME CURRENTLY AVAILABLE FOR RENT UNTIL: ' || TO_CHAR(v_due_date_if_available, 'YYYY-MON-DD') || ' FOR GAME #' || p_game_num);
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            DBMS_OUTPUT.PUT_LINE('NO GAME CURRENTLY AVAILABLE FOR RENT FOR GAME #' || p_game_num);
                    END;
                END IF;
            END;
        END IF;
    END;

BEGIN
    handle_game_rental(p_game_num1);
    IF p_game_num2 IS NOT NULL THEN
        handle_game_rental(p_game_num2);
    END IF;
    IF p_game_num3 IS NOT NULL THEN
        handle_game_rental(p_game_num3);
    END IF;

    DBMS_OUTPUT.PUT_LINE('TOTAL RENTAL FEE: $' || TO_CHAR(v_total_rent_fee, 'FM9999.00'));
    DBMS_OUTPUT.PUT_LINE('**************************');

    -- Update member's balance
    UPDATE MEMBERSHIP
    SET BALANCE = BALANCE + v_total_rent_fee
    WHERE MEM_NUM = (SELECT MEM_NUM FROM RENTAL WHERE RENT_NUM = SEQ_RENT_NUM.CURRVAL);

    DBMS_OUTPUT.PUT_LINE('NEW BALANCE: $' || (SELECT BALANCE FROM MEMBERSHIP WHERE MEM_NUM = (SELECT MEM_NUM FROM RENTAL WHERE RENT_NUM = SEQ_RENT_NUM.CURRVAL)));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

CALL PRC_NEW_DETAIL_V2(1246);
CALL PRC_NEW_DETAIL_V2(1239);

--15
CREATE OR REPLACE PROCEDURE PRC_RETURN_GAME (
    p_gc_num GAMECOPY.GC_NUM%TYPE
)
IS
    v_count INTEGER;
    v_rent_num RENTAL.RENT_NUM%TYPE;
    game_copy_not_found EXCEPTION;
    multiple_rentals EXCEPTION;
BEGIN

    SELECT COUNT(*)
    INTO v_count
    FROM DETAILRENTAL
    WHERE GC_NUM = p_gc_num;

    IF v_count = 0 THEN
        RAISE game_copy_not_found;
    ELSE
       
        SELECT COUNT(*)
        INTO v_count
        FROM DETAILRENTAL
        WHERE GC_NUM = p_gc_num AND RETURN_DATE IS NULL;

        IF v_count > 1 THEN
            RAISE multiple_rentals;
        ELSIF v_count = 1 THEN

            SELECT RENT_NUM
            INTO v_rent_num
            FROM DETAILRENTAL
            WHERE GC_NUM = p_gc_num AND RETURN_DATE IS NULL;

            UPDATE DETAILRENTAL
            SET RETURN_DATE = SYSDATE
            WHERE RENT_NUM = v_rent_num;

            UPDATE GAMECOPY
            SET GA_STATUS = 'IN'
            WHERE GC_NUM = p_gc_num;

            DBMS_OUTPUT.PUT_LINE('GAME SUCCESSFULLY RETURNED');
        END IF;
    END IF;

EXCEPTION
    WHEN game_copy_not_found THEN
        DBMS_OUTPUT.PUT_LINE('ORA-20044: NO MATCHING GAME COPY FOR ' || p_gc_num || ' ...  NO RENTAL RETURN POSSIBLE');
    WHEN multiple_rentals THEN
        DBMS_OUTPUT.PUT_LINE('GAME HAS MULTIPLE OUTSTANDING RENTALS');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: An unknown error has occurred: ' || SQLERRM);
        RAISE;
END;
/

CALL PRC_RETURN_GAME(61367);
CALL PRC_RETURN_GAME(61377);

--16
CREATE OR REPLACE TRIGGER TRG_LATE_RETURN
BEFORE UPDATE OF RETURN_DATE, DUE_DATE
ON DETAILRENTAL
FOR EACH ROW
BEGIN
    IF :NEW.RETURN_DATE IS NULL THEN
        :NEW.DAYS_LATE := NULL;
    ELSIF :NEW.RETURN_DATE <= :NEW.DUE_DATE THEN
        :NEW.DAYS_LATE := 0;
    ELSE
        :NEW.DAYS_LATE := :NEW.RETURN_DATE - :NEW.DUE_DATE;
    END IF;
END;
/

-- Test Statements
-- Set up initial data
INSERT INTO DETAILRENTAL (RENT_NUM, GC_NUM, FEE, DUE_DATE, DAILY_LATE_FEE, RETURN_DATE, DAYS_LATE)
VALUES (1001, 61367, 10, TO_DATE('2025-04-20', 'YYYY-MM-DD'), 1, NULL, NULL);

--RETURN_DATE is NULL
UPDATE DETAILRENTAL
SET RETURN_DATE = NULL
WHERE RENT_NUM = 1001;

SELECT RETURN_DATE, DAYS_LATE
FROM DETAILRENTAL
WHERE RENT_NUM = 1001;

--RETURN_DATE is the day of DUE_DATE
UPDATE DETAILRENTAL
SET RETURN_DATE = TO_DATE('2025-04-20', 'YYYY-MM-DD')
WHERE RENT_NUM = 1001;

SELECT RETURN_DATE, DAYS_LATE
FROM DETAILRENTAL
WHERE RENT_NUM = 1001;

--RETURN_DATE is later than DUE_DATE
UPDATE DETAILRENTAL
SET RETURN_DATE = TO_DATE('2025-04-25', 'YYYY-MM-DD')
WHERE RENT_NUM = 1001;

SELECT RETURN_DATE, DAYS_LATE
FROM DETAILRENTAL
WHERE RENT_NUM = 1001;

--Change DUE_DATE
UPDATE DETAILRENTAL
SET DUE_DATE = TO_DATE('2025-04-23', 'YYYY-MM-DD')
WHERE RENT_NUM = 1001;

SELECT RETURN_DATE, DUE_DATE, DAYS_LATE
FROM DETAILRENTAL
WHERE RENT_NUM = 1001;

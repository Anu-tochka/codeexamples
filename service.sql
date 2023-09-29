/*Функция stack.select_count_pok_by_service, которая получает номера услуг строкой и дату
и возвращает количество показаний по услуге для каждого лицевого счёта
Результат вызова функции - таблица с 3 колонками:
- acc (Лицевой счет)
- serv (Услуга)
- count (Количество показаний)

Пример вызова функции:
select * from stack.select_count_pok_by_service('300','20230201')
--number|service|count
--111	300	2
--144	300	1
*/

CREATE FUNCTION stack.select_count_pok_by_service(num varchar, day varchar)
RETURNS TABLE(acc int, serv int, count bigint) AS $$
BEGIN
    RETURN QUERY SELECT a.number AS acc, c.service AS serv, count(*) 
				FROM stack.Accounts a
				JOIN stack.Meter_Pok m ON a.row_id = m.acc_id
				JOIN stack.Counters c ON c.row_id = m.counter_id
				WHERE m.month = to_date(day, 'YYYYMMDD') and c.service = to_number(num, '999')
				GROUP BY a.number, c.service;
END;
$$
LANGUAGE 'plpgsql';

/*
Функция select_value_by_house_and_month получает номер дома и месяц и возвращает все лицевые в этом доме, 
для лицевых выводятся все счетчики с сумарным расходом за месяц ( суммируются все показания тарифов)
Результат вызова функции таблица с 3 колонками:

- acc (Лицевой счет)
- name (Наименование счетчика)
- value (Расход)

Пример вызова функции:

select * from stack.select_last_pok_by_service(1,'20230201')
--number|name|value
--111	Счетчик на воду	150
--111	Счетчик на отопление	-50
*/

CREATE FUNCTION stack.select_last_pok_by_service(num int, day varchar)
RETURNS TABLE(acc int, name text, value bigint) AS $$
BEGIN
    RETURN QUERY SELECT a.number AS acc, c.name, SUM(m.value) AS value
		FROM stack.Accounts a
		JOIN stack.Counters c ON c.acc_id = a.row_id
		JOIN stack.Meter_Pok m ON a.row_id = m.acc_id AND C.row_id = m.counter_id 
		WHERE month = to_date(day, 'YYYYMMDD') AND type = 3 AND parent_id IN 
			(SELECT a.row_id FROM stack.Accounts a WHERE (a.number = num AND type = 1) OR 
			 parent_id IN (SELECT a.row_id FROM stack.Accounts a WHERE a.number = num AND type = 1)
			) 
		GROUP BY a.number, c.name;
END;
$$
LANGUAGE 'plpgsql';


/*
Функция stack.select_last_pok_by_acc получает номер лицевого счёта
и возвращает дату,тариф,объем последнего показания по каждой услуге
Результат вызова функции - таблица с 5 колонками:
- acc (Лицевой счет)
- serv (Услуга)
- date (Дата показания)
- tarif (Тариф показания)
- value (Объем)

Примеры вызова функции:
select * from stack.select_last_pok_by_acc(144)
--acc|serv|date|tarif|value|
--144	100	2023-02-21	1	0
--144	200	2023-02-27	1	0
--144	300	2023-02-28	1	100
--144	400	2023-02-26	1	10
select * from stack.select_last_pok_by_acc(266)
--266	300	2023-02-27	1	-90
--266	300	2023-02-27	2	0
--266	300	2023-02-27	3	13
*/

CREATE FUNCTION stack.select_last_pok_by_acc(num int)
RETURNS TABLE(acc int, serv int, date date, tarif int, value int) AS $$
BEGIN
    RETURN QUERY WITH sorting AS (		
		SELECT number, service, m.date AS date_pok, m.tarif AS t, m.value AS v,
			row_number () OVER (PARTITION BY service, m.tarif ORDER BY m.date DESC) AS position
		FROM stack.Accounts a
			JOIN stack.Counters c ON c.acc_id = a.row_id
			JOIN stack.Meter_Pok m ON a.row_id = m.acc_id AND c.row_id = m.counter_id
		WHERE a.number = num
		ORDER BY service)
		 
		SELECT number, service, date_pok, t, v
		FROM sorting
		WHERE position = 1;
END;
$$
LANGUAGE 'plpgsql';

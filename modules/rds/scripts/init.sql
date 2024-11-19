
CREATE TABLE Airline (
    Id int NOT NULL,
    Name varchar(255) NOT NULL,    
    PRIMARY KEY (Id)
);

CREATE TABLE Airport (
    Id int NOT NULL,
    Name varchar(255) NOT NULL,    
    PRIMARY KEY (Id)
);

CREATE TABLE Movement (
    Id int NOT NULL,
    Description varchar(255) NOT NULL,
    PRIMARY KEY (Id)
);

CREATE TABLE Flight (    
    Id_Airline int NOT NULL,
    Id_Airport int NOT NULL,
    Id_Movement int NOT NULL,
    DayOfFlight DATE NOT NULL,
        
    FOREIGN KEY (Id_Airline) REFERENCES Airline(Id),
    FOREIGN KEY (Id_Airport) REFERENCES Airport(Id),
    FOREIGN KEY (Id_Movement) REFERENCES Movement(Id)
);


INSERT INTO Airline (Id, Name)
VALUES (1,'Volaris'),
(2,'Aeromar'),
(3,'Interjet'),
(4,'Aeromexico');

INSERT INTO Airport (Id, Name)
VALUES (1,'Benito Juarez'),
(2,'Guanajuato'),
(3,'La paz'),
(4,'Oaxaca');


INSERT INTO Movement (Id, Description)
VALUES (1,'Salida'),
(2,'Llegada');

INSERT INTO Flight (Id_Airline, Id_Airport, Id_Movement, DayOfFlight)
VALUES (1,1,1,'2021-05-02'),
(2,1,1,'2021-05-02'),
(3,2,2,'2021-05-02'),
(4,3,2,'2021-05-02'),
(1,3,2,'2021-05-02'),
(2,1,1,'2021-05-02'),
(2,3,1,'2021-05-04'),
(3,4,1,'2021-05-04'),
(3,4,1,'2021-05-04');

drop procedure if exists sp_get_airport_with_most_movement;
delimiter //
CREATE PROCEDURE sp_get_airport_with_most_movement(yearToCheck int)
BEGIN
	select ar.Name as AirportName, COUNT(*) as TotalMovements 
		from Flight f 
		inner join Airline al on f.Id_Airline = al.Id 
		inner join Airport ar on f.Id_Airport = ar.Id 
		inner join Movement m on f.Id_Movement = m.Id 
		where YEAR(f.DayOfFlight) = yearToCheck
		group by ar.Id, m.Id   
		having count(*) = (	
			SELECT MAX(TotalMovements) 
				FROM (
				select ar.Name, COUNT(*) as TotalMovements 
					from Flight f 
					inner join Airline al on f.Id_Airline = al.Id 
					inner join Airport ar on f.Id_Airport = ar.Id 
					inner join Movement m on f.Id_Movement = m.Id 
					where YEAR(f.DayOfFlight) = yearToCheck
					group by ar.Id, m.Id  
					order by COUNT(*) desc 
				) AS MaxAirportResult
		);	
END//
delimiter ;

drop procedure if exists sp_get_airline_with_most_flights;
delimiter //
CREATE PROCEDURE sp_get_airline_with_most_flights(yearToCheck int)
BEGIN
	select al.Name as AirlineName, COUNT(*) as TotalFlights 
		from Flight f 
		inner join Airline al on f.Id_Airline = al.Id 
		inner join Airport ar on f.Id_Airport = ar.Id 
		inner join Movement m on f.Id_Movement = m.Id 
		where YEAR(f.DayOfFlight) = yearToCheck
		group by al.Id 
		having count(*) = (	
			SELECT MAX(TotalFlights) 
				FROM (
				select al.Name, COUNT(*) as TotalFlights 
					from Flight f 
					inner join Airline al on f.Id_Airline = al.Id 
					inner join Airport ar on f.Id_Airport = ar.Id 
					inner join Movement m on f.Id_Movement = m.Id 
					where YEAR(f.DayOfFlight) = yearToCheck
					group by al.Id 
					order by COUNT(*) 
				) AS MaxAirlineResult
		);
END//
delimiter ;
 
drop procedure if exists sp_get_day_with_most_flights;
delimiter //
CREATE PROCEDURE sp_get_day_with_most_flights(yearToCheck int)
BEGIN
	select f.DayOfFlight, COUNT(*) as TotalFlights 
		from Flight f 
		inner join Airline al on f.Id_Airline = al.Id 
		inner join Airport ar on f.Id_Airport = ar.Id 
		inner join Movement m on f.Id_Movement = m.Id 
		where YEAR(f.DayOfFlight) = yearToCheck
		group by f.DayOfFlight 		
		having count(*) = (	
			SELECT MAX(TotalFlights) 
				FROM (
				select f.DayOfFlight, COUNT(*) as TotalFlights 
					from Flight f 
					inner join Airline al on f.Id_Airline = al.Id 
					inner join Airport ar on f.Id_Airport = ar.Id 
					inner join Movement m on f.Id_Movement = m.Id 
					where YEAR(f.DayOfFlight) = yearToCheck
					group by f.DayOfFlight 				 
				) AS MaxDayOfFlightResult
		);
END//
delimiter ;

drop procedure if exists sp_get_airlines_with_more_than_2flights;
delimiter //
CREATE PROCEDURE sp_get_airlines_with_more_than_2flights()
BEGIN
	select DISTINCT Name as AirlineName
		FROM (
		select al.Name, COUNT(*) as TotalFlights
			from Flight f 
			inner join Airline al on f.Id_Airline = al.Id 
			inner join Airport ar on f.Id_Airport = ar.Id 
			inner join Movement m on f.Id_Movement = m.Id 	
			group by al.Id, f.DayOfFlight
			having count(*) > 2
	) AS AirlinesWith2FLights;
END//
delimiter ;
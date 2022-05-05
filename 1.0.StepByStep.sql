/***********************************************************************************************************************************
--- MONITORIZAÇÃO ATIVA
--- 1.0.StepByStep
***********************************************************************************************************************************/
------------------------------------------------------------------
-- 0) Pré-Requisitos para utilizar esses Scripts
-- 0) Prerequisite to use this scripts
------------------------------------------------------------------
--Test the stored procedure Whoisactive
exec sp_whoisactive 

--Antes de continuar, garanta que o envio de e-mail na sua instância SQL Server está funcionando.
--Before you continue, make sure that your SQL Server Instance is able to send emails

--------------------------------------------------------------------------------------------------------------------------------
-- 1) Criar um operator para utilizar nos jobs e uma database para armazenar os dados
-- 1) Create an operator to use on Jobs and a new Database to store the data
--------------------------------------------------------------------------------------------------------------------------------
-- DBA Team and Client
USE [msdb]
	
if not exists (
select NULL
from msdb.dbo.sysoperators
where name = 'DBA_Operator' )
begin 
	EXEC [msdb].[dbo].[sp_add_operator]
			@name = N'DBA_Operator',
			@enabled = 1,
			@pager_days = 0,
			@email_address = N'dbasqlserver2021@gmail.com'	-- To put more Emails: 'EMail1@provedor.com;EMail2@provedor.com'	

end

-- Only DBA Team
USE [msdb]
	
if not exists (
select NULL
from msdb.dbo.sysoperators
where name = 'DBA_Team_Operator' )
begin 
	EXEC [msdb].[dbo].[sp_add_operator]
			@name = N'DBA_Team_Operator',
			@enabled = 1,
			@pager_days = 0,
			@email_address = N'dbasqlserver2021@gmail.com'	-- To put more Emails: 'EMail1@provedor.com;EMail2@provedor.com'	

end


--Criar uma database para armazenar as informações. Eu utilizo uma database chamada MonitorizacaoAtiva. Caso queira utilizar outra, terá que alterar todo o script para a base com o seu nome.
--We need a Database to store our scripts. I use a database named [MonitorizacaoAtiva] to all of my scripts, if you wish to use another name, you need to replace you database name by [MonitorizacaoAtiva] within the whole script.
GO
	CREATE DATABASE [MonitorizacaoAtiva] 
		ON  PRIMARY ( 
			NAME = N'MonitorizacaoAtiva', FILENAME = N'C:\DATA\MonitorizacaoAtiva.mdf' , -- Alter to a real path
			SIZE = 102400KB , FILEGROWTH = 102400KB 
		)
		LOG ON ( 
			NAME = N'MonitorizacaoAtiva_log', FILENAME = N'C:\DATA\MonitorizacaoAtiva_log.ldf',  -- Alter to a real path
			SIZE = 30720KB , FILEGROWTH = 30720KB 
		)
	GO

	ALTER DATABASE [MonitorizacaoAtiva] SET RECOVERY SIMPLE

-------------------------------------------------------------------------------------------------

	USE MonitorizacaoAtiva
	
	-- Tabela para ignorar algumas bases não importantes de algumas rotinas no ambiente, como por exemplo o Checkdb.
	--Table used to ignore some databases from jobs like CheckDB
	
	IF ( OBJECT_ID('[dbo].[Ignore_Databases]') IS NOT NULL )
		DROP TABLE [dbo].Ignore_Databases
		
	CREATE TABLE [dbo].[Ignore_Databases] (
		[Nm_Database] VARCHAR(500)
	)

	-- If you want to ignore some databases, just insert it here.
	-- Se você quiser ignotar alguma database, insira ela aqui.
	INSERT INTO [Ignore_Databases]
	VALUES('master'),('model'),('msdb')

--Corpabreu
--CorpAbreu2012
--------------------------------------------------------------------------------------------------------------------------------
--2) Executar alguns scripts de outros arquivos
--2) Execute some scripts from other files
--------------------------------------------------------------------------------------------------------------------------------
-- RUN Script: "2.0 - Create Alert Table.sql"
USE MonitorizacaoAtiva

-- exec stpConfiguration_Table 'Email1@provedor.com;Email2@provedor.com', @Profile, @Fl_Language --(1 - Portuguese | 0 -- English)
   exec stpConfiguration_Table 'dbasqlserver2021@gmail.com','DBA-SqlServer', 1 --(1 - Portuguese | 0 -- English)

   
UPDATE [dbo].Alert_Parameter SET  Ds_Email = 'dbasqlserver2021@gmail.com' where Id_Alert_Parameter = 23




--Check the Parameters
select * from [dbo].Alert_Parameter


-- RUN Script: "2.1 - Create All Alert Procedures and Jobs.sql"

--Criar os alertas de severidade. Esses alertas não funcionam no Managed Instance do Azure.
--Create the Alerts of Severity. DO NOT run this stored procedure for an Azure Managed Instance Environment. For Azure Managed Instances, please find it at the end of this script.

EXEC stpAlert_Severity

-- Utilize esses scripts para testar os alertas já criados
-- Use this script to test some of the created alerts

-- EXEC dbo.stpTest_Alerts

--------------------------------------------------------------------------------------------------------------------------------
-- 3)	Se tiver interesse, pode criar algumas rotinas adicionais para o seu banco de dados. Você tem que entender o que essas rotinas fazem antes de criar. 
--      Tenha cuidado. Se não conhece SQL Server talvez seja melhor pular esse item 3.0 e ir para o item 4 dos scripts.
-- 3)	If you wish, you can create additional jobs and Alerts for your databases. But be carefull, you must be aware about what these routines do before you create it. Also be carefull, If you are not a SQL Server DBA or if you don't have a good doaming of it, maybe you should skip to step 4 of this setup.
--------------------------------------------------------------------------------------------------------------------------------

---------------------3.1)  Job to execute a checkdb on databases and an alert if we have some corrupted database. 

--Script: "3.1 - CheckDB - Job and Alert.sql"

---------------------3.2) Profile to monitor what is taking more than xxxx seconds to run and an alert if that number is too high in the last five minutes

--Script: "3.2 - Profile Duration - Job and Alert.sql"

-- obs.: Feel free to change for a XEvents here

select * FROM fn_trace_getinfo (null)

------ Test the server side MonitorizacaoAtiva
waitfor delay '00:00:05'

--Execute the job
EXEC msdb.dbo.sp_start_job N'DBA - Load Server Side Trace';  

--Confira o resultado
select * from MonitorizacaoAtiva..Queries_Profile order by StartTime desc


---------------------3.3) XEvent to monitor database errors and a daily alert information about them

--Script: "3.3 - XEvent Error - Job and Alert.sql"

select 1/0

--Run the job
EXEC msdb.dbo.sp_start_job N'DBA - Load XEvent Database Error';  

select * from MonitorizacaoAtiva..Log_DB_Error


---------------------3.4) Store information about index fragmentation daily

--Script: "3.4 - Index Fragmentation History.sql"

--Open the procedure to execute and test (remove the 6 am lock to test)

SELECT * FROM [dbo].[Index_Fragmentation_History]



---------------------3.5) XEvent to monitor database Dealocks and a daily alert information about them

--Script: "3.5 - Deadlock - Job and Alert.sql"
/*
--To Test
create table test1 (id int)

insert into test1 values (1)

create table test2 (id int)

insert into test2 values (2)

-- Connection 1
BEGIN TRAN
	UPDATE test1
	SET id = id

	UPDATE test2
	SET id = id

--commit


-- Connection 2
BEGIN TRAN
	UPDATE test2
	SET id = id

	UPDATE test1
	SET id = id


EXEC msdb.dbo.sp_start_job N'DBA - Load XEvent Deadlock'


SELECT * FROM MonitorizacaoAtiva.[dbo].[Log_DeadLock]

DROP TABLE teste1
DROP TABLE teste2
*/
---------------------3.6) Log to monitor the whoisactive every minute

--Script: "3.6 - Log Whoisactive.sql"

--Test in another connection
WAITFOR DELAY '00:01:00'

--run the job
EXEC msdb.dbo.sp_start_job N'DBA - Load Whoisactive'

SELECT * FROM dbo.Log_Whoisactive


--------------------------------------------------------------------------------------------------------------------------------
-- 4) Execute este script para criar o checklist do banco de dados
-- 4) Execute this script to create the database checklist
--------------------------------------------------------------------------------------------------------------------------------

-- RUN Script: "4.0 - Procedures CheckList.sql"

-- Run the checklist job to test
EXEC msdb.dbo.sp_start_job N'DBA - CheckList SQL Server Instance';  

-- Finish!!!

--RUN Script 4.1
--RUN Script 5.0
--Configurar DatabaseMail segundo o implementado noutro servidor
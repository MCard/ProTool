/**************************************************************************
* NiSource NiPADS - Deployment Script
*
* Project: Forecasting Import/Export Spreadsheet
*
* Description: New stored procedures used by the Excel VBA code.
* By: Mike Card, Centric Consulting, 630-768-1986
* Date: 3/18/2013
*
* Schema Objects:
* [ProTool].[fGetUserId]			- Gets the current user Id and removes the domain name and backslash. If a user name is not provided obtains the id from the SQL User_Name function.
* [ProTool].[fGetUserRole]			- Gets the 1st AD Group associated to the ProTool application that the provided User ID is a member of.
* [ProTool].[fIsUserAdmin]			- Checks if the user is a member of an Admin AD Group. Returns 1 (true) if user is an Admin; 0 (false) if not. 
* [ProTool].[fIsForecastDateLocked] - Checks if the provided date is during the lock period for submitting forecast estimates for the month of the 
*										provided date and provided user role. Returns 1 (true) if submit month not allowed; Returns 0 (false) if allowed.
* [ProTool].[AddAuditsFromSql]		- Inserts a log event into the Audits table for the provided arguments. 
*										Designed for use from other SQL stored procedures.
* [ProTool].[GetForecastHeader]		- Gets the project and forecast header data including status for the provided 
*										company code, proj #, and year.
* [ProTool].[GetForecastByCategory] - Gets the latest version of monthly forecast estimates and budget approval by category for the provided 
*										company code, proj #, and year. 
* [ProTool].[UpdateForecastFromExcel] - Updates a single row in the Forecast table with the provided values using special business logic.
* [ProTool].[GetCompanyList]		- Gets a list of companies for populating a Dropdown control.
***************************************************************************/
USE ProTool
GO

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET ANSI_WARNINGS ON
GO

/*********************
** Get User Id
**********************/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ProTool].[fGetUserId]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [ProTool].[fGetUserId]
Print 'Creating Function [ProTool].[fGetUserId]'
GO
/* =================================================
-- SUMMARY: Gets the current user Id and removes the domain name and backslash. 
--          If a user name is not provided obtains the id from the SQL User_Name function.
-- 
-- DATE			DEVELOPER			  CHANGE HISTORY
----------------------------------------------------
-- 03/21/2013   Mike Card, Centric    Created
--
-- UNIT TESTS
-- SELECT [ProTool].[fGetUserId](NULL)  -- should return User_Name
-- SELECT [ProTool].[fGetUserId]('NA\U909674') -- s/b U909674
-- SELECT [ProTool].[fGetUserId]('U909674')	-- s/b same as param value
-- ================================================= */
CREATE FUNCTION [ProTool].[fGetUserId]
  ( 
	@userId varchar(10)
  )
RETURNS varchar(10)
AS
 BEGIN
	DECLARE @userRole varchar(50)

	IF @userId IS NULL
	  BEGIN
		SELECT @userId = ISNULL(CAST(USER_NAME() as varchar(10)), '')
	  END
	ELSE 
	  BEGIN
		SELECT @userId = LTRIM(RTRIM(@userId))
	  END

	DECLARE @slashPos int
	SELECT @slashPos = CHARINDEX('\', @userId)
	IF @slashPos > 0 
		SELECT @userId = SUBSTRING(@userId, @slashPos + 1, LEN(@userId) - @slashPos)

	RETURN @userId
 END
GO
Print 'Granting Execute permissions on function [ProTool].[fGetUserId]'
GRANT EXECUTE ON [ProTool].[fGetUserId] TO [db_FieldCostTracker]
GO
IF (EXISTS(SELECT * FROM sys.database_principals WHERE name = N'developers' AND type = 'R'))
GRANT EXECUTE ON [ProTool].[fGetUserId] TO [developers]
GO

/*********************
** Get User Role
**********************/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ProTool].[fGetUserRole]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [ProTool].[fGetUserRole]
Print 'Creating Function [ProTool].[fGetUserRole]'
GO
/* =================================================
-- SUMMARY: Gets the 1st AD Group associated to the ProTool 
--          application that the provided User ID is a member of.
-- 
-- DATE			DEVELOPER			  CHANGE HISTORY
----------------------------------------------------
-- 03/21/2013   Mike Card, Centric    Created
--
-- UNIT TESTS
-- SELECT [ProTool].[fGetUserRole](NULL)  -- s/b NULL
-- SELECT [ProTool].[fGetUserRole]('U909674') -- s/b USER
-- SELECT [ProTool].[fGetUserRole]('U907461') -- s/b ADMIN
-- SELECT [ProTool].[fGetUserRole]('U906007')	-- s/b ADMIN
-- ================================================= */
CREATE FUNCTION [ProTool].[fGetUserRole]
  ( 
	@UserId varchar(10)
  )
RETURNS varchar(50)
AS
 BEGIN
	DECLARE @userRole varchar(50)

	SELECT DISTINCT TOP 1 @userRole = LTRIM(RTRIM(RoleID))
	FROM AppServices.AppServices.dbo.RoleMembers
	WHERE UserID = @UserId AND APPID = 'ProTool'

	RETURN @userRole
 END
GO
Print 'Granting Execute permissions on function [ProTool].[fGetUserRole]'
GRANT EXECUTE ON [ProTool].[fGetUserRole] TO [db_FieldCostTracker]
GO
IF (EXISTS(SELECT * FROM sys.database_principals WHERE name = N'developers' AND type = 'R'))
GRANT EXECUTE ON [ProTool].[fGetUserRole] TO [developers]
GO

/*********************
** Is User Admin
**********************/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ProTool].[fIsUserAdmin]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [ProTool].[fIsUserAdmin]
Print 'Creating Function [ProTool].[fIsUserAdmin]'
GO
/* =================================================
-- SUMMARY: Checks if the user is a member of an Admin AD Group.
--          Returns 1 (true) if user is an Admin; 0 (false) if not.
-- 
-- DATE			DEVELOPER			  CHANGE HISTORY
----------------------------------------------------
-- 03/21/2013   Mike Card, Centric    Created
--
-- UNIT TESTS
-- SELECT [ProTool].[fIsUserAdmin](NULL)  -- s/b 0
-- SELECT [ProTool].[fIsUserAdmin]('Admin') -- s/b 1
-- SELECT [ProTool].[fIsUserAdmin]('User')	-- s/b 0
-- ================================================= */
CREATE FUNCTION [ProTool].[fIsUserAdmin]
  ( 
	@userRole varchar(50)
  )
RETURNS bit
AS
 BEGIN
	DECLARE @isAdmin bit
	IF @userRole = 'ADMIN' OR @userRole = 'IT_ADMIN'
	  BEGIN
		SET @isAdmin = 1
	  END
	ELSE 
	  BEGIN
		SET @isAdmin = 0
	  END
	RETURN @isAdmin
 END
GO
Print 'Granting Execute permissions on function [ProTool].[fIsUserAdmin]'
GRANT EXECUTE ON [ProTool].[fIsUserAdmin] TO [db_FieldCostTracker]
GO
IF (EXISTS(SELECT * FROM sys.database_principals WHERE name = N'developers' AND type = 'R'))
GRANT EXECUTE ON [ProTool].[fIsUserAdmin] TO [developers]
GO

/*********************
** Is Forecast Date Locked
**********************/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ProTool].[fIsForecastDateLocked]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [ProTool].[fIsForecastDateLocked]
Print 'Creating Function [ProTool].[fIsForecastDateLocked]'
GO
/* =================================================
-- SUMMARY: Checks if the provided date is during the lock period
--          for submitting forecast estimates for the month of the 
--          provided date and provided user role. 
--          Returns 1 (true) if submit month not allowed; Returns 0 (false) if allowed.
-- 
-- DATE			DEVELOPER			  CHANGE HISTORY
----------------------------------------------------
-- 03/18/2013   Mike Card, Centric    Created
--
-- UNIT TESTS
-- SELECT * FROM LockingDatebyMonth (nolock) WHERE ID IN (3)
-- SELECT [ProTool].[fIsForecastDateLocked]('3/13/2013', 'ADMIN') -- 0
-- SELECT [ProTool].[fIsForecastDateLocked]('3/14/2013', 'ADMIN') -- 1
-- SELECT [ProTool].[fIsForecastDateLocked]('3/11/2013', 'USER')  -- 0
-- SELECT [ProTool].[fIsForecastDateLocked]('3/12/2013', 'USER')  -- 1
-- SELECT [ProTool].[fIsForecastDateLocked]('3/10/2013', NULL)    -- 0
-- ================================================= */
CREATE FUNCTION [ProTool].[fIsForecastDateLocked]
  ( 
	@currentDate datetime,
	@userRole varchar(50)
   )
RETURNS bit
AS
 BEGIN
	DECLARE @month int,
			@day int,
			@lockDay int,
			@isLocked bit
			
	-- get month and day portion
	SELECT @month = MONTH(@currentDate), @day = DAY(@currentDate)
	
	-- get lock day of month
	SELECT @lockDay = CASE WHEN [ProTool].fIsUserAdmin(@userRole) = 1 THEN AdminDateToLock ELSE DateToLock END
	FROM ProTool.LockingDateByMonth
	WHERE ID = @month
	
	-- return result
	IF @day > @lockDay
		SET @isLocked = 1
	ELSE
		SET @isLocked = 0
		
	RETURN @isLocked
 END
GO
Print 'Granting Execute permissions on function [ProTool].[fIsForecastDateLocked]'
GRANT EXECUTE ON [ProTool].[fIsForecastDateLocked] TO [db_FieldCostTracker]
GO
IF (EXISTS(SELECT * FROM sys.database_principals WHERE name = N'developers' AND type = 'R'))
GRANT EXECUTE ON [ProTool].[fIsForecastDateLocked] TO [developers]
GO

/*********************
** Add Audits from SQL object
**********************/
if exists(select * from dbo.sysobjects where id = OBJECT_ID(N'[ProTool].[AddAuditsFromSql]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [ProTool].[AddAuditsFromSql]
Print 'Creating Stored Procedure [ProTool].[AddAuditsFromSql]'
GO
/* =================================================
-- SUMMARY: Inserts a log event into the Audits table 
--          for the provided arguments. Designed for use
--          from other SQL stored procedures.
-- 
-- DATE			DEVELOPER			  CHANGE HISTORY
----------------------------------------------------
-- 03/21/2013   Mike Card, Centric    Created
--
-- UNIT TESTS
-- EXEC [ProTool].[AddAuditsFromSql] 'TCO', '17024', '2013', 5, 51, NULL, 'U909674'
-- SELECT * FROM ProTool.Audits (NOLOCK) WHERE User_ID = 'U909674' ORDER BY Audit_ID DESC
-- DELETE ProTool.Audits WHERE User_ID = 'U909674' 
-- ================================================= */
CREATE PROCEDURE [ProTool].[AddAuditsFromSql]  
	@Company_Cd varchar(3),  
	@Project_No int,  
	@Estimate_Year varchar(4),  
	@Version_No smallint,  
	@Audit_Event_ID int,  
	@Audit_Date datetime = NULL,
	@User_ID varchar(10) = NULL,  
	@User_Role varchar(50) = NULL,
	@Scope_Version_No smallint = NULL
AS
	DECLARE @isAdmin bit,
			@userAuditId int

	-- get audit event date
	IF @Audit_Date IS NULL
		SELECT @Audit_Date = GETDATE()

	-- get audit user
	SELECT @User_ID = [ProTool].[fGetUserId](@User_ID)
	--IF @User_ID IS NULL
	--	SELECT @User_ID = CAST(USER_NAME() as varchar(10))

	-- get user role
	IF @User_Role IS NULL
		SELECT @User_Role = [ProTool].[fGetUserRole](@User_ID)

	-- is admin?
	SELECT @isAdmin = [ProTool].fIsUserAdmin(@User_Role)

	-- increment user's audit id
	SELECT @userAuditId = ISNULL(MAX(Audit_ID) + 1, 1)
	FROM ProTool.Audits (NOLOCK)
	WHERE [User_ID] = @User_ID

	-- insert a single event.
	INSERT INTO [ProTool].[Audits]   
	  ([Company_Cd]
	  ,[Project_No]
	  ,[User_ID]
	  ,[Audit_ID]
	  ,[Audit_Event_ID]
	  ,[Audit_Date]
	  ,[Version_No]
	  ,[Estimate_Year]
	  ,[Scope_Version_No]
	  ,[Admin_Fl])   
	VALUES   
	 (@Company_Cd
	  ,@Project_No
	  ,@User_ID
	  ,@userAuditId
	  ,@Audit_Event_ID
	  ,@Audit_Date
	  ,@Version_No
	  ,@Estimate_Year
	  ,@Scope_Version_No
	  ,@isAdmin)  
GO
Print 'Granting Execute permissions on Stored Procedure [ProTool].[AddAuditsFromSql]'
GRANT EXECUTE ON [ProTool].[AddAuditsFromSql] TO [db_FieldCostTracker]
GO
IF (EXISTS(SELECT * FROM sys.database_principals WHERE name = N'developers' AND type = 'R'))
GRANT EXECUTE ON [ProTool].[AddAuditsFromSql] TO [developers]
GO

/*********************
** Get Estimates Project Header
**********************/
if exists(select * from dbo.sysobjects where id = OBJECT_ID(N'[ProTool].[GetForecastHeader]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [ProTool].[GetForecastHeader]
Print 'Creating Stored Procedure [ProTool].[GetForecastHeader]'
GO
/* =================================================
-- SUMMARY: Gets the project and forecast header data including 
--          status for the provided company code, proj #, and year.
-- 
-- DATE			DEVELOPER			  CHANGE HISTORY
----------------------------------------------------
-- 03/18/2013   Mike Card, Centric    Created
--
-- UNIT TESTS
-- EXEC [ProTool].[GetForecastHeader] 'TCO', 17024, '2013'
-- EXEC [ProTool].[GetForecastHeader] 'TCO', 17024, '2013', 'U909674'
-- EXEC [ProTool].[GetForecastHeader] 'NMS', 10, '2013', 'U906007' -- admin
-- EXEC [ProTool].[GetForecastHeader] 'NMS', 10, '2013'
-- ================================================= */
CREATE PROCEDURE [ProTool].[GetForecastHeader]
	@companyCode varchar(3),
	@projectNo int,
	@year varchar(4),
	@userId varchar(10) = NULL
AS
 BEGIN
	SET NOCOUNT ON
	
	DECLARE @version smallint,
		@projectName varchar(80),
		@categoryType varchar(50), 
		@projStatusCode smallint,
		@projStatus varchar(50),
		@userRole varchar(10),
		@currentMonthLocked bit,
		@lastUpdateUser varchar(10),
		@lastUpdateDate datetime,
		@userSubmitLocked bit,
		@userUnlockDate varchar(10), 
		@currentDate datetime

	SELECT @currentDate = GETDATE()

	-- get security info 
	SELECT @userId = [ProTool].[fGetUserId](@userId)
	--IF @userId IS NULL
	--  BEGIN
	--	SELECT @userId = ISNULL(CAST(USER_NAME() as varchar(10)), '')
	--	DECLARE @slashPos int
	--	SELECT @slashPos = CHARINDEX('\', @userId)
	--	IF @slashPos > 0 
	--		SELECT @userId = SUBSTRING(@userId, @slashPos + 1, LEN(@userId) - @slashPos)
	--  END
	SELECT @userRole = [ProTool].[fGetUserRole](@userId)
	SELECT @currentMonthLocked = [ProTool].fIsForecastDateLocked(@currentDate, @userRole)
	IF @currentMonthLocked = 1 AND @userRole <> 'ADMIN' AND [ProTool].fIsForecastDateLocked(@currentDate, 'ADMIN') = 0
	  BEGIN
		SET @userSubmitLocked = 1
		DECLARE @adminLockDate int
		SELECT @adminLockDate = AdminDateToLock FROM LockingDatebyMonth WHERE ID = MONTH(@currentDate)
		SELECT @userUnlockDate = CAST(MONTH(@currentDate) as varchar(2)) + '/' 
							+ CAST((@adminLockDate + 1) as varchar(2)) + '/' 
							+ CAST(YEAR(@currentDate) as varchar(4))
	  END
	ELSE
	  BEGIN
		SET @userSubmitLocked = 0
		SET @userUnlockDate = ''
	  END
		
	-- first verify company code and proj no
	SELECT @projStatusCode = p.Project_Status_Cd
		, @projStatus = s.Project_Status_Name
		, @projectName = p.Title
	FROM ProTool.Projects p
	LEFT JOIN ProTool.ProjectStatus s ON s.Project_Status_Cd = p.Project_Status_Cd
	WHERE Company_Cd = @companyCode AND Project_No = @projectNo
	
	IF @projStatus IS NOT NULL
	  BEGIN
		-- get latest/current version
		SELECT @version = MAX(Version_No)
		FROM [ProTool].[EstimateYearByCategories] 
		WHERE Company_Cd=@companyCode AND Project_No=@projectNo AND Estimate_Year=@year

		IF @version IS NOT NULL
		  BEGIN
			-- get category type
			SELECT @categoryType = CASE WHEN Cost_Category_Type = 1 THEN 'Summary' ELSE 'Detail' END
			FROM [ProTool].[Estimates] (NOLOCK)
			WHERE Company_Cd = @companyCode 
				AND Project_No = @projectNo 
				AND Version_No = @version
			IF @categoryType IS NULL
			  BEGIN
				-- get category type (try obtaining from Budget as backup)
				SELECT @categoryType = c.Cost_Category_Type
				FROM [ProTool].[CostCategories] c 
				JOIN 
					(SELECT TOP 1 Cost_Category_Cd
					FROM [ProTool].[EstimateYearByCategories] 
					WHERE Company_Cd = @companyCode AND Project_No = @projectNo 
						AND Estimate_Year = @year AND Version_No = @version) b
					ON c.Cost_Category_Cd = b.Cost_Category_Cd
			  END
		  END
		ELSE
		  BEGIN
			-- budget year not found.
			SET @year = NULL
			--SET @categoryType = NULL
		  END
	  END
	ELSE
	  BEGIN
		-- company/proj not found.
		SET @companyCode = NULL
		SET @projectNo = NULL
		SET @year = NULL
		--SET @version = NULL
		--SET @categoryType = NULL
		--SET @projStatus = NULL
	  END

	-- get last update user/date
	SELECT @lastUpdateDate = MAX(Audit_Date)
	FROM ProTool.Audits (NOLOCK)
	WHERE Company_Cd = @companyCode
		AND Project_No = @projectNo
		AND Estimate_Year = @year
		AND Version_No = @version
		AND Audit_Event_ID IN (1, 25, 52)
	
	IF @lastUpdateDate IS NOT NULL
	  BEGIN
		SELECT @lastUpdateUser = User_ID
		FROM ProTool.Audits (NOLOCK)
		WHERE Company_Cd = @companyCode
			AND Project_No = @projectNo
			AND Estimate_Year = @year
			AND Version_No = @version
			AND Audit_Date = @lastUpdateDate
			AND Audit_Event_ID IN (1, 25, 52)
	  END

	-- return header results
	SELECT @companyCode as Company_Cd 
		  ,@projectNo as Project_No
		  ,@year as Estimate_Year
		  ,@version as Version_No
		  ,@projectName as Project_Title
		  ,@projStatusCode as Project_Status_Cd
		  ,@projStatus as Project_Status_Name
		  ,@categoryType as Cost_Category_Type
		  ,@userId as [User_Id]
		  ,@userRole as [User_Role]
		  ,@currentMonthLocked as Current_Month_Locked
		  ,@lastUpdateDate as Last_Update_Date
		  ,@lastUpdateUser as Last_Update_User
		  ,@userSubmitLocked as User_Submit_Locked
		  ,@userUnlockDate as User_Unlock_Date
		  
 END
GO	
Print 'Granting Execute permissions on Stored Procedure [ProTool].[GetForecastHeader]'
GRANT EXECUTE ON [ProTool].[GetForecastHeader] TO [db_FieldCostTracker]
GO
IF (EXISTS(SELECT * FROM sys.database_principals WHERE name = N'developers' AND type = 'R'))
GRANT EXECUTE ON [ProTool].[GetForecastHeader] TO [developers]
GO

/*********************
** Get Estimate Years By Category
**********************/
if exists(select * from dbo.sysobjects where id = OBJECT_ID(N'[ProTool].[GetForecastByCategory]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [ProTool].[GetForecastByCategory]
Print 'Creating Stored Procedure [ProTool].[GetForecastByCategory]'
GO
/* =================================================
-- SUMMARY: Gets the latest version of monthly forecast estimates 
--          and budget approval by category for the provided 
--          company code, proj #, and year.
-- 
-- DATE			DEVELOPER			  CHANGE HISTORY
----------------------------------------------------
-- 03/18/2013   Mike Card, Centric    Created
--
-- UNIT TESTS
-- EXEC [ProTool].[GetForecastByCategory] 'TCO', '17024', '2013', 'U909674'
-- EXEC [ProTool].[GetForecastByCategory] 'TCO', '17024', '2013'
-- SELECT TOP 5 * FROM [ProTool].[Audits] (nolock) WHERE Audit_Event_ID = 51 ORDER BY Audit_Date DESC
-- ================================================= */
CREATE PROCEDURE [ProTool].[GetForecastByCategory]
	@companyCode varchar(3),
	@projectNo int,
	@year varchar(4),
	@userID varchar(10) = NULL 
AS
 BEGIN
	SET NOCOUNT ON
	
	DECLARE @version smallint,
		@categoryType varchar(50), 
		@defaultCount smallint,
		@forecastCount smallint,
		@auditUser varchar(10)

	-- get audit user and date
	SELECT @auditUser = ISNULL(@userID, CAST(USER_NAME() as varchar(10)))

	-- get latest/current version
	SELECT @version = MAX(Version_No)
	FROM [ProTool].[EstimateYearByCategories] 
	WHERE Company_Cd=@companyCode AND Project_No=@projectNo AND Estimate_Year=@year

	-- get category type 
	SELECT @categoryType = CASE WHEN Cost_Category_Type = 1 THEN 'Summary' ELSE 'Detail' END
		FROM [ProTool].[Estimates] (NOLOCK)
		WHERE Company_Cd = @companyCode 
			AND Project_No = @projectNo 
			AND Version_No = @version

			IF @categoryType IS NULL
			  BEGIN
				-- get category type (try obtaining from Budget as backup)
				SELECT @categoryType = c.Cost_Category_Type
				FROM [ProTool].[CostCategories] c 
				JOIN 
					(SELECT TOP 1 Cost_Category_Cd
					FROM [ProTool].[EstimateYearByCategories] 
					WHERE Company_Cd = @companyCode AND Project_No = @projectNo 
						AND Estimate_Year = @year AND Version_No = @version) b
					ON c.Cost_Category_Cd = b.Cost_Category_Cd
			  END

	-- check if forcast rows already created by comparing with budget category counts.
	SELECT @defaultCount = COUNT(*)
	FROM [ProTool].[CostCategories] (NOLOCK)
	WHERE Cost_Category_Type = @categoryType
		AND Capital_Active_Fl = 1

	SELECT @forecastCount = COUNT(*)
	FROM [ProTool].[Forecast] f (NOLOCK)
	JOIN [ProTool].[CostCategories] cc (NOLOCK)
		ON cc.Cost_Category_Cd = f.Cost_Category_Cd
	WHERE Company_Cd=@companyCode AND Project_No=@projectNo 
		AND Estimate_Year=@year AND Version_No = @version
		AND cc.Capital_Active_Fl = 1

	IF @defaultCount > @forecastCount
	  BEGIN
		-- create missing forecast rows
		INSERT INTO [ProTool].[Forecast]
	           ([Company_Cd]
	           ,[Project_No]
	           ,[Estimate_Year]
	           ,[Version_No]
	           ,[Cost_Category_Cd])
	     SELECT @companyCode
	           ,@projectNo
	           ,@year
	           ,@version
	           ,cc.[Cost_Category_Cd]
	      FROM [ProTool].[CostCategories] cc
	      LEFT JOIN [ProTool].[Forecast] f ON (f.[Company_Cd] = @companyCode
													AND f.[Project_No] = @projectNo
													AND f.[Estimate_Year] = @year
													AND f.[Version_No] = @version 
													AND f.[Cost_Category_Cd] = cc.[Cost_Category_Cd])
		WHERE f.Company_Cd IS NULL
			AND cc.Cost_Category_Type = @categoryType
			AND cc.Capital_Active_Fl = 1
	  END

	-- log event for Audit
	EXECUTE [ProTool].[AddAuditsFromSql] 
		 @companyCode
		,@projectNo
		,@year
		,@version
		,51
		,NULL
		,@auditUser

	-- return result forecasting rows 
	SELECT	f.[Company_Cd]
			,f.[Project_No]
	        ,f.[Estimate_Year]
	        ,f.[Version_No]
			,f.[Cost_Category_Cd]   
			,c.[Cost_Category_Desc]
			,b.[Amount] as Budget_Amount
			,f.[January]
			,f.[February]
			,f.[March]
			,f.[April]
			,f.[May]
			,f.[June]
			,f.[July]
			,f.[August]
			,f.[September]
			,f.[October]
			,f.[November]
			,f.[December]
	  FROM [ProTool].[Forecast] f
	  LEFT JOIN [ProTool].[EstimateYearByCategories] b ON (f.[Company_Cd] = b.[Company_Cd]
														AND f.[Project_No] = b.[Project_No]
														AND f.[Estimate_Year] = b.[Estimate_Year]
														AND f.[Version_No] = b.[Version_No] 
														AND f.[Cost_Category_Cd] = b.[Cost_Category_Cd])
	  JOIN [ProTool].[CostCategories] c ON c.Cost_Category_Cd = f.Cost_Category_Cd
	  WHERE f.Company_Cd = @companyCode AND f.Project_No = @projectNo 
			AND f.Estimate_Year = @year AND f.Version_No = @version
			AND c.Cost_Category_Type = @categoryType
			AND c.Capital_Active_Fl = 1
	  ORDER BY f.Cost_Category_Cd --c.Capital_Display_Order, c.OM_Display_Order, c.Cost_Category_Key
 END
GO
Print 'Granting Execute permissions on Stored Procedure [ProTool].[GetForecastByCategory]'
GRANT EXECUTE ON [ProTool].[GetForecastByCategory] TO [db_FieldCostTracker]
GO
IF (EXISTS(SELECT * FROM sys.database_principals WHERE name = N'developers' AND type = 'R'))
GRANT EXECUTE ON [ProTool].[GetForecastByCategory] TO [developers]
GO
		
/*********************
** Update Estimates With Monthly Forecast
**********************/
if exists(select * from dbo.sysobjects where id = OBJECT_ID(N'[ProTool].[UpdateForecastFromExcel]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [ProTool].[UpdateForecastFromExcel]
Print 'Creating Stored Procedure [ProTool].[UpdateForecastFromExcel]'
GO
/* =================================================
-- SUMMARY: Updates a single row in the Forecast table
--          with the provided values using special business logic.
-- 
-- DATE			DEVELOPER			  CHANGE HISTORY
----------------------------------------------------
-- 03/15/2013   Mike Card, Centric    Created
--
-- UNIT TESTS
-- EXEC [ProTool].[UpdateForecastFromExcel] 'TCO', 17024, '2013', 101, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200, 1, 'U909674'
-- EXEC [ProTool].[UpdateForecastFromExcel] 'TCO', 17024, '2013', 129, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200, 0, 'U909674'
-- EXEC [ProTool].[UpdateForecastFromExcel] 'TCO', 17024, '2013', 118, 100, 200, 300, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1
-- EXEC [ProTool].[UpdateForecastFromExcel] 'TCO', 17024, '2013', 129, 100, 200, 300, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0
-- SELECT TOP 5 * FROM [ProTool].[Audits] (nolock) WHERE Audit_Event_ID = 52 ORDER BY Audit_Date DESC
-- ================================================= */
CREATE PROCEDURE [ProTool].[UpdateForecastFromExcel]
	@companyCode varchar(3),
	@projectNo int,
	@year varchar(4),
	@costCategoryCode smallint,
	@January float = NULL,
	@February float = NULL,
	@March float = NULL,
	@April float = NULL,
	@May float = NULL,
	@June float = NULL,
	@July float = NULL,
	@August float = NULL,
	@September float = NULL,
	@October float = NULL,
	@November float = NULL,
	@December float = NULL,
	@IsFirstGroup bit,
	@userID varchar(10) = NULL
AS
 BEGIN
	SET NOCOUNT ON
	
	DECLARE @version smallint,
			@auditUser varchar(10),
			@auditDate datetime,
			@userRole varchar(10),
			@currentMonthLocked bit,
			@month int,
			@sql varchar(8000),
			@isSuccess bit
	SET @isSuccess = 0

	-- get audit user and date
	SELECT @auditUser = [ProTool].[fGetUserId](@userID), @auditDate = GETDATE()
	--SELECT @auditUser = ISNULL(@userID, CAST(USER_NAME() as varchar(10))), @auditDate = GETDATE()

	-- get user permission info 
	SELECT @userRole = [ProTool].[fGetUserRole](@auditUser)
	SELECT @currentMonthLocked = [ProTool].fIsForecastDateLocked(@auditDate, @userRole)
	SELECT @month = MONTH(@auditDate)

	-- get latest/current version
	SELECT @version = MAX(Version_No)
	FROM [ProTool].[Forecast] 
	WHERE Company_Cd = @companyCode AND Project_No = @projectNo AND Estimate_Year = @year

	BEGIN TRAN
	BEGIN TRY
		-- build update sql using special permissions logic
		IF (@month < 12 OR (@month = 12 AND @currentMonthLocked = 0))
		  BEGIN
			SET @sql = 'UPDATE [ProTool].[Forecast] SET '
			IF (@month <= 1 AND @currentMonthLocked = 0)
				SET @sql = @sql + '[January] = ' + ISNULL(CAST(@January as varchar(50)), '0') + ', '
			
			IF (@month < 2 OR (@month = 2 AND @currentMonthLocked = 0))
				SET @sql = @sql + '[February] = ' + ISNULL(CAST(@February as varchar(50)), '0') + ', '
			
			IF (@month < 3 OR (@month = 3 AND @currentMonthLocked = 0))
				SET @sql = @sql + '[March] = ' + ISNULL(CAST(@March as varchar(50)), '0') + ', '
			
			IF (@month < 4 OR (@month = 4 AND @currentMonthLocked = 0))
				SET @sql = @sql + '[April] = ' + ISNULL(CAST(@April as varchar(50)), '0') + ', '
			
			IF (@month < 5 OR (@month = 5 AND @currentMonthLocked = 0))
				SET @sql = @sql + '[May] = ' + ISNULL(CAST(@May as varchar(50)), '0') + ', '
			
			IF (@month < 6 OR (@month = 6 AND @currentMonthLocked = 0))
				SET @sql = @sql + '[June] = ' + ISNULL(CAST(@June as varchar(50)), '0') + ', '
			
			IF (@month < 7 OR (@month = 7 AND @currentMonthLocked = 0))
				SET @sql = @sql + '[July] = ' + ISNULL(CAST(@July as varchar(50)), '0') + ', '
			
			IF (@month < 8 OR (@month = 8 AND @currentMonthLocked = 0))
				SET @sql = @sql + '[August] = ' + ISNULL(CAST(@August as varchar(50)), '0') + ', '
			
			IF (@month < 9 OR (@month = 9 AND @currentMonthLocked = 0))
				SET @sql = @sql + '[September] = ' + ISNULL(CAST(@September as varchar(50)), '0') + ', '
			
			IF (@month < 10 OR (@month = 10 AND @currentMonthLocked = 0))
				SET @sql = @sql + '[October] = ' + ISNULL(CAST(@October as varchar(50)), '0') + ', '
			
			IF (@month < 11 OR (@month = 11 AND @currentMonthLocked = 0))
				SET @sql = @sql + '[November] = ' + ISNULL(CAST(@November as varchar(50)), '0') + ', '
			
			SET @sql = @sql + '[December] = ' + ISNULL(CAST(@December as varchar(50)), '0') + ', '
			SET @sql = @sql + '[User_ID] = ''' + @auditUser 
							+ ''', [Trans_Date] = ''' + CAST(@auditDate as varchar(50)) 
							+ ''' WHERE Company_Cd = ''' + @companyCode 
							+ ''' AND Project_No = ' + CAST(@projectNo as varchar(50))
							+ ' AND Estimate_Year = ''' + @year 
							+ ''' AND Version_No = ' + CAST(@version as varchar(50))
							+ ' AND Cost_Category_Cd = ' + CAST(@costCategoryCode as varchar(50))
							+ ' AND (SELECT COUNT(*) FROM [ProTool].[CostCategories] WHERE'
							+ ' Cost_Category_Cd = ' + CAST(@costCategoryCode as varchar(50))
							+ ' AND Capital_Active_Fl = 1) = 1'
			--SELECT @sql as Query 
			EXECUTE(@sql)
			IF @@ROWCOUNT > 0
				SET @isSuccess = 1

			-- Add Audit log entry. only once for all group category updates.
			IF @IsFirstGroup = 1 AND @isSuccess = 1
			  BEGIN
				EXECUTE [ProTool].[AddAuditsFromSql] 
					 @companyCode
					,@projectNo
					,@year
					,@version
					,52
					,@auditDate
					,@auditUser
					,@userRole
			  END
		  END

		  -- return success results
		  SELECT @isSuccess as Success
				,@auditUser as [Update_User]
				,@auditDate as [Update_Date]
				,'' as [Error_Message]
				
		  COMMIT TRAN
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN
		SET @isSuccess = 0

		DECLARE @ErrMsg varchar(8000)
		SELECT @ErrMsg = 'SQL Error occurred in stored procedure [ProTool].[UpdateForecastFromExcel] on line '
			+ CAST(ERROR_LINE() as varchar) + '. Error Number: ' 
			+ CAST(ERROR_NUMBER() as varchar(30)) + ', Error Message: ' + ERROR_MESSAGE()

		-- return fail results
		SELECT @isSuccess as Success
			,@auditUser as [Update_User]
			,@auditDate as [Update_Date]
			,@ErrMsg as [Error_Message]


	END CATCH
 END
GO	
Print 'Granting Execute permissions on Stored Procedure [ProTool].[UpdateForecastFromExcel]'
GRANT EXECUTE ON [ProTool].[UpdateForecastFromExcel] TO [db_FieldCostTracker]
GO
IF (EXISTS(SELECT * FROM sys.database_principals WHERE name = N'developers' AND type = 'R'))
GRANT EXECUTE ON [ProTool].[UpdateForecastFromExcel] TO [developers]
GO

/*********************
** Get Company List
**********************/
if exists(select * from dbo.sysobjects where id = OBJECT_ID(N'[ProTool].[GetCompanyList]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [ProTool].[GetCompanyList]
Print 'Creating Stored Procedure [ProTool].[GetCompanyList]'
GO
/* =================================================
-- SUMMARY: Gets a list of companies for populating 
--          a Dropdown control.
-- 
-- DATE			DEVELOPER			  CHANGE HISTORY
----------------------------------------------------
-- 03/27/2013   Mike Card, Centric    Created
--
-- UNIT TESTS
-- EXEC [ProTool].[GetCompanyList] 
-- EXEC [ProTool].[GetCompanyList] 'TCO'
-- ================================================= */
CREATE PROCEDURE [ProTool].[GetCompanyList]
	@selectedId varchar(3) = NULL
AS
 BEGIN
	SET NOCOUNT ON
	
	SELECT Company_Cd as Id
		, Company_Cd + ' ' + Company_Name as Name
	FROM ProTool.Company (nolock)
	WHERE Active_Fl = 1
		OR (@selectedId IS NOT NULL 
			AND Company_Cd = @selectedId) -- include previously selected.
	ORDER BY Company_Cd
 END
GO	
Print 'Granting Execute permissions on Stored Procedure [ProTool].[GetCompanyList]'
GRANT EXECUTE ON [ProTool].[GetCompanyList] TO [db_FieldCostTracker]
GO
IF (EXISTS(SELECT * FROM sys.database_principals WHERE name = N'developers' AND type = 'R'))
GRANT EXECUTE ON [ProTool].[GetCompanyList] TO [developers]
GO

USE [ProTool_Staging]
GO

/****** Object:  StoredProcedure [ProTool].[GetSettingValue]    Script Date: 04/17/2013 09:14:58 ******/
Print 'Alter Stored Procedure [ProTool].[GetSettingValue]'
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* =================================================
-- SUMMARY: Gets the setting value for the provided setting name.
-- 
-- DATE			DEVELOPER			  CHANGE HISTORY
----------------------------------------------------
-- 03/20/2013   Mike Card, Centric    Created
-- 04/17/2013   Mike Card             Correction to not return two rowsets.
--
-- UNIT TESTS
-- EXEC [ProTool].[GetSettingValue] 'MaximoWebServiceUrl'	-- success 
-- EXEC [ProTool].[GetSettingValue] 'BogusSettingName'		-- should return null
-- EXEC [ProTool].[GetSettingValue] 'ForecastGetDataRoles'
-- EXEC [ProTool].[GetSettingValue] 'ForecastSaveDataRoles'
-- ================================================= */
ALTER PROCEDURE [ProTool].[GetSettingValue]
	@name varchar(50)
AS
 BEGIN
	SET NOCOUNT ON

	IF (SELECT COUNT(*) FROM ProTool.Settings WHERE Name = @name AND Active = 1) = 0
	  BEGIN
		-- return Null to indicate setting not found or not active.
		SELECT NULL as [Value]
	  END
	ELSE
	  BEGIN
		-- return setting value or empty string if null. Empty string indicates setting name was found.
		SELECT ISNULL([Value], '') as [Value]
		FROM ProTool.Settings
		WHERE Name = @name AND Active = 1
	  END
 END
GO

-- Note: This is needed because sproc [ProTool].[UpdateForecastFromExcel] uses dynamic sql to update the Forecast table.
Print 'Granting Select,Insert,Update permissions on table [ProTool].[Forecast] to role [db_FieldCostTracker].'
GRANT SELECT,INSERT,UPDATE ON [ProTool].[Forecast] TO [db_FieldCostTracker]
GO
Print 'Granting Select,Insert,Update permissions on table [ProTool].[CostCategories] to role [db_FieldCostTracker].'
GRANT SELECT,INSERT,UPDATE ON [ProTool].[CostCategories] TO [db_FieldCostTracker]
GO
		
/**********************
--       DATA 
***********************/
Print 'Inserting Data into [ProTool].[Settings] table.'		
-- New Setting: ForecastGetDataRoles
IF (SELECT COUNT(*) FROM [ProTool].[Settings] WHERE [Name] = 'ForecastGetDataRoles') = 0
INSERT INTO [ProTool].[Settings]
           ([Name]
           ,[Value]
           ,[Description]
           ,[Active])
     VALUES
           ('ForecastGetDataRoles'
           ,'|USER|ADMIN|MARKET_DEV|EC_MANAGER|'
           ,'List of ProTool roles that have permission to get data using the Forecast Import/Export Excel Workbook. Always wrap each role with the pipe character.'
           ,1)

-- New Setting: ForecastSaveDataRoles
IF (SELECT COUNT(*) FROM [ProTool].[Settings] WHERE [Name] = 'ForecastSaveDataRoles') = 0
INSERT INTO [ProTool].[Settings]
           ([Name]
           ,[Value]
           ,[Description]
           ,[Active])
     VALUES
           ('ForecastSaveDataRoles'
           ,'|USER|ADMIN|MARKET_DEV|EC_MANAGER|'
           ,'List of ProTool roles that have permission to get data using the Forecast Import/Export Excel Workbook. Always wrap each role with the pipe character.'
           ,1)
GO






		
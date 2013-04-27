/**************************************************************************
* NiSource NiPADS - Deployment Script
*
* Project: ProTool Reporting Enhancements
*
* Description: Changes to existing stored procedures used by Reporting Web Service
* By: Mike Card, Centric Consulting, 630-768-1986
* Date: 4/9/2013
*
* Schema Objects:
* [ProTool].[crosstab] - bug fix. increased output parameters to avoid truncated strings.
* [ProTool].[GetProjectExtract] - Removed columns and logic for specific, retired cost categories.
* [ProTool].[ProgramAnnualEstimates] - Removed retired cost category columns no longer used.
* [ProTool].[AnnualEstimates] - Removed retired cost category columns no longer used.
* [ProTool].[ReportForecastTotalsByCategory] - Gets the forecast totals by cost category for the 
*                           provided company and project. Returns 2 table result sets for report processing.
* [ProTool].[ReportProjectChangeRequest_Main] - Gets the ScopeChanges header data for the 
*                           Project Change Request report.
* [ProTool].[ReportProjectChangeRequest_CostImpact] - Gets the Cost Impact subreport data for 
*                           the Project Change Request report.
***************************************************************************/
USE [ProTool_Staging]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

USE [ProTool_Staging]
GO

/****** Object:  StoredProcedure [ProTool].[crosstab]    Script Date: 04/10/2013 11:12:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Print 'Altering Stored Procedure [ProTool].[crosstab]'
GO
ALTER      PROCEDURE [ProTool].[crosstab] 
@select varchar(1000),
@sumfunc varchar(100), 
@pivot varchar(100), 
@table varchar(100),
@where varchar(1000)='1=1',
@select1 varchar(8000) OUTPUT,
@selectlist varchar(8000) OUTPUT
AS
BEGIN
DECLARE @sql varchar(4000), @delim varchar(1)

SET NOCOUNT ON
SET ANSI_WARNINGS OFF

EXEC ('SELECT ' + @pivot + ' AS pivot INTO ##pivot FROM ' + @table + ' WHERE 1=2')
EXEC ('INSERT INTO ##pivot SELECT DISTINCT ' + @pivot + ' FROM ' + @table + ' WHERE ' 
+ @where + ' AND ' + @pivot + ' Is Not Null')

SELECT @sql='', @selectlist='', @sumfunc=stuff(@sumfunc, len(@sumfunc), 1, ' END)' )

SELECT @delim=CASE Sign( CharIndex('char', data_type)+CharIndex('date', data_type) ) 
WHEN 0 THEN '' ELSE '''' END 
FROM tempdb.information_schema.columns 
WHERE table_name='##pivot' AND column_name='pivot'

SELECT @sql=@sql + '''' + convert(varchar(100), pivot) + ''' = ' + 
stuff(@sumfunc,charindex( '(', @sumfunc )+1, 0, ' CASE ' + @pivot + ' WHEN ' 
+ '''' + convert(varchar(100), pivot) + '''' + ' THEN ' ) + ', ' FROM ##pivot


SELECT @selectlist=@selectlist + ' IsNull(' + '[' + convert(varchar(100),pivot) + '], ''Not Selected'') as ' + '''' + convert(varchar(100),pivot) + '''' + ',' FROM ##pivot

DROP TABLE ##pivot

SELECT @sql=left(@sql, len(@sql)-1)
SELECT @select1=stuff(@select, charindex(' FROM ', @select)+1, 0, ', ' + @sql + ' ')

SET ANSI_WARNINGS ON

END
GO

/****** Object:  StoredProcedure [ProTool].[GetProjectExtract]    Script Date: 04/09/2013 09:43:27 ******/
Print 'Drop and Create Stored Procedure [ProTool].[GetProjectExtract]'
if exists(select * from dbo.sysobjects where id = OBJECT_ID(N'[ProTool].[GetProjectExtract]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [ProTool].[GetProjectExtract]
GO
/* =================================================
-- SUMMARY: ProTool reporting stored procedure.
-- 
-- DATE			DEVELOPER			  CHANGE HISTORY
----------------------------------------------------
-- 5/2/2008 10:59 AM,  Unknown		  Initially Created
-- 04/10/2013   Mike Card, Centric    Removed columns and logic for specific, retired cost categories.
--
-- UNIT TESTS
-- EXEC [ProTool].[GetProjectExtract] '2013', 'TCO', 1, ' AND p.Project_No IN (17024) '
-- EXEC [ProTool].[GetProjectExtract] '2013', 'TCO', 2, NULL
-- ================================================= */
CREATE PROCEDURE [ProTool].[GetProjectExtract] 
@Estimate_Year varchar(4),
@Company_Cd varchar(3),
@Project_Type_Cd smallint,
@Project_List varchar(8000),
@Project_List_2 varchar(8000) = NULL,
@Project_List_3 varchar(8000) = NULL,
@Project_List_4 varchar(8000) = NULL,
@Project_List_5 varchar(8000) = NULL,
@Project_List_6 varchar(8000) = NULL,
@Project_List_7 varchar(8000) = NULL
AS
BEGIN

IF @Project_List IS NULL
	SET @Project_List = ''
IF @Project_List_2 IS NULL
	SET @Project_List_2 = ''
IF @Project_List_3 IS NULL
	SET @Project_List_3 = ''
IF @Project_List_4 IS NULL
	SET @Project_List_4 = ''
IF @Project_List_5 IS NULL
	SET @Project_List_5 = ''
IF @Project_List_6 IS NULL
	SET @Project_List_6 = ''
IF @Project_List_7 IS NULL
	SET @Project_List_7 = ''

DECLARE @select1 varchar(8000)
DECLARE @Group_Name varchar(8000)
DECLARE @Role_Name varchar(8000)
DECLARE @Priority_Desc varchar(8000)
DECLARE @selectlist varchar(8000)
DECLARE @selectlisttotal varchar(8000)
DECLARE @Where varchar(1000)
DECLARE @YTD_Flag varchar(100)
--DECLARE @sql text

--change these local variables to parameter inputs when converted to stored procedure
--SELECT @Estimate_Year='2004', @Company_Cd='TCO', @Project_Type_Cd='1'

SELECT @Where = '((ProTool.Groups.Capital_Active_Fl=1 AND ' + CAST(@Project_Type_Cd as varchar) + '=1) OR (ProTool.Groups.OM_Active_Fl=1 AND ' + CAST(@Project_Type_Cd as varchar) + '=2))' 
EXEC ProTool.Crosstab
 	'SELECT ProTool.ProjectGroups.Company_Cd, ProTool.ProjectGroups.Project_No From ProTool.ProjectGroups Inner Join ProTool.GroupValues ON ProTool.ProjectGroups.Group_ID=ProTool.GroupValues.Group_Cd AND ProTool.ProjectGroups.Group_Value_Cd=ProTool.GroupValues.Group_Value_Cd INNER JOIN ProTool.Groups ON ProTool.Groups.Group_Cd=ProTool.ProjectGroups.Group_Id GROUP BY ProTool.ProjectGroups.Company_Cd,ProjectGroups.Project_No',
 	'MAX(Group_Value_Name)',
	'Group_Name',
 	'ProTool.Groups',
	@Where,
	@select1 = @select1 OUTPUT,
	@selectlist = @selectlist OUTPUT

SELECT @Group_Name = ISNULL(@select1, '')
IF @Group_Name > ''
  BEGIN
	SELECT @Group_Name = 
	  ' left join (' + @Group_Name + ') as g '
	+ ' ON p.Company_Cd=g.Company_Cd AND p.Project_No=g.Project_No'
  END 
SELECT @selectlisttotal = @selectlist

SELECT @Where = '((ProTool.ProjectRoles.Capital_Active_Fl=1 AND ' + CAST(@Project_Type_Cd as varchar) + '=1) OR (ProTool.ProjectRoles.OM_Active_Fl=1 AND ' + CAST(@Project_Type_Cd as varchar) + '=2))' 
EXEC ProTool.Crosstab
	'SELECT P1.Company_Cd, P1.Project_No From (SELECT ProjectPeople.*,Users.UserName FROM ProjectPeople INNER JOIN Users on ProjectPeople.User_ID=Users.UserID WHERE Users.UserID IS NOT NULL) P1 Inner Join ProjectRoles on P1.Project_Role_Cd=ProjectRoles.Project_Role_Cd GROUP BY P1.Company_Cd, P1.Project_No',
	'Max(UserName)',	
	'Project_Role_Name',
	'ProjectRoles',
	@select1 = @select1 OUTPUT,
	@selectlist = @selectlist OUTPUT

SELECT @Role_Name = ISNULL(@select1, '')
IF @Role_Name > ''
  BEGIN
    SELECT @Role_Name = 
 	  ' left join (' + @Role_Name + ') as r '
	+ ' ON p.Company_Cd=r.Company_Cd AND p.Project_No=r.Project_No'
  END

SELECT @selectlisttotal = @selectlisttotal + @selectlist

SELECT @Where = '((ProTool.Priorities.Capital_Active_Fl=1 AND ' + CAST(@Project_Type_Cd as varchar) + '=1) OR (ProTool.Priorities.OM_Active_Fl=1 AND ' + CAST(@Project_Type_Cd as varchar) + '=2))' 
EXEC ProTool.Crosstab
	'SELECT ProjectPriorities.Company_Cd, ProjectPriorities.Project_No FROM ProjectPriorities Inner Join Priorities on ProjectPriorities.Priority_Cd = Priorities.Priority_Cd Inner Join PriorityLevels ON Priorities.Priority_Level_Cd = PriorityLevels.Priority_Level_Cd GROUP BY ProjectPriorities.Company_Cd, ProjectPriorities.Project_No',
	'MAX(Priority_Level_Desc)',
	'Priority_Desc',
	'Priorities',
	@select1 = @select1 OUTPUT,
	@selectlist = @selectlist OUTPUT

IF @selectList IS NULL
	SET @selectList = ''
	
SELECT @Priority_Desc = ISNULL(@select1, '')
IF @Priority_Desc > ''
  BEGIN
    SELECT @Priority_Desc =
	+ ' left join (' + @Priority_Desc + ') as pr '
	+ ' ON p.Company_Cd=pr.Company_Cd AND p.Project_No=pr.Project_No'
  END

SELECT @selectlisttotal = @selectlisttotal + @selectlist

IF @Company_Cd<>'All'
BEGIN
SELECT @Where = ' where p.Company_Cd=''' + @Company_Cd + ''' AND p.Project_Type_Cd=' + CAST(@Project_Type_Cd as varchar) + ' AND p.Project_System_Status_Cd=1 '
END
ELSE
SELECT @Where = ' where p.Project_Type_Cd=' + CAST(@Project_Type_Cd as varchar) + 'AND p.Project_System_Status_Cd=1 '

IF @Estimate_Year = Year(GetDate())
BEGIN
SELECT @YTD_Flag = ' SumExp.Exp_Voucher_Year='+@Estimate_Year+' AND SumExp.Exp_Voucher_Month <= MONTH(getDate())'
END
ELSE
SELECT @YTD_Flag = + ' SumExp.Exp_Voucher_Year='+@Estimate_Year

--NOTE: These commented out "SELECT (" and ") as Query" lines are for debugging purposes.
--     This Stored proc should be completely refactored using temp tables, PIVOT, etc., but 
--     no time allowed, so in order to debug just remove the EXEC and uncomment the lines. 
--		Then, copy past the multiple query fragments to a new query window and try executing the 
--      resulting dynamic query.  Remmember to recomment and add the EXE back before deploying to test.
--SELECT 
EXEC('select p.Company_Cd as Company,'
	+ ' p.Project_No as [Project Number],'
	+ ' pt.Project_Type_Name as [Project Type],'
	+ ' p.Title as [Project Title], '
	+ ' Users.UserName as [Originating Person],'
	+ ' IsNull(p.Facility_Id,''None'') as [Facility ID],'	
	+ ' IsNull(fac.Description, ''None'') as [Facility Name],'
 	+ ' IsNull(p.Work_Management_Id,''None'') as [Work Management ID],'
	+ ' IsNull(p.Cost_Center, ''None'') as [Cost Center],'
	+ ' ps.Project_Status_Name as [Project Status],'
	+ ' fs.Funding_Source_Name as [Funding Source],'
	+ ' IsNull(fbt.Funding_Basket_Type_Name,''Not Selected'') as [Funding Basket Type],'
	+ ' IsNull(fbl.Basket_Level_Name, ''Not Selected'') as [Funding Level],'
	+ ' p.Multi_Year_Fl as [Multi Year Flag],'
	+ ' p.Mandatory_Fl as [Mandatory Flag], '
	+ ' IsNull(CONVERT(CHAR(8),ProjRev.Audit_Date,10),'''') as [Project Reviewed Date], '
	+ @selectlisttotal
	+ ' IsNull(OrigEstVerTPA.[Original Estimate Version - Total Project Amount],0) as [Original Estimate Version - Total Project Amount],'
 	+ ' IsNull(MaxLockedEstVerTPA.[Max Locked Estimate Version],0) as [Max Locked Estimate Version],'
 	+ ' IsNull(MaxLockedEstVerTPA.[Max Locked Estimate Version - Total Project Amount],0) as [Max Locked Estimate Version - Total Project Amount],'
 	+ ' IsNull(MaxEstVerTPA.[Max Estimate Version],0) as [Max Estimate Version],'
 	+ ' IsNull(MaxEstVerTPA.[Max Estimate Version - Total Project Amount],0) as [Max Estimate Version - Total Project Amount],'
	+ ' SelYearATS.Version_No as [ '+ @Estimate_Year + ' - Approved To Spend, Estimate Version Number],'
	+ ' IsNull(SelYearATS.Approved_To_Spend_Gross,0) as [ ' + @Estimate_Year + '  - Approved To Spend, Gross Project Cost for Year],'
	+ ' IsNull(SelYearATS.Billings,0) as [ ' + @Estimate_Year + '  - Approved To Spend, Calculated Billings],'
	+ ' IsNull(SelYearATS.Approved_To_Spend_Net,0) as [ ' + @Estimate_Year + '  - Approved To Spend, Net Project Cost for Year],'
	+ ' IsNull(SelYearTotalGross.Approved_To_Spend_Gross,0) as [ ' + @Estimate_Year + '  - Approved to Spend, Total Gross Project Estimate All Years],'
	+ ' IsNull(SelYearOP.Original_Program_Gross,0) as [ ' + @Estimate_Year + '  - Original Program, Gross Project Cost for Year],'
	+ ' IsNull(SelYearOP.Billings,0) as [ ' + @Estimate_Year + '  - Original Program, Calculated Billings],'
--) AS [Query];
--SELECT (
	+ ' IsNull(SelYearOP.Original_Program_Net,0) as [ ' + @Estimate_Year + '  - Original Program, Net Project Cost for Year],'
	+ ' IsNull(SelYearTotalGross.Original_Program_Gross,0) as [ ' + @Estimate_Year + '  - Original Program, Total Gross Project Estimate All Years],'
	+ ' IsNull(SelYearPP.Preliminary_Program_Gross,0) as [ ' + @Estimate_Year + '  - Preliminary Program, Gross Project Cost for Year],'
	+ ' IsNull(SelYearPP.Billings,0) as [ ' + @Estimate_Year + '  - Preliminary Program, Calculated Billings],'
	+ ' IsNull(SelYearPP.Preliminary_Program_Net,0) as [ ' + @Estimate_Year + '  - Preliminary Program, Net Project Cost for Year],'
	+ ' IsNull(SelYearTotalGross.Preliminary_Program_Gross,0) as [ ' + @Estimate_Year + '  - Preliminary Program, Total Gross Project Estimate All Years],'
	+ ' IsNull(SelYearPE.Gross,0) as [ ' + @Estimate_Year + '  - Present Estimate, Gross Project Cost for Year],'
	+ ' IsNull(SelYearPE.Billings,0) as [ ' + @Estimate_Year + '  - Present Estimate, Calculated Billings],'
	+ ' IsNull(SelYearPE.Net,0) as [ ' + @Estimate_Year + '  - Present Estimate, Net Project Cost for Year],'
	+ ' IsNull(CAST(YTDActualsGross.Gross as decimal(20,2)),0) as [YTD Actuals, Gross Project Cost],'
	+ ' IsNull(CAST(YTDActualsNet.Net as decimal(20,2)),0) as [YTD Actuals, Net Project Cost],'
	+ ' IsNull(CAST(PTDActualsGross.Gross as decimal(20,2)),0) as [PTD Actuals, Gross Project Cost],'
	+ ' IsNull(CAST(PTDActualsNet.Net as decimal(20,2)),0) as [PTD Actuals, Net Project Cost]'
	+ ' from ProTool.Projects as p'
	+ ' inner join'
	+ ' (select distinct a1.project_no,a1.company_cd from ProTool.AnnualEstimates as a1 WHERE a1.Estimate_Year=' + @Estimate_Year +') '
	+ ' as pp1 on p.Company_Cd = pp1.Company_Cd and p.project_no = pp1.project_no '
	+ ' inner join'
	+ ' ProTool.ProjectTypes as pt'
	+ ' on'
	+ ' p.Project_Type_Cd=pt.Project_Type_Cd'
	+ ' inner join'
	+ ' Users'
	+ ' on'	
	+ ' p.Originating_Person_Id=Users.UserID'
	+ ' inner join'
	+ ' ProTool.ProjectStatus as ps'
	+ ' on'
	+ ' p.Project_Status_Cd = ps.Project_Status_Cd'
	+ ' inner join'
	+ ' ProTool.FundingSources as fs'
	+ ' on'
	+ ' p.Funding_Source_Cd = fs.Funding_Source_Cd	'
	+ ' left join'
	+ ' ProTool.FundingBasketTypes as fbt'
	+ ' on'
	+ ' p.Funding_Basket_Type_Cd = fbt.Funding_Basket_Type_Cd'
	+ ' left join'
	+ ' ProTool.FundingBasketLevels as fbl'
	+ ' on'
	+ ' p.Funding_Basket_Level_Cd = fbl.Basket_Level_Cd'
	+ ' left join'
	+ ' ProTool.Facilities as fac '
	+ ' on'
	+ ' p.Facility_Id = fac.Facility_Cd '
	+ ' left join'
	+ ' ('
	+ ' SELECT a.Company_Cd'
	+ ' ,a.Project_No'
	+ ' ,SUM(a.Amount) as [Original Estimate Version - Total Project Amount] '
	+ ' From ProTool.EstimateYearByCategories a '
	+ ' Where a.Version_No=1 AND a.Estimate_Year='+@Estimate_Year
	+ ' GROUP BY a.Company_Cd, a.Project_No'
	+ ' ) as OrigEstVerTPA'
	+ ' on	'
	+ ' p.Project_No = OrigEstVerTPA.Project_No AND p.Company_Cd = OrigEstVerTPA.Company_Cd'
	+ ' left join'
	+ ' ('
	+ ' SELECT 	a.Project_No'
	+ ' ,a.Company_Cd'
	+ ' ,a.Version_No as [Max Locked Estimate Version]'
	+ ' ,SUM(a.Amount) as [Max Locked Estimate Version - Total Project Amount]'
	+ ' from ProTool.EstimateYearByCategories as a'
	+ ' where a.Estimate_Year='+@Estimate_Year
	+ ' and a.Version_No in (Select max(Version_No) '
	+ ' from Protool.Estimates est '
	+ ' where est.Project_No = a.Project_No '
	+ ' and est.Company_CD = a.Company_CD and est.Locked_Estimate_Fl=1)'
	+ ' GROUP BY a.Project_No, a.Company_Cd, a.Version_No'
	+ ' ) as MaxLockedEstVerTPA'
	+ ' on'
	+ ' p.Project_No = MaxLockedEstVerTPA.Project_No AND p.Company_Cd = MaxLockedEstVerTPA.Company_Cd'
	+ ' left join'
	+ ' ('
	+ ' SELECT 	a.Project_No'
	+ ' ,a.Company_Cd'
	+ ' ,a.Version_No as [Max Estimate Version]'
	+ ' ,SUM(a.Amount) as [Max Estimate Version - Total Project Amount]'
	+ ' from ProTool.EstimateYearByCategories as a'
	+ ' where a.Estimate_Year='+@Estimate_Year
	+ ' and a.Version_No in (Select max(Version_No) '
	+ ' from Protool.Estimates est '
	+ ' where est.Project_No = a.Project_No '
	+ ' and est.Company_CD = a.Company_CD)'
	+ ' GROUP BY a.Project_No, a.Company_Cd, a.Version_No'
	+ ' ) as MaxEstVerTPA'
	+ ' on'
	+ ' p.Project_No = MaxEstVerTPA.Project_No AND p.Company_Cd = MaxEstVerTPA.Company_Cd'
	+ ' left join'
	+ ' ('
	+ ' SELECT ae.Project_No'
	+ ' ,ae.Company_Cd'
	+ ' ,ae.Version_No '
	+ ' ,ae.Approved_To_Spend_Gross'
	+ ' ,ae.Billings'
	+ ' ,ae.Approved_To_Spend_Net'	
	+ ' FROM ProgramAnnualEstimates ae '
	+ ' WHERE ae.Estimate_Year='+ @Estimate_Year +' AND ae.Year_Approval_Fl=1'
	+ ' ) as SelYearATS'
	+ ' on'
	+ ' p.Company_Cd = SelYearATS.Company_Cd AND p.Project_No = SelYearATS.Project_No'
	+ ' left join'
	+ ' ('
	+ ' SELECT aeTot.Project_No'
	+ ' ,aeTot.Company_Cd'
	+ ' ,SUM(aeTot.Approved_To_Spend_Gross) as Approved_To_Spend_Gross, SUM(aeTot.Original_Program_Gross) as Original_Program_Gross,SUM(aeTot.Preliminary_Program_Gross) as Preliminary_Program_Gross'
	+ ' FROM ProgramAnnualEstimates aeTot '
	+ ' WHERE aeTot.Year_Approval_Fl=1'
	+ ' GROUP BY aeTot.Project_No, aeTot.Company_Cd'
	+ ' ) as SelYearTotalGross'
	+ ' on	'
	+ ' p.Company_Cd = SelYearTotalGross.Company_Cd AND p.Project_No = SelYearTotalGross.Project_No'
	+ ' left join'
	+ ' ('
	+ ' SELECT ae.Project_No'
	+ ' ,ae.Company_Cd'
	+ ' ,ae.Version_No '
	+ ' ,ae.Original_Program_Gross'
	+ ' ,ae.Billings'
	+ ' ,ae.Original_Program_Net'	 	
	+ ' FROM ProgramAnnualEstimates ae '
	+ ' WHERE ae.Estimate_Year='+@Estimate_Year+' AND ae.Original_Program_Fl=1	'
	+ ' ) as SelYearOP'
	+ ' on'
	+ ' p.Company_Cd = SelYearOP.Company_Cd AND p.Project_No = SelYearOP.Project_No'
	+ ' left join'
	+ ' ('
	+ ' SELECT ae.Project_No'
	+ ' ,ae.Company_Cd'
	+ ' ,ae.Version_No '
	+ ' ,ae.Preliminary_Program_Gross'
	+ ' ,ae.Billings'
	+ ' ,ae.Preliminary_Program_Net'	
	+ ' FROM ProgramAnnualEstimates ae '
	+ ' WHERE ae.Estimate_Year='+@Estimate_Year+' AND ae.Preliminary_Program_Fl=1	'
	+ ' ) as SelYearPP'
	+ ' on'
	+ ' p.Company_Cd = SelYearPP.Company_Cd AND p.Project_No = SelYearPP.Project_No'
	+ ' left join'
	+ ' 	('
	+ ' SELECT ae.Project_No'
	+ ' ,ae.Company_Cd'
	+ ' ,ae.Version_No '
	+ ' ,ae.Gross'
	+ ' ,ae.Billings'
	+ ' ,ae.Net	 '	
	+ ' FROM ProgramAnnualEstimates ae '
	+ ' WHERE ae.Estimate_Year='+@Estimate_Year+'	'
	+ ' and ae.Version_No in (Select max(Version_No) '
	+ ' from Protool.Estimates est '
	+ ' where est.Project_No = ae.Project_No '
	+ ' and est.Company_CD = ae.Company_CD)'
	+ ' ) as SelYearPE'
	+ ' on'
	+ ' p.Company_Cd = SelYearPE.Company_Cd AND p.Project_No = SelYearPE.Project_No'
	+ ' left join'
	+ ' ('
--) AS [Query];
--SELECT (
	+ ' SELECT '	
	+ ' SumExp.Company_Cd, '
	+ ' SumExp.Project_No, '
	+ ' SUM(CASE SumExp.Exp_Cost_Category_Cd'
	+ ' WHEN 7 THEN SumExp.Amount ELSE 0 END) as [Billings],'
	+ ' SUM(CASE SumExp.Exp_Cost_Category_Cd'
	+ ' WHEN 8 THEN SumExp.Amount ELSE 0 END) as Accruals,'
	+ ' SUM(CASE SumExp.Exp_Cost_Category_Cd'
	+ ' WHEN 9 THEN SumExp.Amount ELSE 0 END) as Closings'
	+ ' FROM '
	+ ' SummaryExpenditures SumExp '
	+ ' Inner Join '
	+ ' CostCategories CostCat'
	+ ' ON'
	+ ' SumExp.Exp_Cost_Category_Cd = CostCat.Cost_Category_Cd'
	+ ' WHERE'
	+ @YTD_Flag
	+ ' GROUP BY'
	+ ' SumExp.Company_Cd, SumExp.Project_No'
	+ ' ) YTDActuals'
	+ ' on'
	+ ' p.Company_Cd = YTDActuals.Company_Cd AND p.Project_No = YTDActuals.Project_No'
	+ ' left join'
	+ ' ('
	+ ' select SumExp.Project_No,'
	+ ' SumExp.Company_Cd,'
	+ ' SUM(SumExp.Amount) as Gross'
	+ ' from'
	+ ' SummaryExpenditures SumExp'
	+ ' where'
	+ @YTD_Flag
	+ ' and SumExp.Exp_Cost_Category_Cd NOT IN (7,9,10)'
	+ ' group by SumExp.Project_No,'
	+ ' SumExp.Company_Cd	'
	+ ' ) as YTDActualsGross'
	+ ' on'
	+ ' p.Company_Cd = YTDActualsGross.Company_Cd AND p.Project_No = YTDActualsGross.Project_No'
	+ ' left join'
	+ ' ('
	+ ' select SumExp.Project_No,'
	+ ' SumExp.Company_Cd,'
	+ ' SUM(SumExp.Amount) as Net'
	+ ' from'
	+ ' SummaryExpenditures SumExp'
	+ ' where'
	+ @YTD_Flag
	+ ' and SumExp.Exp_Cost_Category_Cd NOT IN (9,10)'
	+ ' group by SumExp.Project_No,'
	+ ' SumExp.Company_Cd	'
	+ ' ) as YTDActualsNet'
	+ ' on'
	+ ' p.Company_Cd = YTDActualsNet.Company_Cd AND p.Project_No = YTDActualsNet.Project_No'
	+ ' left join'
	+ ' ('
	+ ' SELECT 	'
	+ ' SumExp.Company_Cd, '
	+ ' SumExp.Project_No, '
	+ ' SUM(CASE SumExp.Exp_Cost_Category_Cd'
	+ ' WHEN 7 THEN SumExp.Amount ELSE 0 END) as [Billings],'
	+ ' SUM(CASE SumExp.Exp_Cost_Category_Cd'
	+ '			WHEN 8 THEN SumExp.Amount ELSE 0 END) as Accruals,'
	+ ' SUM(CASE SumExp.Exp_Cost_Category_Cd'
	+ ' WHEN 9 THEN SumExp.Amount ELSE 0 END) as Closings'
	+ ' FROM '
	+ ' SummaryExpenditures SumExp '
	+ ' Inner Join '
	+ ' CostCategories CostCat'
	+ ' ON'
	+ ' SumExp.Exp_Cost_Category_Cd = CostCat.Cost_Category_Cd'
	+ ' GROUP BY'
	+ ' SumExp.Company_Cd, SumExp.Project_No'
	+ ' ) PTDActuals'
	+ ' on'
	+ ' p.Company_Cd = PTDActuals.Company_Cd AND p.Project_No = PTDActuals.Project_No'
	+ ' left join'
	+ ' ('
	+ ' select SumExp.Project_No,'
	+ ' SumExp.Company_Cd,'
	+ ' SUM(SumExp.Amount) as Gross'
	+ ' from'
	+ ' SummaryExpenditures SumExp'
	+ ' where'
	+ ' SumExp.Exp_Cost_Category_Cd NOT IN (7,9)'
	+ ' group by SumExp.Project_No,'
	+ ' SumExp.Company_Cd	'
	+ ' ) as PTDActualsGross'
	+ ' on'
	+ ' p.Company_Cd = PTDActualsGross.Company_Cd AND p.Project_No = PTDActualsGross.Project_No'
	+ ' left join'
	+ ' ('
	+ ' select SumExp.Project_No,'
	+ ' SumExp.Company_Cd,'
	+ ' SUM(SumExp.Amount) as Net'
	+ ' from'
	+ ' SummaryExpenditures SumExp'
	+ ' where'
	+ ' SumExp.Exp_Cost_Category_Cd <> 9'
	+ ' group by SumExp.Project_No,'
	+ ' SumExp.Company_Cd'
	+ ' ) as PTDActualsNet'
	+ ' on'
	+ ' p.Company_Cd = PTDActualsNet.Company_Cd AND p.Project_No = PTDActualsNet.Project_No '
	+ ' left join ('
	+ ' SELECT    aud.Company_Cd, aud.Project_No, max(aud.Audit_Date) as Audit_Date '
	+ ' FROM         Audits aud'
	+ ' WHERE     (aud.Audit_Event_ID = 44) GROUP BY aud.Company_Cd, aud.Project_No '
	+ ' ) as ProjRev'
	+ ' on p.Company_cd=ProjRev.Company_cd and p.Project_No=ProjRev.Project_No'
--) AS [Query];
--SELECT (
	+ @Group_Name
 	+ @Role_Name 
	+ @Priority_Desc
	+ @where
	+ @Project_List	+ @Project_List_2 + @Project_List_3	+ @Project_List_4 + @Project_List_5 
	+ @Project_List_6 + @Project_List_7
	+ ' AND Users.UserID IS NOT NULL'
	+ ' order by '
	+ ' p.Company_Cd,p.Project_No')
--AS [Query]

END
GO

Print 'Granting Execute permissions on Stored Procedure [ProTool].[GetProjectExtract]'
GRANT EXECUTE ON [ProTool].[GetProjectExtract] TO [db_FieldCostTracker]
GO
IF (EXISTS(SELECT * FROM sys.database_principals WHERE name = N'developers' AND type = 'R'))
GRANT EXECUTE ON [ProTool].[GetProjectExtract] TO [developers]
GO

/*********************
** Report Forecast Totals By Category
**********************/
if exists(select * from dbo.sysobjects where id = OBJECT_ID(N'[ProTool].[ReportForecastTotalsByCategory]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [ProTool].[ReportForecastTotalsByCategory]
Print 'Creating Stored Procedure [ProTool].[ReportForecastTotalsByCategory]'
GO
/* =================================================
-- SUMMARY: Gets the forecast totals by cost category for the provided company and project. 
--          Returns 2 table result sets for report processing.
-- 
-- DATE			DEVELOPER			  CHANGE HISTORY
----------------------------------------------------
-- 04/19/2013   Mike Card, Centric    Created
--
-- UNIT TESTS
-- EXEC [ProTool].[ReportForecastTotalsByCategory] 'TCO', 17024
-- ================================================= */
CREATE PROCEDURE [ProTool].[ReportForecastTotalsByCategory]
	@companyCode varchar(3),
	@projectNo int
AS
 BEGIN
	SET NOCOUNT ON
	-- Note: This logic supports only 1 project per execution.
	-- ProTool produces multiple reports if user selected more than 1 project no.
	
	DECLARE @version smallint,
		@year varchar(4),
		@categoryType varchar(50),
		@grossYear decimal(19,2),
		@grossTotal decimal(19,2),
		@billingYear decimal(19,2),
		@billingTotal decimal(19,2)

	CREATE TABLE #tblYearVersion(
		[Company_Cd] varchar(3) NOT NULL,
		[Project_No] int NOT NULL,
		[Estimate_Year] varchar(4) NOT NULL,
		[Version_No] smallint NULL)

	CREATE TABLE #tblResults(
		[Company_Cd] varchar(3) NOT NULL,
		[Project_No] int NOT NULL,
		[Year] varchar(4) NOT NULL,
		[Cost_Category_Cd] smallint NOT NULL,
		[Cost_Category_Desc] varchar(75) NOT NULL,
		[Estimate_Year] decimal(19,2) NULL,
		[Estimate_Total] decimal(19,2) NULL,
		[Estimate_Year_Percent] decimal(7,4) NULL,
		[Estimate_Total_Percent] decimal(7,4) NULL)
	CREATE INDEX #ix_tblResults_CompanyCd ON #tblResults([Company_Cd])
	CREATE INDEX #ix_tblResults_ProjNo ON #tblResults([Project_No])
	CREATE INDEX #ix_tblResults_CostCat ON #tblResults([Cost_Category_Cd])

	-- get latest version for each year
	INSERT INTO #tblYearVersion
           ([Company_Cd]
           ,[Project_No]
           ,[Estimate_Year]
           ,[Version_No])
	SELECT [Company_Cd], [Project_No],[Estimate_Year], MAX([Version_No])
	FROM [ProTool].[EstimateYearByCategories] (NOLOCK)
	WHERE Company_Cd=@companyCode AND Project_No=@projectNo
	GROUP BY [Company_Cd], [Project_No],[Estimate_Year]

	-- get latest year and its version
	SELECT @year = MAX([Estimate_Year]) FROM #tblYearVersion
	SELECT @version = [Version_No] FROM #tblYearVersion WHERE [Estimate_Year] = @year

	-- get category type 
	SELECT @categoryType = CASE WHEN Cost_Category_Type = 1 THEN 'Summary' ELSE 'Detail' END
		FROM [ProTool].[Estimates] (NOLOCK)
		WHERE Company_Cd = @companyCode 
			AND Project_No = @projectNo
			AND Version_No = @version

			IF @categoryType IS NULL
			  BEGIN
				-- get category type (try obtaining from Budget as backup since Cost_Category_Type is nullable)
				SELECT @categoryType = c.Cost_Category_Type
				FROM [ProTool].[CostCategories] c 
				JOIN 
					(SELECT TOP 1 Cost_Category_Cd
					FROM [ProTool].[EstimateYearByCategories] 
					WHERE Company_Cd = @companyCode AND Project_No = @projectNo 
						AND Estimate_Year = @year AND Version_No = @version) b
					ON c.Cost_Category_Cd = b.Cost_Category_Cd
			  END

	-------------------------------------
	-- build forecast detail results
	-- 1st, get totals for current year.
	INSERT INTO #tblResults 
		([Company_Cd] 
		,[Project_No] 
		,[Year]
		,[Cost_Category_Cd]
		,[Cost_Category_Desc]
		,[Estimate_Year])
	SELECT	f.[Company_Cd]
			,f.[Project_No]
			,@year
			,f.[Cost_Category_Cd]   
			,c.[Cost_Category_Desc]
			,ISNULL(f.[January], 0)
			+ISNULL(f.[February], 0)
			+ISNULL(f.[March], 0)
			+ISNULL(f.[April], 0)
			+ISNULL(f.[May], 0)
			+ISNULL(f.[June], 0)
			+ISNULL(f.[July], 0)
			+ISNULL(f.[August], 0)
			+ISNULL(f.[September], 0)
			+ISNULL(f.[October], 0)
			+ISNULL(f.[November], 0)
			+ISNULL(f.[December], 0) as Estimate_Year
	  FROM [ProTool].[Forecast] f
	  JOIN [ProTool].[CostCategories] c ON c.Cost_Category_Cd = f.Cost_Category_Cd
	  WHERE f.Company_Cd = @companyCode AND f.Project_No = @projectNo 
			AND f.Estimate_Year = @year AND f.Version_No = @version
			AND c.Cost_Category_Type = @categoryType
			AND c.Capital_Active_Fl = 1
	  ORDER BY f.Cost_Category_Cd 

	-- 2nd, get totals for all years by company, project, cost category
	UPDATE #tblResults SET [Estimate_Total] = [EstimateTotal]
		FROM #tblResults r
		JOIN (SELECT 
				f.Company_Cd
				,f.Project_No
				,f.Cost_Category_Cd
				,SUM(ISNULL(f.[January], 0)
				+ISNULL(f.[February], 0)
				+ISNULL(f.[March], 0)
				+ISNULL(f.[April], 0)
				+ISNULL(f.[May], 0)
				+ISNULL(f.[June], 0)
				+ISNULL(f.[July], 0)
				+ISNULL(f.[August], 0)
				+ISNULL(f.[September], 0)
				+ISNULL(f.[October], 0)
				+ISNULL(f.[November], 0)
				+ISNULL(f.[December], 0)) as [EstimateTotal]
				FROM [ProTool].[Forecast] f
				JOIN [ProTool].[CostCategories] c ON c.Cost_Category_Cd = f.Cost_Category_Cd
				JOIN #tblYearVersion yv 
					ON (yv.Company_Cd = f.Company_Cd AND yv.Project_No = f.Project_No
					AND yv.Estimate_Year = f.Estimate_Year AND yv.Version_No = f.Version_No)
				WHERE c.Cost_Category_Type = @categoryType
					AND c.Capital_Active_Fl = 1
				GROUP BY f.Company_Cd, f.Project_No, f.Cost_Category_Cd) as fc
			ON (fc.Company_Cd = r.Company_Cd AND fc.Project_No = r.Project_No
				AND fc.Cost_Category_Cd = r.Cost_Category_Cd)

	-- 3rd, calculate Gross totals  
	SELECT @grossYear = SUM([Estimate_Year])
		, @grossTotal = SUM([Estimate_Total])
	FROM #tblResults

	-- 4th, calculate percentages
	UPDATE #tblResults SET 
		[Estimate_Year_Percent] = CASE WHEN @grossYear <> 0 
									THEN ([Estimate_Year] / @grossYear)
									ELSE 0 END
		,[Estimate_Total_Percent] = CASE WHEN @grossTotal <> 0 
									THEN ([Estimate_Total] / @grossTotal)
									ELSE 0 END

	-- 5th, calculate billings
	SELECT 
	    @billingYear = CASE WHEN ISNULL([Fixed_Amount], 0) = 0 
							THEN [Billable_Pct] * @grossYear
							ELSE [Fixed_Amount] END
	    ,@billingTotal = CASE WHEN ISNULL([Fixed_Amount], 0) = 0 
							THEN [Billable_Pct] * @grossTotal
							ELSE [Fixed_Amount] END
	FROM ProTool.EstimateBillings
	WHERE Company_Cd = @companyCode AND Project_No = @projectNo 

	-- insert Gross Totals row
	INSERT INTO #tblResults 
		([Company_Cd] 
		,[Project_No] 
		,[Year]
		,[Cost_Category_Cd]
		,[Cost_Category_Desc]
		,[Estimate_Year]
		,[Estimate_Total])
	VALUES (@companyCode
		,@projectNo
		,@year
		,31991
		,'Gross Project Costs'
		,@grossYear
		,@grossTotal)
	
	-- insert Billings row
	INSERT INTO #tblResults 
		([Company_Cd] 
		,[Project_No] 
		,[Year]
		,[Cost_Category_Cd]
		,[Cost_Category_Desc]
		,[Estimate_Year]
		,[Estimate_Total])
	VALUES (@companyCode
		,@projectNo
		,@year
		,31992
		,'Billings'
		,@billingYear
		,@billingTotal)

	-- insert Net Totals row
	INSERT INTO #tblResults 
		([Company_Cd] 
		,[Project_No] 
		,[Year]
		,[Cost_Category_Cd]
		,[Cost_Category_Desc]
		,[Estimate_Year]
		,[Estimate_Total])
	VALUES (@companyCode
		,@projectNo
		,@year
		,31993
		,'Net Project Costs'
		,(@grossYear - @billingYear)
		,(@grossTotal - @billingTotal))

	-------------------------------------
	-- return result set (multi-rows)
	SELECT [Company_Cd] 
		,[Project_No]
		,[Year]
		,[Cost_Category_Cd] 
		,[Cost_Category_Desc] 
		,[Estimate_Year] 
		,[Estimate_Total] 
		,[Estimate_Year_Percent] 
		,[Estimate_Total_Percent] 
	FROM #tblResults
	ORDER BY [Company_Cd],[Project_No],[Cost_Category_Cd] 
	
	-- clean up temp tables.
	DROP TABLE #tblYearVersion
	DROP TABLE #tblResults

 END
GO
Print 'Granting Execute permissions on Stored Procedure [ProTool].[ReportForecastTotalsByCategory]'
GRANT EXECUTE ON [ProTool].[ReportForecastTotalsByCategory] TO [db_FieldCostTracker]
GO
IF (EXISTS(SELECT * FROM sys.database_principals WHERE name = N'developers' AND type = 'R'))
GRANT EXECUTE ON [ProTool].[ReportForecastTotalsByCategory] TO [developers]
GO

/*********************
** Report Project Change Request - Header
**********************/
if exists(select * from dbo.sysobjects where id = OBJECT_ID(N'[ProTool].[ReportProjectChangeRequest_Main]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [ProTool].[ReportProjectChangeRequest_Main]
Print 'Creating Stored Procedure [ProTool].[ReportProjectChangeRequest_Main]'
GO
/* =================================================
-- SUMMARY: Gets the ScopeChanges header data for the Project Change Request report.
-- 
-- DATE			DEVELOPER			  CHANGE HISTORY
----------------------------------------------------
-- 04/24/2013   Mike Card, Centric    Created
--
-- UNIT TESTS
-- EXEC [ProTool].[ReportProjectChangeRequest_Main] 'TCO', 16764, 3, 1
-- ================================================= */
CREATE PROCEDURE [ProTool].[ReportProjectChangeRequest_Main]
	@companyCode varchar(3),
	@projectNo int,
	@versionNo smallint,
	@scopeVersionNo smallint
AS
 BEGIN
	SET NOCOUNT ON
	DECLARE @companyName varchar(50)
	
	-- get name
	SELECT @companyName = Company_Name
	FROM ProTool.Company
	WHERE Company_Cd = @companyCode

	CREATE TABLE #tblAgreement(
		[Company_Cd] varchar(3) NOT NULL,
		[Project_No] int NOT NULL,
		[Version_No] smallint NOT NULL,
		[Scope_Version_No] smallint NOT NULL,
		[Project_Role_CD] smallint NOT NULL,
		[User_ID] varchar(10) NOT NULL,
		[Agreement_Date] datetime NOT NULL)

	-- get latest ScopeAgreements row. 
	-- Note: Table could of used an Identity column to make this easier :-)
	INSERT INTO #tblAgreement ([Company_Cd]
		,[Project_No]
		,[Version_No]
		,[Scope_Version_No]
		,[Project_Role_CD]
		,[User_ID]
		,[Agreement_Date])
	SELECT [Company_Cd]
      ,[Project_No]
      ,[Version_No]
      ,[Scope_Version_No]
      ,[Project_Role_CD]
      ,[User_ID]
      ,[Agreement_Date]
	FROM [ProTool].[ScopeAgreements] (NOLOCK) 
	WHERE (Company_Cd = @companyCode
		AND Project_No = @projectNo
		AND Version_No = @versionNo
		AND Scope_Version_No = @scopeVersionNo
		AND Agreement_Fl = 1
		AND [Agreement_Date] IS NOT NULL 
		AND [Agreement_Date] = 
			(SELECT MAX([Agreement_Date])
  			 FROM [ProTool].[ScopeAgreements] (NOLOCK) 
			 WHERE (Company_Cd = @companyCode
				AND Project_No = @projectNo
				AND Version_No = @versionNo
				AND Scope_Version_No = @scopeVersionNo
				AND Agreement_Fl = 1
				AND [Agreement_Date] IS NOT NULL)))

	-- return results
	SELECT sc.[Company_Cd]
	  ,@companyName as Company_Name
      ,sc.[Project_No]
      ,p.Title as Project_Name
      ,sc.[Version_No]
      ,sc.[Scope_Version_No]
      ,sc.[Change_Type]
      ,sc.[Change_Desc]
      ,sc.[Change_Status]
      ,sc.[Change_Type_Design]--chk
      ,sc.[Change_Type_Phy_Scope]--chk
      ,sc.[Change_Type_Wk_Scope]--chk
      ,sc.[Change_Type_Cost]--chk
      ,sc.[Change_Type_Schedule]--chk
      ,scd.[Description] as [Primary_Driver]
      ,scd2.[Description] as [Secondary_Driver]
      ,sc.[Material_Impact]--chk
      ,sc.[Contractor_Impact]--chk
      ,sc.[Other_Impact]--chk
      ,sc.[Change_Timing]--radio
      ,sc.[Change_Timing_Reason]
      ,sc.[PEIF_Updated]--chk
      ,sc.[PO_Number]
      ,sc.[PO_Change]
      ,sc.[Year_Impacted]
      ,sc.[Initiated_By_ID]
      ,sc.[Management_Decision]-- join to User_Directory TCOID for Approver?
      ,sc.[Project_Impact]
      ,sc.[Change_Justification]
      ,sc.[Gate_CD]
      ,sc.[Scope_Notes]
      ,sc.[Project_Manager_Comments]
      ,sc.[Project_Manager_Edited]
      ,sc.[Management_Approval_Comments]
      ,sc.[Management_Edited]
      ,sc.[Scope_Approval_Fl]-- where for approver?
      ,sc.[Scope_Approval_Date]
      ,sc.[CostEstimate_Version_No] -- estimate version
      ,v.Name as Vendor_Name
      ,po.Original_Cost as Original_PO_Total  --ToDo: change for new column: po.Original_Cost
      ,po.Total_Cost as Current_PO_Total
      ,(SELECT SUM([Amount])
		 FROM [ProTool].[ScopeChangeEstimate] (NOLOCK) 
		 WHERE (Company_Cd = sc.Company_Cd 
			AND Project_No = sc.Project_No
			AND Scope_Version_No = sc.Scope_Version_No 
			AND Version_No = sc.Version_No)) as Change_Estimate_Total
      ,r.Project_Role_Name as Agreement_Role_Name
      ,u.Name as Initiated_User_Name
      ,COALESCE(u.MobileNumber, u.OfficePhoneNumber, u.HomePhoneNumber) as Initiated_User_Phone
      ,ua.Name as Agreement_User_Name
      ,a.[Agreement_Date]
  	FROM [ProTool].[ScopeChanges] sc (NOLOCK)
  	LEFT JOIN [ProTool].[Projects] p (NOLOCK)
  		ON p.Project_No = sc.Project_No
  	LEFT JOIN [ProTool].[PurchaseOrders] po (NOLOCK) 
		ON po.PO_Num = sc.[PO_Number]
  	LEFT JOIN [ProTool].[Vendors] v (NOLOCK) 
		ON v.Vendor_Id = po.Vendor_Id
	LEFT JOIN [ProTool].[ScopeChangeDrivers] scd (NOLOCK)
		ON scd.Driver_Cd = sc.[Primary_Driver_CD]
	LEFT JOIN [ProTool].[ScopeChangeDrivers] scd2 (NOLOCK)
		ON scd2.Driver_Cd = sc.[Secondary_Driver_CD]
  	LEFT JOIN [ProTool].[User_Directory] u (NOLOCK) 
		ON u.TCOID = sc.[Initiated_By_ID]
	LEFT JOIN #tblAgreement a
		ON (a.Company_Cd = sc.Company_Cd 
			AND a.Project_No = sc.Project_No
			AND a.Scope_Version_No = sc.Scope_Version_No 
			AND a.Version_No = sc.Version_No)
  	LEFT JOIN [ProTool].[User_Directory] ua (NOLOCK) 
		ON ua.TCOID = a.[User_ID]
  	LEFT JOIN [ProTool].[ProjectRoles] r (NOLOCK)
		ON r.Project_Role_Cd = a.Project_Role_CD
  	WHERE sc.Company_Cd = @companyCode
  		AND sc.Project_No = @projectNo
  		AND sc.Version_No = @versionNo
  		AND sc.Scope_Version_No = @scopeVersionNo

	-- clean up temp tables.
	DROP TABLE #tblAgreement

 END
GO
Print 'Granting Execute permissions on Stored Procedure [ProTool].[ReportProjectChangeRequest_Main]'
GRANT EXECUTE ON [ProTool].[ReportProjectChangeRequest_Main] TO [db_FieldCostTracker]
GO
IF (EXISTS(SELECT * FROM sys.database_principals WHERE name = N'developers' AND type = 'R'))
GRANT EXECUTE ON [ProTool].[ReportProjectChangeRequest_Main] TO [developers]
GO

/*********************
** Report: Project Change Request - Cost Impact
**********************/
if exists(select * from dbo.sysobjects where id = OBJECT_ID(N'[ProTool].[ReportProjectChangeRequest_CostImpact]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [ProTool].[ReportProjectChangeRequest_CostImpact]
Print 'Creating Stored Procedure [ProTool].[ReportProjectChangeRequest_CostImpact]'
GO
/* =================================================
-- SUMMARY: Gets the Cost Impact subreport data for the Project Change Request report.
-- 
-- DATE			DEVELOPER			  CHANGE HISTORY
----------------------------------------------------
-- 04/24/2013   Mike Card, Centric    Created
--
-- UNIT TESTS
-- EXEC [ProTool].[ReportProjectChangeRequest_CostImpact] 'TCO', 16764, 3, 1
-- ================================================= */
CREATE PROCEDURE [ProTool].[ReportProjectChangeRequest_CostImpact]
	@companyCode varchar(3),
	@projectNo int,
	@versionNo smallint,
	@scopeVersionNo smallint
AS
 BEGIN
	SET NOCOUNT ON
	DECLARE @categoryType varchar(50)
	
	-- estimates are Summary or Detail?
	SELECT @categoryType = CASE WHEN Cost_Category_Type = 1 THEN 'Summary' ELSE 'Detail' END
	FROM [ProTool].[Estimates] (NOLOCK)
	WHERE Company_Cd = @companyCode 
		AND Project_No = @projectNo 
		AND Version_No = @versionNo

	-- return results
	SELECT * FROM 
	(SELECT sce.Cost_Category_Cd
		,cc.Cost_Category_Desc
		,sce.Amount
	FROM [ProTool].[ScopeChangeEstimate] sce (NOLOCK)
	JOIN [ProTool].[CostCategories] cc (NOLOCK)
		ON cc.Cost_Category_Cd = sce.Cost_Category_Cd
  	WHERE sce.Company_Cd = @companyCode
  		AND sce.Project_No = @projectNo
  		AND sce.Version_No = @versionNo
  		AND sce.Scope_Version_No = @scopeVersionNo
		AND cc.Capital_Active_Fl = 1
		AND cc.Cost_Category_Type = @categoryType
	UNION
	SELECT 31991 as [Cost_Category_Cd]
		,'Total Changes:' as [Cost_Category_Desc]
		,SUM(sce.[Amount]) as [Amount]
	FROM [ProTool].[ScopeChangeEstimate] sce (NOLOCK)
	JOIN [ProTool].[CostCategories] cc (NOLOCK)
		ON cc.Cost_Category_Cd = sce.Cost_Category_Cd
  	WHERE sce.Company_Cd = @companyCode
  		AND sce.Project_No = @projectNo
  		AND sce.Version_No = @versionNo
  		AND sce.Scope_Version_No = @scopeVersionNo
		AND cc.Capital_Active_Fl = 1
		AND cc.Cost_Category_Type = @categoryType
	) AS impact ORDER BY Cost_Category_Cd
 END
GO
Print 'Granting Execute permissions on Stored Procedure [ProTool].[ReportProjectChangeRequest_Main]'
GRANT EXECUTE ON [ProTool].[ReportProjectChangeRequest_CostImpact] TO [db_FieldCostTracker]
GO
IF (EXISTS(SELECT * FROM sys.database_principals WHERE name = N'developers' AND type = 'R'))
GRANT EXECUTE ON [ProTool].[ReportProjectChangeRequest_CostImpact] TO [developers]
GO


/*----------------------------------------------------------------------------------------------------
						VIEWS
------------------------------------------------------------------------------------------------------*/
/****** Object:  View [ProTool].[ProgramAnnualEstimates]    Script Date: 04/10/2013 16:51:11 ******/
Print 'Dropping View [ProTool].[ProgramAnnualEstimates]'
IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[ProTool].[ProgramAnnualEstimates]'))
DROP VIEW [ProTool].[ProgramAnnualEstimates]
GO
/****** Object:  View [ProTool].[AnnualEstimates]    Script Date: 04/10/2013 16:51:11 ******/
Print 'Dropping View [ProTool].[AnnualEstimates]'
IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[ProTool].[AnnualEstimates]'))
DROP VIEW [ProTool].[AnnualEstimates]
GO
/****** Object:  View [ProTool].[AnnualEstimates]    Script Date: 04/10/2013 16:51:11 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
Print 'Creating View [ProTool].[AnnualEstimates]'
GO
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[ProTool].[AnnualEstimates]'))
EXEC dbo.sp_executesql @statement = N'CREATE VIEW [ProTool].[AnnualEstimates]
AS
SELECT     d.Company_Cd, d.Project_No, d.Estimate_Year, d.Version_No, d.Gross, d.Billings, d.Year_Approval_Fl, d.Budget_Version_Cd, d.Preliminary_Program_FL, 
                      d.Original_Program_FL, d.January, d.February, d.March, d.April, d.May, d.June, d.July, d.August, d.September, d.October, d.November, d.December, 
                      c.Locked_Estimate_Fl, c.Brief_Note, d.Gross - d.Billings AS Net
FROM         ProTool.Estimates AS c INNER JOIN
                          (SELECT     a.Company_Cd, a.Project_No, a.Estimate_Year, a.Version_No, SUM(b.Amount) AS Gross, ProTool.Calc_Annual_Billing_Amount(a.Company_Cd, 
                                                   a.Project_No, a.Version_No, a.Estimate_Year, SUM(b.Amount)) AS Billings, a.Year_Approval_Fl, a.Budget_Version_Cd, a.Preliminary_Program_FL, 
                                                   a.Original_Program_FL, a.January, a.February, a.March, a.April, a.May, a.June, a.July, a.August, a.September, a.October, a.November, a.December
                            FROM          ProTool.EstimateYears AS a INNER JOIN
                                                   ProTool.EstimateYearByCategories AS b ON a.Company_Cd = b.Company_Cd AND a.Project_No = b.Project_No AND a.Version_No = b.Version_No AND 
                                                   a.Estimate_Year = b.Estimate_Year
                            GROUP BY a.Company_Cd, a.Project_No, a.Estimate_Year, a.Version_No, a.Year_Approval_Fl, a.Budget_Version_Cd, a.Original_Program_FL, 
                                                   a.Preliminary_Program_FL, a.January, a.February, a.March, a.April, a.May, a.June, a.July, a.August, a.September, a.October, a.November, a.December) 
                      AS d ON c.Company_Cd = d.Company_Cd AND c.Project_No = d.Project_No AND c.Version_No = d.Version_No
'
GO
IF NOT EXISTS (SELECT * FROM ::fn_listextendedproperty(N'MS_DiagramPane1' , N'SCHEMA',N'ProTool', N'VIEW',N'AnnualEstimates', NULL,NULL))
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[18] 4[43] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[25] 4[46] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 8
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "c"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 125
               Right = 230
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "d"
            Begin Extent = 
               Top = 6
               Left = 268
               Bottom = 177
               Right = 472
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      PaneHidden = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'ProTool', @level1type=N'VIEW',@level1name=N'AnnualEstimates'
GO
IF NOT EXISTS (SELECT * FROM ::fn_listextendedproperty(N'MS_DiagramPaneCount' , N'SCHEMA',N'ProTool', N'VIEW',N'AnnualEstimates', NULL,NULL))
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'ProTool', @level1type=N'VIEW',@level1name=N'AnnualEstimates'
GO

/****** Object:  View [ProTool].[ProgramAnnualEstimates]    Script Date: 04/10/2013 16:51:11 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
Print 'Creating View [ProTool].[ProgramAnnualEstimates]'
GO
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[ProTool].[ProgramAnnualEstimates]'))
EXEC dbo.sp_executesql @statement = N'CREATE VIEW [ProTool].[ProgramAnnualEstimates]
AS
SELECT     a.Company_Cd, a.Project_No, a.Estimate_Year, a.Version_No, a.Gross - IsNull
                          ((SELECT     SUM(x.Gross)
                              FROM         ProTool.AnnualEstimates x INNER JOIN
                                                    ProTool.Projects y ON x.Company_Cd = y.Company_Cd AND x.Project_No = y.Project_No
                              WHERE     y.Funding_Basket_Level_Cd = ''3'' AND y.Funding_Basket_Type_Cd = b.Funding_Basket_Type_Cd AND x.Estimate_Year = a.Estimate_Year AND 
                                                    x.Version_No IN
                                                        (SELECT     max(Version_No)
                                                          FROM          ProTool.Estimates est
                                                          WHERE      est.Project_No = x.Project_No AND est.Company_Cd = x.Company_cd)), 0) AS Gross, a.Net - IsNull
                          ((SELECT     SUM(x.Net)
                              FROM         ProTool.AnnualEstimates x INNER JOIN
                                                    ProTool.Projects y ON x.Company_Cd = y.Company_Cd AND x.Project_No = y.Project_No
                              WHERE     y.Funding_Basket_Level_Cd = ''3'' AND y.Funding_Basket_Type_Cd = b.Funding_Basket_Type_Cd AND x.Estimate_Year = a.Estimate_Year AND 
                                                    x.Version_No IN
                                                        (SELECT     max(Version_No)
                                                          FROM          ProTool.Estimates est
                                                          WHERE      est.Project_No = x.Project_No AND est.Company_Cd = x.Company_cd)), 0) AS Net, 
                      (CASE a.Year_Approval_Fl WHEN ''1'' THEN IsNull(a.Gross - IsNull(e.Approved_To_Spend_Gross_Sub, 0), 0) ELSE 0 END) AS Approved_To_Spend_Gross, 
                      (CASE a.Year_Approval_Fl WHEN ''1'' THEN IsNull(a.Net - IsNull(e.Approved_To_Spend_Net_Sub, 0), 0) ELSE 0 END) AS Approved_To_Spend_Net, 
                      (CASE a.Original_Program_Fl WHEN ''1'' THEN IsNull(a.Gross - IsNull(e.Original_Program_Gross_Sub, 0), 0) ELSE 0 END) AS Original_Program_Gross, 
                      (CASE a.Original_Program_Fl WHEN ''1'' THEN IsNull(a.Net - IsNull(e.Original_Program_Net_Sub, 0), 0) ELSE 0 END) AS Original_Program_Net, 
                      (CASE a.Preliminary_Program_Fl WHEN ''1'' THEN IsNull(a.Gross - IsNull(e.Preliminary_Program_Gross_Sub, 0), 0) ELSE 0 END) AS Preliminary_Program_Gross, 
                      (CASE a.Preliminary_Program_Fl WHEN ''1'' THEN IsNull(a.Net - IsNull(e.Preliminary_Program_Net_Sub, 0), 0) ELSE 0 END) AS Preliminary_Program_Net, 
                      IsNull(a.Billings, 0) AS Billings, a.Year_Approval_Fl, a.Budget_Version_Cd, a.Preliminary_Program_Fl, a.Original_Program_Fl, a.January, a.February, a.March, a.April, 
                      a.May, a.June, a.July, a.August, a.September, a.October, a.November, a.December, a.Locked_Estimate_Fl, a.Brief_Note
FROM         ProTool.AnnualEstimates a INNER JOIN
                      ProTool.Projects b ON a.Company_Cd = b.Company_Cd AND a.Project_No = b.Project_No LEFT JOIN
                          (SELECT     d .Funding_Basket_Type_Cd, c.Estimate_Year, IsNull(SUM(c.Gross), 0) AS Gross, IsNull(Sum(c.Net), 0) AS Net, IsNull(Sum(c.Billings), 0) AS Billings, 
                                                   SUM(CASE c.Year_Approval_Fl WHEN ''1'' THEN IsNull(c.Gross, 0) ELSE 0 END) AS Approved_To_Spend_Gross_Sub, 
                                                   SUM(CASE c.Year_Approval_Fl WHEN ''1'' THEN IsNull(c.Net, 0) ELSE 0 END) AS Approved_To_Spend_Net_Sub, 
                                                   SUM(CASE c.Original_Program_Fl WHEN ''1'' THEN IsNull(c.Gross, 0) ELSE 0 END) AS Original_Program_Gross_Sub, 
                                                   SUM(CASE c.Original_Program_Fl WHEN ''1'' THEN IsNull(c.Net, 0) ELSE 0 END) AS Original_Program_Net_Sub, 
                                                   SUM(CASE c.Preliminary_Program_Fl WHEN ''1'' THEN IsNull(c.Gross, 0) ELSE 0 END) AS Preliminary_Program_Gross_Sub, 
                                                   SUM(CASE c.Preliminary_Program_Fl WHEN ''1'' THEN IsNull(c.Net, 0) ELSE 0 END) AS Preliminary_Program_Net_Sub
                            FROM          ProTool.AnnualEstimates c INNER JOIN
                                                   ProTool.Projects d ON c.Company_Cd = d .Company_Cd AND c.Project_No = d .Project_No AND d .Funding_Basket_Level_Cd = ''3''
                            GROUP BY d .Funding_Basket_Type_Cd, c.Estimate_Year) AS e ON b.Funding_Basket_Type_Cd = e.Funding_Basket_Type_Cd AND 
                      a.Estimate_Year = e.Estimate_Year
WHERE     b.Funding_Basket_Level_Cd = ''2''
UNION ALL
SELECT     g.Company_Cd, g.Project_No, g.Estimate_Year, g.Version_No, g.Gross, g.Net, (CASE g.Year_Approval_Fl WHEN ''1'' THEN g.Gross ELSE 0 END) 
                      AS Approved_To_Spend_Gross, (CASE g.Year_Approval_Fl WHEN ''1'' THEN g.Net ELSE 0 END) AS Approved_To_Spend_Net, 
                      (CASE g.Original_Program_Fl WHEN ''1'' THEN g.Gross ELSE 0 END) AS Original_Program_Gross, (CASE g.Original_Program_Fl WHEN ''1'' THEN g.Net ELSE 0 END) 
                      AS Original_Program_Net, (CASE g.Preliminary_Program_Fl WHEN ''1'' THEN g.Gross ELSE 0 END) AS Preliminary_Program_Gross, 
                      (CASE g.Preliminary_Program_Fl WHEN ''1'' THEN g.Net ELSE 0 END) AS Preliminary_Program_Net, g.Billings, g.Year_Approval_Fl, g.Budget_Version_Cd, 
                      g.Preliminary_Program_Fl, g.Original_Program_Fl, g.January, g.February, g.March, g.April, g.May, g.June, g.July, g.August, g.September, g.October, g.November, 
                      g.December, g.Locked_Estimate_Fl, g.Brief_Note
FROM         ProTool.AnnualEstimates g INNER JOIN
                      ProTool.Projects h ON g.Company_Cd = h.Company_Cd AND g.Project_No = h.Project_No
WHERE     h.Funding_Source_Cd = ''1'' OR
                      (h.Funding_Source_Cd = ''2'' AND h.Funding_Basket_Level_Cd = ''3'')
'
GO
IF NOT EXISTS (SELECT * FROM ::fn_listextendedproperty(N'MS_DiagramPane1' , N'SCHEMA',N'ProTool', N'VIEW',N'ProgramAnnualEstimates', NULL,NULL))
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[24] 4[25] 2[33] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[6] 4[23] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4[60] 2) )"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2) )"
      End
      ActivePaneConfig = 14
   End
   Begin DiagramPane = 
      PaneHidden = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      PaneHidden = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      PaneHidden = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'ProTool', @level1type=N'VIEW',@level1name=N'ProgramAnnualEstimates'
GO
IF NOT EXISTS (SELECT * FROM ::fn_listextendedproperty(N'MS_DiagramPaneCount' , N'SCHEMA',N'ProTool', N'VIEW',N'ProgramAnnualEstimates', NULL,NULL))
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'ProTool', @level1type=N'VIEW',@level1name=N'ProgramAnnualEstimates'
GO

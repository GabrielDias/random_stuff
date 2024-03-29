USE BANCO
GO

-- =============================================================================================================
-- Create a list of words present in all documents
-- =============================================================================================================

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'BANCO.[SCHEMA].[List of Words]') AND type in (N'U'))
DROP TABLE BANCO.[SCHEMA].[List of Words]

SELECT
	[CAMPO_CHAVE],
	split.splitdata
INTO BANCO.[SCHEMA].[List of Words]
FROM [BANCO].[SCHEMA].[TABELA]
cross apply [BANCO].[dbo].[fnSplitString] ([texto], '') split


CREATE CLUSTERED COLUMNSTORE INDEX idx_cs ON BANCO.[SCHEMA].[List of Words]

-- Time to run: 00:03:22


-- =============================================================================================================
-- Term frequency calculation
-- =============================================================================================================

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'BANCO.[SCHEMA].[Term Frequency]') AND type in (N'U'))
DROP TABLE BANCO.[SCHEMA].[Term Frequency]

SELECT [CAMPO_CHAVE], [Words], count(*) as [Word Frequency], cast(0 as INT) AS [Total Words in Document], cast(0 as decimal(18,4)) AS [TF]
INTO BANCO.[SCHEMA].[Term Frequency]
FROM BANCO.[SCHEMA].[List of Words]
WHERE len([Words]) > 1
GROUP BY [CAMPO_CHAVE], [Words]
-- (39508 row(s) affected)


-- Calculate TF
SELECT [Words], count(*) AS [Total Words in Document]
INTO #sumTF
FROM BANCO.[SCHEMA].[List of Words]
GROUP BY [Words]

update A
SET A.[Total Words in Document] = B.[Total Words in Document]
FROM BANCO.[SCHEMA].[Term Frequency] A
inner join #sumTF B
ON A.[Words] = B.[Words]

DROP TABLE #sumTF

update BANCO.[SCHEMA].[Term Frequency]
SET [TF] = cast(cast([Word Frequency] AS DECIMAL(18,4)) / cast([Total Words in Document] AS DECIMAL(18,4)) AS DECIMAL(18,4))


-- =============================================================================================================
-- Number of documents containing the word
-- =============================================================================================================

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'BANCO.[SCHEMA].[Docs vs. Words]') AND type in (N'U'))
DROP TABLE BANCO.[SCHEMA].[Docs vs. Words]

SELECT [words], count(DISTINCT [CAMPO_CHAVE]) AS [Number of Documents containing Word]
INTO #numberDoc
FROM BANCO.[SCHEMA].[Term Frequency]
GROUP BY [Words]

SELECT A.*, B.[Number of Documents containing Word], cast(0 as decimal(18,4)) AS [IDF]
INTO BANCO.[SCHEMA].[Docs vs. Words]
FROM BANCO.[SCHEMA].[Term Frequency] A
inner join #numberDoc B
ON A.[Words] = B.[Words]

DROP TABLE #numberDoc


-- =============================================================================================================
-- Total number of documents
-- =============================================================================================================

DECLARE @totalDocs INT
SET @totalDocs = (SELECT count(DISTINCT [CAMPO_CHAVE]) FROM BANCO.[SCHEMA].[Term Frequency])

-- =============================================================================================================
-- IDF Calculation
-- =============================================================================================================

update BANCO.[SCHEMA].[Docs vs. Words]
SET [IDF] = log(cast(@totalDocs AS DECIMAL(18,4)) / cast([Number of Documents containing Word] AS DECIMAL(18,4)))


-- =============================================================================================================
-- TFIDF Calculation
-- =============================================================================================================
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'BANCO.[SCHEMA].[TFIDF]') AND type in (N'U'))
DROP TABLE BANCO.[SCHEMA].[TFIDF]

SELECT *, cast([TF] * [IDF] AS DECIMAL(18,4)) AS [TFIDF]
INTO BANCO.[SCHEMA].[TFIDF] 
FROM BANCO.[SCHEMA].[Docs vs. Words]
	


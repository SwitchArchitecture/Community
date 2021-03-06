GO
/*	Create a stub of the procedure if it does not already exist. Why do we do this?
	This allows us to ALTER the procedure instead of DROP and CREATE the procedure.
	DROP and CREATE is dangerous as it will lose any permissions assigned to the object. */
IF OBJECT_ID('[dbo].[usp_Utility_DropTempTables]') IS NULL
BEGIN
	EXEC sp_executesql N'CREATE PROCEDURE [dbo].[usp_Utility_DropTempTables] AS RETURN 0;';
END
GO
ALTER PROCEDURE [dbo].[usp_Utility_DropTempTables]
	 @VerboseOutput					BIT		= 0	-- Print the name of the temporary tables to the output buffer
	,@PrintSQL						BIT		= 0	-- Print the DROP TABLE commands ot the output buffer
	,@ExecuteSQL					BIT		= 1	-- Execute the DROP TABLE commands
AS
BEGIN

	/**************************************************************************
		Author:		Switch Architecture, LLC. http://www.switcharch.com

		Source:		https://github.com/SwitchArchitecture/Community/

		Overview:	http://www.switcharch.com/say_goodbye_to_dropping_sql_temporary_tables/

		Version		Date				Change
		-------		------------------	---------------------------------------
		1.0.0		September 12, 2018	Initial Revision


		Usage Examples:
		---------------

		EXEC [dbo].[usp_Utility_DropTempTables];

		EXEC [dbo].[usp_Utility_DropTempTables]		 @VerboseOutput		= 1;

		EXEC [dbo].[usp_Utility_DropTempTables]		 @PrintSQL			= 1
													,@ExecuteSQL		= 0;

		The fine print:
		---------------

		MIT License

		Copyright (c) 2018 Switch Architecture, LLC.

		Permission is hereby granted, free of charge, to any person obtaining a copy
		of this software and associated documentation files (the "Software"), to deal
		in the Software without restriction, including without limitation the rights
		to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
		copies of the Software, and to permit persons to whom the Software is
		furnished to do so, subject to the following conditions:

		The above copyright notice and this permission notice shall be included in all
		copies or substantial portions of the Software.

		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
		IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
		FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
		AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
		LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
		OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
		SOFTWARE.

	***************************************************************************/

	SET NOCOUNT ON;
	
	/* Declare and initialize local variables */
	DECLARE	@SQL						NVARCHAR(MAX);
	DECLARE	@SQLTemplate				NVARCHAR(MAX);
	DECLARE	@CurrentSchemaName			SYSNAME;
	DECLARE	@CurrentTableName			SYSNAME;
	DECLARE	@CurrentFriendlyTableName	SYSNAME;
	
	DECLARE	@TableList					TABLE (
		 [SchemaName]					SYSNAME		NOT NULL
		,[TableName]					SYSNAME		NOT NULL
		,[FriendlyTableName]			SYSNAME		NOT NULL
		,[IsProcessed]					BIT			NOT NULL DEFAULT (0)	
	
		,UNIQUE NONCLUSTERED
			( [SchemaName], [TableName] )
	
		,UNIQUE NONCLUSTERED
			( [SchemaName], [FriendlyTableName] )
	);
	
	/* Build the tokenized template command that will be used for the dynamic SQL statements */
	SET @SQLTemplate = N'DROP TABLE [{SchemaName}].[{TableName}];';
	
	/* Gather the list of temporary tables for the current session */
	INSERT INTO @TableList
		(	 [SchemaName]
			,[TableName]
			,[FriendlyTableName]	)
	SELECT	 [s].[name]						AS [SchemaName]
			,[o].[name]						AS [TableName]
			,[o].[name]						AS [FriendlyTableName]
	FROM	[tempdb].[sys].[objects]		AS [o] WITH(NOLOCK) /* The current session is running this procedure, so we know we're not creating temporary tables */
	INNER JOIN [tempdb].[sys].[schemas]		AS [s]
		ON	[o].[schema_id] = [s].[schema_id]
	WHERE	[o].[type] = 'U'
		AND	[o].[name] LIKE '#%'
		/* This predicate restricts the query to only returning the current session's temporary tables */
		AND	OBJECT_ID('[tempdb].[dbo].[' + [o].[name] + ']') IS NOT NULL
		/* This predicate restricts the query from returning global temporary tables */
		AND	[o].[name] NOT LIKE '##%';
	
	/*	
		To build the friendly table name, first trim the 12 character unique code that is added to the end of the table name.
		This code makes the table's name unique across all sessions. It's also why temporary table names are limited to 116
		characters (vs. 128 characters)

		Before: #DATA_SET_1_________________________________________________________________________________________________________000000327594
		After:	#DATA_SET_1_________________________________________________________________________________________________________
	*/
	UPDATE	[tl]
		SET	[FriendlyTableName]	= LEFT([tl].[FriendlyTableName], 116)
	FROM	@TableList AS [tl];

	/*	Next, continue building the friendly table name by trimming the trailing underscores added by SQL Server
		This works by reversing the string, locating the position of the first character that is not an underscore,
		and using that position as the end of the string.

		Before: #DATA_SET_1_________________________________________________________________________________________________________
		After:	#DATA_SET_1
	 */
	UPDATE	[tl]
		SET	[FriendlyTableName]	=	SUBSTRING(
										 [tl].[FriendlyTableName]
										,1
										,LEN([tl].[FriendlyTableName])
										 - PATINDEX(
												'%[^_]%'
												,REVERSE([tl].[FriendlyTableName])
											) + 1
									)
	FROM	@TableList AS [tl]
	WHERE	[FriendlyTableName] LIKE '%[_]'; /* The table's name can take up all 116 characters and not requiring trimming */
	
	/*	Finally, handle the edge scenario where the table's name is 116 characters AND the table's name actually
		ends with an underscore. The query above would have removed the underscore thinking it was added by SQL Server.

		To do this, we simply revert to the actual table's name (minus the trailing 12 digits) if the friendly table name was not found. */
	UPDATE	[tl]
		SET	[FriendlyTableName] = LEFT([tl].[TableName], 116)
	FROM	@TableList AS [tl]
	WHERE	OBJECT_ID('[tempdb].[' + [tl].[SchemaName] + '].[' + [tl].[FriendlyTableName] + ']' ) IS NULL;
	
	/* Process the DELETE for each table */
	WHILE EXISTS (
		SELECT	1
		FROM	@TableList AS [tl]
		WHERE	[tl].[IsProcessed] = 0
	)
	BEGIN
		SELECT	TOP (1)
				 @CurrentSchemaName			= [tl].[SchemaName]
				,@CurrentTableName			= [tl].[TableName]
				,@CurrentFriendlyTableName	= [tl].[FriendlyTableName]
		FROM	@TableList AS [tl]
		WHERE	[tl].[IsProcessed] = 0;
	
		SET @SQL = REPLACE(
					 REPLACE(
						 @SQLTemplate
						,'{SchemaName}'
						,@CurrentSchemaName
					)
					,'{TableName}'
					, @CurrentFriendlyTableName
				);
	
		/* Print the dynamic SQL statement to the output buffer */
		IF @PrintSQL = 1
		BEGIN
			PRINT @SQL;
		END;
	
		/* Execute the dynamic SQL statement */
		IF @ExecuteSQL = 1
		BEGIN
			/* Print the table's name the output buffer */
			IF @VerboseOutput = 1
			BEGIN
				RAISERROR('Dropping temporary table [%s].[%s]', 10, 0, @CurrentSchemaName, @CurrentFriendlyTableName) WITH NOWAIT;
			END
	
			EXECUTE [master].[dbo].[sp_executesql] @SQL = @SQL;
		END
	
		UPDATE	[tl]
			SET	[IsProcessed] = 1
		FROM	@TableList AS [tl]
		WHERE	[tl].[SchemaName]	= @CurrentSchemaName
			AND	[tl].[TableName]	= @CurrentTableName;
	END

	RETURN 0;
END
GO
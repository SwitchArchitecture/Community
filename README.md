__Hello!__

This repository contains utilities, tools, and queries developed by [Switch Architecture](http://www.switcharch.com) and shared with the community to help other developers, architects, and administrators.

Tool: usp_Utility_DropAllTemporaryTables
------

__Description:__

This script will create a utility stored procedure that will drop all #temporary tables that exist for the current session. It's helpful when you're debugging code that creates multiple #temporary tables and you need to execute the code multiple times.

More details on it's purpose and usage may be found in this article.

__Repository Location:__

/Commmunity/DropAllTemporaryTables/

__Installation Steps:__

Run "Install [usp_Utility_DropAllTemporaryTables]"

__Usage Example:__

EXEC [dbo].[usp_Utility_DropTemporaryTablesForSession];

__Tips:__

Create the stored procedure in the [master] database and name it [sp_DropAllTemporaryTables] if you would like to run it from any database without context.

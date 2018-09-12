__Hello!__

This repository contains utilities, tools, and queries developed by [Switch Architecture](http://www.switcharch.com) and shared with the community to help other developers, architects, and administrators.

Tool: usp_Utility_DropTempTables
------

__Description:__

This script will create a utility stored procedure that will drop all #temporary tables that exist for the current session. It's helpful when you're debugging code that creates multiple #temporary tables and you need to execute the code multiple times.

More details on it's purpose and usage may be found in our article ["Say goodbye to dropping #temporary tables"](http://www.switcharch.com/say_goodbye_to_dropping_sql_temporary_tables/).

__Repository Location:__

[/Commmunity/DropTempTables/](https://github.com/SwitchArchitecture/Community/tree/master/SQL/DropTempTables)

__Installation Steps:__

Run "Install [usp_Utility_DropTempTables].sql" _Be sure to change to the appropriate database context first_

__Usage Example:__

```sql
EXEC [dbo].[usp_Utility_DropTempTables];
```

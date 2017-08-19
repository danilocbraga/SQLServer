SELECT top (1) FirstName
FROM [Person].[Person] AS P
INNER JOIN [Person].[PersonPhone] AS H
 ON P.BusinessEntityID = H.BusinessEntityID
OPTION (RECOMPILE, MAXDOP 4, QUERYTRACEON 8649)
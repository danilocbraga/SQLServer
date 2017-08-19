begin try
    begin transaction
        --do some stuff
        --and some other stuff
    commit transaction
end try
begin catch
    declare @ErrorMessage nvarchar(4000)
        , @ErrorSeverity int
 
    select @ErrorMessage = ERROR_MESSAGE()
        , @ErrorSeverity = ERROR_SEVERITY()
 
    raiserror(@ErrorMessage, @ErrorSeverity, 1)
end catch
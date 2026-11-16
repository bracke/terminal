package Terminal.App.Platform_Files is
   --  Atomically replace Target with Source when the host filesystem supports
   --  the native rename/replace operation.  Source is consumed on success.
   function Replace_File (Source, Target : String) return Boolean;
end Terminal.App.Platform_Files;

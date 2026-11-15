with Terminal.App.PTY_Write;

package Terminal.App.Session_Runtime.Testing is
   procedure Queue_Deferred_Parser_Recovery (R : in out Runtime);

   procedure Write_Paste_With_Construction_Failure
     (R         : in out Runtime;
      Text      : String;
      Bracketed : Boolean;
      Status    : out Terminal.App.PTY_Write.Write_All_Status);
end Terminal.App.Session_Runtime.Testing;

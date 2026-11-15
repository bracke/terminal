separate (Terminal.App.Session_Table)
procedure Start_Runtime
  (Table            : in out Runtime_Table;
   Slot             : out Runtime_Access;
   Rows             : Positive;
   Cols             : Positive;
   Scrollback_Limit : Natural;
   Graphics_Profile : Terminal.Core.Graphics_Capability_Profile;
   Status           : out Table_Status;
   Start_Status     : out Terminal.App.Session_Runtime.Start_Status)
is
   procedure Roll_Back is
   begin
      if Table.Pending_Start /= null then
         Release_Runtime (Table.Pending_Start);
      end if;
   exception
      when E : others =>
         Status := Start_Failed;
         Start_Status := Terminal.App.Session_Runtime.Cleanup_Failed;
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Session_Table,
            E,
            "rollback session runtime startup");
   end Roll_Back;
begin
   Slot := null;
   --  A previous failed attempt may have retained a runtime whose cleanup
   --  was incomplete.  Never overwrite that table-owned pointer on retry.
   if Table.Pending_Start /= null then
      Roll_Back;
      if Table.Pending_Start /= null then
         Status := Start_Failed;
         Start_Status := Terminal.App.Session_Runtime.Cleanup_Failed;
         return;
      end if;
   end if;
   Table.Pending_Start := new Terminal.App.Session_Runtime.Runtime;
   Terminal.App.Session_Runtime.Start
     (Table.Pending_Start.all,
      Rows,
      Cols,
      Scrollback_Limit,
      Start_Status,
      Graphics_Profile);
   if Start_Status = Terminal.App.Session_Runtime.Ok then
      Slot := Table.Pending_Start;
      Table.Pending_Start := null;
      Status := Ok;
   else
      Status := Start_Failed;
      Roll_Back;
   end if;
exception
   when Storage_Error =>
      Status := Start_Failed;
      Start_Status := Terminal.App.Session_Runtime.Allocation_Failed;
      Roll_Back;
   when others =>
      Roll_Back;
      raise;
end Start_Runtime;

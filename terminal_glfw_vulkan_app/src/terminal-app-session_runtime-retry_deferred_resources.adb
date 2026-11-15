with Ada.Exceptions;

separate (Terminal.App.Session_Runtime)
procedure Retry_Deferred_Resources
  (Item        : in out Deferred_Resource_Set_Access;
   Retry_After : out Ada.Real_Time.Time)
is
   procedure Note_First_Failure
     (Error     : Ada.Exceptions.Exception_Occurrence;
      Operation : String;
      Reported  : in out Boolean) is
   begin
      if not Reported then
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
            Error,
            Operation);
         Reported := True;
      end if;
   end Note_First_Failure;

   Had_Reader  : constant Boolean := Item.Reader /= null;
   Had_Session : constant Boolean := Item.S /= null;
   Had_Queue   : constant Boolean := Item.Q /= null;
   Had_Core    : constant Boolean := Item.T /= null;
   Progress    : Boolean;
begin
   Retry_After := Ada.Real_Time.Time_Last;
   if Item.Reader /= null and then Item.Reader.all'Terminated then
      begin
         Free_Reader (Item.Reader);
      exception
         when E : others =>
            Note_First_Failure
              (E,
               "retry deferred PTY reader release",
               Item.Failures.Reader);
      end;
   end if;
   if Item.Reader = null and then Item.S /= null then
      begin
         Terminal.PTY.Backend.Defer_Close (Item.S.all);
         Free_Session (Item.S);
      exception
         when E : others =>
            Note_First_Failure
              (E,
               "retry deferred PTY session release",
               Item.Failures.Session);
      end;
   end if;
   if Item.Reader = null and then Item.Q /= null then
      begin
         Free_Queue (Item.Q);
      exception
         when E : others =>
            Note_First_Failure
              (E,
               "retry deferred session queue release",
               Item.Failures.Queue);
      end;
   end if;
   if Item.T /= null then
      begin
         Free_Core (Item.T);
      exception
         when E : others =>
            Note_First_Failure
              (E,
               "retry deferred terminal core release",
               Item.Failures.Core);
      end;
   end if;

   Progress :=
     (Had_Reader and then Item.Reader = null)
     or else (Had_Session and then Item.S = null)
     or else (Had_Queue and then Item.Q = null)
     or else (Had_Core and then Item.T = null);

   if Empty (Item.all) then
      Free_Resource_Set (Item);
   else
      if Progress then
         Item.Retry.Delay_Milliseconds := 0;
         Item.Retry.Retry_After := Ada.Real_Time.Time_First;
      end if;
      Schedule_Deferred_Retry (Item.Retry);
      Retry_After := Item.Retry.Retry_After;
      Deferred_Owners.Retain_Resources (Item);
   end if;
end Retry_Deferred_Resources;

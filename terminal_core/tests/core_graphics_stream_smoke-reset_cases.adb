separate (Core_Graphics_Stream_Smoke)
procedure Reset_Cases is
   T    : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
begin
   Terminal.Core.Initialize (T, 2, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "reset cases initialize");
   Terminal.Core.Set_Graphics_Stream_ID (T, 42);
   declare
      Reset_T : Terminal.Core.Terminal;
      Reset_Init : Terminal.Core.Initialize_Status;
      Reset_Status : Terminal.Core.Feed_Status;
   begin
      Terminal.Core.Initialize (Reset_T, 2, 8, 10, Reset_Init);
      if Reset_Init /= Terminal.Core.Ok then
         raise Program_Error with "graphics reset initialize";
      end if;
      Terminal.Core.Feed
        (Reset_T,
         To_Bytes (ASCII.ESC & "_Gq=2,a=d,i=17" & ASCII.ESC & "\"),
         Reset_Status);
      if Reset_Status /= Terminal.Core.Ok
        or else Terminal.Core.Pending_Graphics_Event_Count (Reset_T) /= 1
      then
         raise Program_Error with "graphics command exists before terminal reset";
      end if;
      Terminal.Core.Feed
        (Reset_T, To_Bytes (ASCII.ESC & "c"), Reset_Status);
      declare
         Reset_Snapshot : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Reset_T);
      begin
         if Reset_Status /= Terminal.Core.Ok
           or else Terminal.Core.Pending_Graphics_Event_Count (Reset_T) /= 0
           or else Reset_Snapshot.Graphics.Pending
         then
            raise Program_Error with
              "terminal reset clears both queued and published graphics events";
         end if;
         Terminal.Core.Release (Reset_Snapshot);
      end;
      Terminal.Core.Finalize (Reset_T);
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("terminal reset", E);
   end;

   declare
   begin
      for I in 1 .. Terminal.Core.Max_Pending_Graphics_Events + 1 loop
         Feed_Text (T, ASCII.ESC & "_Gq=2,a=d,i=" & Integer'Image (I) & ASCII.ESC & "\");
      end loop;
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (T) =
           Terminal.Core.Max_Pending_Graphics_Events,
         "event FIFO is bounded");
      Assert
        (Terminal.Core.Diagnostics (T).Queue_Overflow = 0,
         "full FIFO defers input rather than dropping the newest event");
      Terminal.Core.Discard_Graphics_Event (T);
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (T) =
           Terminal.Core.Max_Pending_Graphics_Events,
         "deferred FIFO event resumes after a consumer makes space");
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("FIFO capacity", E);
   end;
end Reset_Cases;

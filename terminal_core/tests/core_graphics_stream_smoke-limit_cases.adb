separate (Core_Graphics_Stream_Smoke)
procedure Limit_Cases is
begin
   declare
      Limit_T : Terminal.Core.Terminal;
      Limit_Init : Terminal.Core.Initialize_Status;
      Limit_Status : Terminal.Core.Feed_Status;
      Limits : constant Terminal.Core.Graphics_Resource_Limits :=
        (Transaction_Length => 32,
         Pending_Events => 2,
         Pending_Bytes => 64,
         Deferred_Input_Bytes => 128,
         Pixel_Dimension => 16);
   begin
      Terminal.Core.Initialize (Limit_T, 2, 4, 10, Limit_Init);
      Assert (Limit_Init = Terminal.Core.Ok, "graphics limits initialize");
      Terminal.Core.Set_Graphics_Resource_Limits (Limit_T, Limits);
      Assert
        (Terminal.Core.Graphics_Resource_Limit (Limit_T) = Limits,
         "configurable core graphics limits");
      Terminal.Core.Feed
        (Limit_T,
         To_Bytes
           (ASCII.ESC & "_G" & Repeat_Char ('A', 40) & ASCII.ESC & "\"),
         Limit_Status);
      Assert
        (Limit_Status = Terminal.Core.Parser_Overflow
         and then Terminal.Core.Pending_Graphics_Event_Count (Limit_T) = 0,
         "configured transaction limit discards oversized graphics");
      for I in 1 .. 3 loop
         Terminal.Core.Feed
           (Limit_T,
            To_Bytes
              (ASCII.ESC & "_Gq=2,a=d,i=" & Integer'Image (I)
               & ASCII.ESC & "\"),
            Limit_Status);
      end loop;
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (Limit_T) = 2
         and then Terminal.Core.Diagnostics (Limit_T).Queue_Overflow = 0,
         "configured graphics event limit applies backpressure without loss");
      Terminal.Core.Discard_Graphics_Event (Limit_T);
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (Limit_T) = 2,
         "deferred graphics resumes when bounded queue space is available");
      Terminal.Core.Finalize (Limit_T);
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("resource limits", E);
   end;

   declare
      Reconcile_T : Terminal.Core.Terminal;
      Reconcile_Init : Terminal.Core.Initialize_Status;
      Reconcile_Status : Terminal.Core.Feed_Status;
   begin
      Terminal.Core.Initialize (Reconcile_T, 2, 8, 10, Reconcile_Init);
      Assert (Reconcile_Init = Terminal.Core.Ok, "limit reconcile initialize");
      for I in 1 .. 3 loop
         Terminal.Core.Feed
           (Reconcile_T,
            To_Bytes
              (ASCII.ESC & "_Gq=2,a=d,i=" & Integer'Image (I)
               & ASCII.ESC & "\"),
            Reconcile_Status);
      end loop;
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (Reconcile_T) = 3,
         "limit reconcile precondition queues events");
      Terminal.Core.Set_Graphics_Resource_Limits
        (Reconcile_T,
         (Transaction_Length => 16,
          Pending_Events => 1,
          Pending_Bytes => 16,
          Deferred_Input_Bytes => 16,
          Pixel_Dimension => 16));
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (Reconcile_T) = 1
         and then Terminal.Core.Diagnostics (Reconcile_T).Queue_Overflow = 1,
         "lowering limits immediately trims retained graphics events");
      Terminal.Core.Finalize (Reconcile_T);
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("limit reconciliation", E);
   end;

   declare
      Lower_T : Terminal.Core.Terminal;
      Lower_Init : Terminal.Core.Initialize_Status;
      Lower_Status : Terminal.Core.Feed_Status;
      Lower_Event : Terminal.Core.Graphics_Event;
      Lower_Limits : constant Terminal.Core.Graphics_Resource_Limits :=
        (Transaction_Length => 16,
         Pending_Events => 8,
         Pending_Bytes => 128,
         Deferred_Input_Bytes => 8,
         Pixel_Dimension => 16);
   begin
      Terminal.Core.Initialize (Lower_T, 2, 8, 10, Lower_Init);
      Assert (Lower_Init = Terminal.Core.Ok, "active limit reconcile initialize");
      Terminal.Core.Feed
        (Lower_T,
         To_Bytes (ASCII.ESC & "_G" & Repeat_Char ('A', 40)),
         Lower_Status);
      Terminal.Core.Set_Graphics_Resource_Limits (Lower_T, Lower_Limits);
      Terminal.Core.Feed
        (Lower_T, To_Bytes (ASCII.ESC & "\" & "Z"), Lower_Status);
      declare
         Recovered : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Lower_T);
      begin
         Assert
           (Terminal.Core.Pending_Graphics_Event_Count (Lower_T) = 0
            and then Terminal.Core.Cell_At (Recovered, 1, 1).Text.Code_Point =
              Character'Pos ('Z'),
            "lowering limits cancels an active transfer and recovers parsing");
         Terminal.Core.Release (Recovered);
      end;
      Terminal.Core.Finalize (Lower_T);

      Terminal.Core.Initialize (Lower_T, 2, 8, 10, Lower_Init);
      Terminal.Core.Feed
        (Lower_T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=t,m=1;" & Repeat_Char ('A', 40)
            & ASCII.ESC & "\"),
         Lower_Status);
      Terminal.Core.Set_Graphics_Resource_Limits (Lower_T, Lower_Limits);
      Terminal.Core.Feed
        (Lower_T,
         To_Bytes (ASCII.ESC & "_Gq=2,m=0;B" & ASCII.ESC & "\"),
         Lower_Status);
      Terminal.Core.Peek_Graphics_Event (Lower_T, Lower_Event);
      Assert
        (Lower_Event.Pending
         and then Terminal.Core.Graphics_Event_Payload (Lower_T, Lower_Event) =
           "Gq=2,m=0;B",
         "lowering limits discards an oversized active Kitty chunk");
      Terminal.Core.Finalize (Lower_T);

      Terminal.Core.Initialize (Lower_T, 2, 8, 10, Lower_Init);
      Terminal.Core.Feed
        (Lower_T,
         To_Bytes
           (ASCII.ESC & "]1337;MultipartFile=inline=1" & ASCII.BEL
            & ASCII.ESC & "]1337;FilePart=" & Repeat_Char ('A', 40)
            & ASCII.BEL),
         Lower_Status);
      Terminal.Core.Set_Graphics_Resource_Limits (Lower_T, Lower_Limits);
      Terminal.Core.Feed
        (Lower_T,
         To_Bytes (ASCII.ESC & "]1337;FileEnd" & ASCII.BEL),
         Lower_Status);
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (Lower_T) = 0,
         "lowering limits discards oversized iTerm2 multipart storage");
      Terminal.Core.Finalize (Lower_T);

      Terminal.Core.Initialize (Lower_T, 2, 8, 10, Lower_Init);
      Terminal.Core.Feed
        (Lower_T,
         To_Bytes
           (ASCII.ESC & "_Ga=p,i=1" & ASCII.ESC & "\"
            & Repeat_Char ('X', 40)),
         Lower_Status);
      Terminal.Core.Set_Graphics_Resource_Limits (Lower_T, Lower_Limits);
      Terminal.Core.Discard_Graphics_Event (Lower_T);
      declare
         No_Deferred_Text : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Lower_T);
      begin
         Assert
           (Terminal.Core.Cell_At (No_Deferred_Text, 1, 1).Text.Code_Point = 0,
            "lowering limits discards oversized deferred input storage");
         Terminal.Core.Release (No_Deferred_Text);
      end;
      Terminal.Core.Finalize (Lower_T);
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("lowered storage limits", E);
   end;

   declare
      Deferred_T : Terminal.Core.Terminal;
      Deferred_Init : Terminal.Core.Initialize_Status;
      Deferred_Status : Terminal.Core.Feed_Status;
   begin
      Terminal.Core.Initialize (Deferred_T, 2, 8, 10, Deferred_Init);
      Assert
        (Deferred_Init = Terminal.Core.Ok,
         "deferred parser status initialize");
      Terminal.Core.Feed
        (Deferred_T,
         To_Bytes
           (ASCII.ESC & "_Ga=p,i=1" & ASCII.ESC & "\"
            & ASCII.ESC & "%x"),
         Deferred_Status);
      Assert
        (Deferred_Status = Terminal.Core.Ok,
         "blocked input is accepted before deferred parsing");
      Terminal.Core.Discard_Graphics_Event (Deferred_T);
      Assert
        (Terminal.Core.Take_Deferred_Feed_Status (Deferred_T) =
           Terminal.Core.Parser_Recovered,
         "deferred parser recovery status is retained");
      Assert
        (Terminal.Core.Take_Deferred_Feed_Status (Deferred_T) = Terminal.Core.Ok,
         "deferred parser status is consumed once");

      Terminal.Core.Feed
        (Deferred_T,
         To_Bytes
           (ASCII.ESC & "_Ga=p,i=2" & ASCII.ESC & "\"
            & ASCII.ESC & "%x"),
         Deferred_Status);
      Terminal.Core.Discard_Graphics_Event (Deferred_T);
      Terminal.Core.Initialize (Deferred_T, 2, 8, 10, Deferred_Init);
      Assert
        (Deferred_Init = Terminal.Core.Ok
         and then Terminal.Core.Take_Deferred_Feed_Status (Deferred_T) =
           Terminal.Core.Ok,
         "reinitialization clears deferred parser status");
      Terminal.Core.Finalize (Deferred_T);
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("deferred parser status", E);
   end;

end Limit_Cases;

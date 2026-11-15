separate (Core_Graphics_Stream_Smoke)
procedure Screen_Cases is
begin
   declare
      Screen_T : Terminal.Core.Terminal;
      Screen_Init : Terminal.Core.Initialize_Status;
      Screen_Status : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Primary_Generation : Terminal.Core.Graphics_Screen_Generation;
      Alternate_Generation : Terminal.Core.Graphics_Screen_Generation;
   begin
      Terminal.Core.Initialize (Screen_T, 2, 4, 10, Screen_Init);
      Assert (Screen_Init = Terminal.Core.Ok, "graphics screen initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Screen_T, 77);
      declare
         Snapshot : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Screen_T);
      begin
         Primary_Generation := Snapshot.Screen_Generation;
         Assert
           (not Snapshot.Alternate_Screen
            and then Primary_Generation /= 0,
            "primary graphics screen identity");
         Terminal.Core.Release (Snapshot);
      end;

      Terminal.Core.Feed
        (Screen_T,
         To_Bytes
           (ASCII.ESC & "_Ga=p,i=1,C=1" & ASCII.ESC & "\"
            & ASCII.ESC & "[?1049h"),
         Screen_Status);
      Assert (Screen_Status = Terminal.Core.Ok, "queue before alternate entry");
      Terminal.Core.Peek_Graphics_Event (Screen_T, Event);
      Assert
        (Event.Pending
         and then not Event.Alternate_Screen
         and then Event.Screen_Generation = Primary_Generation,
         "queued placement retains originating primary screen");
      Terminal.Core.Discard_Graphics_Event (Screen_T);

      declare
         Snapshot : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Screen_T);
      begin
         Alternate_Generation := Snapshot.Screen_Generation;
         Assert
           (Snapshot.Alternate_Screen
            and then Alternate_Generation /= 0,
            "alternate graphics screen identity");
         Terminal.Core.Release (Snapshot);
      end;

      Terminal.Core.Feed
        (Screen_T,
         To_Bytes (ASCII.ESC & "[?1049l" & ASCII.ESC & "[2J"),
         Screen_Status);
      declare
         Snapshot : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Screen_T);
      begin
         Assert
           (not Snapshot.Alternate_Screen
            and then Snapshot.Screen_Generation /= Primary_Generation,
            "full primary clear advances placement lifetime");
         Terminal.Core.Release (Snapshot);
      end;

      Terminal.Core.Feed
        (Screen_T, To_Bytes (ASCII.ESC & "[?1049h"), Screen_Status);
      declare
         Snapshot : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Screen_T);
      begin
         Assert
           (Snapshot.Alternate_Screen
            and then Snapshot.Screen_Generation /= Alternate_Generation,
            "alternate re-entry advances placement lifetime");
         Terminal.Core.Release (Snapshot);
      end;
      Terminal.Core.Finalize (Screen_T);
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("screen generations", E);
   end;

   declare
      Full_T : Terminal.Core.Terminal;
      Full_Init : Terminal.Core.Initialize_Status;
      Full_Status : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Data_Length : constant Natural :=
        Terminal.Core.Max_Graphics_Preview_Length + 257;
   begin
      Terminal.Core.Initialize (Full_T, 2, 4, 10, Full_Init);
      Assert (Full_Init = Terminal.Core.Ok, "full graphics payload initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Full_T, 88);
      Terminal.Core.Feed
        (Full_T,
         To_Bytes
           (ASCII.ESC & "]1337;MultipartFile=inline=1" & ASCII.BEL
            & ASCII.ESC & "]1337;FilePart="
            & Repeat_Char ('A', Data_Length) & ASCII.BEL
            & ASCII.ESC & "]1337;FileEnd" & ASCII.BEL),
         Full_Status);
      Assert (Full_Status = Terminal.Core.Ok, "full graphics payload feed");
      Terminal.Core.Peek_Graphics_Event (Full_T, Event);
      declare
         Payload : constant String :=
           Terminal.Core.Graphics_Event_Payload (Full_T, Event);
      begin
         Assert
           (Event.Pending
            and then Event.Preview_Length =
              Terminal.Core.Max_Graphics_Preview_Length
            and then Event.Payload_Length = Data_Length + 14
            and then Payload'Length = Event.Payload_Length
            and then Payload (Payload'First .. Payload'First + 4) = "File="
            and then Payload (Payload'Last) = 'A',
            "complete payload is available beyond the bounded preview");
      end;
      Terminal.Core.Finalize (Full_T);
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("preview bounds", E);
   end;

   declare
      Reject_T : Terminal.Core.Terminal;
      Reject_Init : Terminal.Core.Initialize_Status;
      Reject_Status : Terminal.Core.Feed_Status;
   begin
      Terminal.Core.Initialize (Reject_T, 2, 4, 10, Reject_Init);
      Assert (Reject_Init = Terminal.Core.Ok, "queue rejection initialize");
      Terminal.Core.Set_Graphics_Resource_Limits
        (Reject_T,
         (Transaction_Length => 128,
          Pending_Events => 2,
          Pending_Bytes => 16,
          Deferred_Input_Bytes => 128,
          Pixel_Dimension => 16));
      Terminal.Core.Feed
        (Reject_T,
         To_Bytes
           (ASCII.ESC & "_Ga=d,i=123456789012345678901234" & ASCII.ESC & "\"),
         Reject_Status);
      declare
         Rejected_Snapshot : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Reject_T);
      begin
         Assert
           (Reject_Status = Terminal.Core.Parser_Overflow
            and then Terminal.Core.Pending_Graphics_Event_Count (Reject_T) = 0
            and then not Rejected_Snapshot.Graphics.Pending,
            "queue byte rejection is not published through the snapshot");
         Terminal.Core.Release (Rejected_Snapshot);
      end;
      Terminal.Core.Finalize (Reject_T);
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("oversized rejection", E);
   end;

end Screen_Cases;

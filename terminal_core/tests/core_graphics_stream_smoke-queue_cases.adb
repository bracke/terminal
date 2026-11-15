separate (Core_Graphics_Stream_Smoke)
procedure Queue_Cases is
   T    : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
begin
   Terminal.Core.Initialize (T, 2, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "queue cases initialize");
   Terminal.Core.Set_Graphics_Stream_ID (T, 42);
   declare
      First  : constant String := "Gq=2,f=32,s=1,v=1,i=11;AAAAAA==";
      Second : constant String := "Gq=2,a=p,i=11,p=2";
   begin
      Feed_Text (T, ASCII.ESC & "_" & First & ASCII.ESC & "\"
         & ASCII.ESC & "_" & Second & ASCII.ESC & "\");
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (T) = 2,
         "consecutive commands must both be queued");
      Assert
        (Terminal.Core.Pending_Graphics_Byte_Count (T) =
           First'Length + Second'Length,
         "queued byte count");

      declare
         Snapshot : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Assert
           (Snapshot.Graphics.Preview
              (1 .. Snapshot.Graphics.Preview_Length) = Second,
            "legacy snapshot remains the latest command");
         Assert
           (Snapshot.Graphics.Stream_ID = 42
            and then Snapshot.Graphics.Sequence = 2,
            "legacy snapshot carries stable stream and sequence identity");
         Terminal.Core.Release (Snapshot);
      end;

      Drain_And_Assert (T, First, "first FIFO event");
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (T) = 1,
         "first event consumed");
      Drain_And_Assert (T, Second, "second FIFO event");
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (T) = 0
         and then Terminal.Core.Pending_Graphics_Byte_Count (T) = 0,
         "FIFO drained");
      declare
         Snapshot : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Assert
           (not Snapshot.Graphics.Pending,
            "draining the FIFO clears the compatibility graphics event");
         Terminal.Core.Release (Snapshot);
      end;
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("FIFO delivery", E);
   end;

   declare
      Complete : constant String := "Gq=2,a=p,i=12,p=1";
      Assembled : constant String :=
        "Gq=2,f=32,s=1,v=1,i=13,m=0;AAAABBBB";
      Partial_T : Terminal.Core.Terminal;
      Partial_Init : Terminal.Core.Initialize_Status;
      Partial_Status : Terminal.Core.Feed_Status;

      procedure Partial_Feed (Text : String) is
      begin
         Terminal.Core.Feed (Partial_T, To_Bytes (Text), Partial_Status);
         Assert (Partial_Status = Terminal.Core.Ok, "partial-event feed");
      end Partial_Feed;
   begin
      Terminal.Core.Initialize (Partial_T, 2, 10, 100, Partial_Init);
      Assert (Partial_Init = Terminal.Core.Ok, "partial-event initialize");
      Partial_Feed (ASCII.ESC & "_" & Complete & ASCII.ESC & "\");
      Partial_Feed
        (ASCII.ESC & "_Gq=2,f=32,s=1,v=1,i=13,m=1;AAAA"
         & ASCII.ESC & "\");
      declare
         Snapshot : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Partial_T);
      begin
         if not Snapshot.Graphics.Pending
           or else Snapshot.Graphics.Preview_Length /= Complete'Length
           or else Snapshot.Graphics.Preview
             (1 .. Snapshot.Graphics.Preview_Length) /= Complete
         then
            raise Program_Error with
              "partial Kitty chunk replaced the queued compatibility event";
         end if;
         Terminal.Core.Release (Snapshot);
      end;
      Partial_Feed (ASCII.ESC & "_Gm=0;BBBB" & ASCII.ESC & "\");
      declare
         Event : Terminal.Core.Graphics_Event;
      begin
         Terminal.Core.Peek_Graphics_Event (Partial_T, Event);
         if not Event.Pending
           or else
             Terminal.Core.Graphics_Event_Payload (Partial_T, Event) /= Complete
         then
            raise Program_Error with
              "event preceding partial Kitty transaction lost FIFO identity";
         end if;
         Terminal.Core.Discard_Graphics_Event (Partial_T);
         Terminal.Core.Peek_Graphics_Event (Partial_T, Event);
         if not Event.Pending
           or else
             Terminal.Core.Graphics_Event_Payload (Partial_T, Event) /= Assembled
         then
            raise Program_Error with
              "assembled Kitty transaction did not follow queued event";
         end if;
         Terminal.Core.Discard_Graphics_Event (Partial_T);
      end;
      Terminal.Core.Finalize (Partial_T);
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("chunk assembly", E);
   end;

   declare
      Payload : constant String := "Gf=100,a=t,i=19;AAAA";
      Framed  : constant String :=
        ASCII.ESC & "_" & Payload & ASCII.ESC & "\";
   begin
      for Ch of Framed loop
         Feed_Text (T, (1 => Ch));
      end loop;
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (T) = 1,
         "arbitrary read boundaries");
      Drain_And_Assert (T, Payload, "byte-at-a-time event");
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("arbitrary boundaries", E);
   end;

   declare
   begin
      Feed_Text (T, ASCII.ESC & "_Gf=100;AAAA" & ASCII.CAN & "x");
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (T) = 0,
         "CAN cancels APC command");
      declare
         Snapshot : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (T);
      begin
         Assert
           (Terminal.Core.Cell_At (Snapshot, 1, 1).Text.Code_Point =
              Character'Pos ('x'),
            "text resumes after cancelled APC");
         Terminal.Core.Release (Snapshot);
      end;
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("APC cancellation", E);
   end;

   declare
      Payload : constant String := "Ga=d,d=i,i=19";
      Event   : Terminal.Core.Graphics_Event;
   begin
      Feed_Text (T, ASCII.ESC & "_" & Payload & ASCII.ESC & "\");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert
        (Event.Pending
         and then Event.Stream_ID = 42
         and then Event.Sequence = 4
         and then Event.Preview (1 .. Event.Preview_Length) = Payload,
         "peek returns FIFO head without consuming it");
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (T) = 1,
         "peek preserves FIFO head");
      Terminal.Core.Discard_Graphics_Event (T);
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (T) = 0
         and then Terminal.Core.Pending_Graphics_Byte_Count (T) = 0,
         "discard releases FIFO head");
      declare
         Snapshot : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Assert
           (not Snapshot.Graphics.Pending,
            "discard clears the final published graphics event");
         Terminal.Core.Release (Snapshot);
      end;
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("event discard", E);
   end;

end Queue_Cases;

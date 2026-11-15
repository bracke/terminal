separate (Core_Graphics_Stream_Smoke)
procedure Response_Cases is
   T    : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
begin
   Terminal.Core.Initialize (T, 2, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "response cases initialize");
   Terminal.Core.Set_Graphics_Stream_ID (T, 42);
   declare
      Event : Terminal.Core.Graphics_Event;
      Stale : Terminal.Core.Graphics_Event;
   begin
      Feed_Text (T, ASCII.ESC & "_Ga=p,i=77,p=3" & ASCII.ESC & "\");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Stale := Event;
      Stale.Sequence := Stale.Sequence + 1;
      Terminal.Core.Complete_Graphics_Event
        (T,
         Stale,
         Kitty_Completion
           (Terminal.Core.Graphics_OK, 77, Placement_ID => 3));
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (T) = 1,
         "stale completion must preserve FIFO head");
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         Kitty_Completion
           (Terminal.Core.Graphics_OK, 77, Placement_ID => 3));
      Assert_Response (T, ASCII.ESC & "_Gi=77,p=3;OK" & ASCII.ESC & "\",
         "committed placement response");

      Feed_Text (T, ASCII.ESC & "_Ga=p,I=88,q=1" & ASCII.ESC & "\");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         Kitty_Completion
           (Terminal.Core.Graphics_OK, 123, Image_Number => 88, Quiet => 1));
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "q=1 completion suppresses OK response");

      Feed_Text (T, ASCII.ESC & "_Ga=p,i=99,q=2" & ASCII.ESC & "\");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         Kitty_Completion
           (Terminal.Core.Graphics_ENOENT, 99, Quiet => 2));
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "q=2 completion suppresses error response");

      Feed_Text (T, ASCII.ESC & "_Ga=p,i=99,q=2" & ASCII.ESC & "\");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         Kitty_Completion (Terminal.Core.Graphics_OK, 99, Quiet => 2));
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "q=2 completion suppresses success response");

      Feed_Text (T, ASCII.ESC & "_Gf=32,s=1,v=1,i=101,m=1;AAAA" & ASCII.ESC & "\"
         & ASCII.ESC & "_Gm=0,q=2;" & ASCII.ESC & "\");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert
        (Terminal.Core.Graphics_Event_Payload (T, Event) =
           "Gf=32,s=1,v=1,i=101,m=0,q=2;AAAA",
         "final chunk quiet mode is retained in the assembled command");
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         Kitty_Completion (Terminal.Core.Graphics_OK, 101, Quiet => 2));
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "final chunk q=2 suppresses success response");

      Feed_Text (T, ASCII.ESC & "_Ga=t,f=32,s=1,v=1,i=102,q=0;AAAA"
         & ASCII.ESC & "\" & ASCII.ESC & "[c");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "later DA response waits for a transmitting command response");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         Kitty_Completion (Terminal.Core.Graphics_OK, 102));
      Assert_Response (T, ASCII.ESC & "_Gi=102;OK" & ASCII.ESC & "\"
         & ASCII.ESC & "[?62;4;22c",
         "transmission response precedes later DA response");

      Feed_Text (T, ASCII.ESC & "_Ga=T,f=32,s=1,v=1;AAAA" & ASCII.ESC & "\");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         Kitty_Completion (Terminal.Core.Graphics_OK, Respond => False));
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "anonymous transmission completion emits no response");

      Feed_Text (T, ASCII.ESC & "_Ga=p,i=101,p=4" & ASCII.ESC & "\");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         Kitty_Completion
           (Terminal.Core.Graphics_ECYCLE, 101, Placement_ID => 4));
      Assert_Response (T, ASCII.ESC
         & "_Gi=101,p=4;ECYCLE:Relative placement cycle"
         & ASCII.ESC & "\",
         "relative cycle completion response");
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("response ordering", E);
   end;

   declare
      Stream_T      : Terminal.Core.Terminal;
      Stream_Init   : Terminal.Core.Initialize_Status;
      Stream_Status : Terminal.Core.Feed_Status;
      Event         : Terminal.Core.Graphics_Event;
   begin
      Terminal.Core.Initialize (Stream_T, 2, 10, 20, Stream_Init);
      Assert (Stream_Init = Terminal.Core.Ok, "stream identity core initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Stream_T, 701);
      Terminal.Core.Feed
        (Stream_T,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=t,f=32,s=1,v=1;AAAAAA=="
            & ASCII.ESC & "\"),
         Stream_Status);
      Assert (Stream_Status = Terminal.Core.Ok, "stream identity event feed");
      Terminal.Core.Set_Graphics_Stream_ID (Stream_T, 702);
      declare
         Snapshot : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Stream_T);
      begin
         Assert
           (Snapshot.Graphics.Pending
            and then Snapshot.Graphics.Stream_ID = 701,
            "compatibility snapshot retains enqueue-time stream identity");
         Terminal.Core.Release (Snapshot);
      end;
      Terminal.Core.Peek_Graphics_Event (Stream_T, Event);
      Assert
        (Event.Pending and then Event.Stream_ID = 701,
         "queued event retains enqueue-time stream identity");
      Assert
        (Terminal.Core.Graphics_Event_Payload (Stream_T, Event)'Length > 0,
         "queued event payload remains addressable after stream change");
      Terminal.Core.Complete_Graphics_Event
        (Stream_T,
         Event,
         Kitty_Completion (Terminal.Core.Graphics_OK, Respond => False));
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (Stream_T) = 0,
         "enqueue-time stream event completes after stream change");
      Terminal.Core.Finalize (Stream_T);
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("stream identity", E);
   end;

end Response_Cases;

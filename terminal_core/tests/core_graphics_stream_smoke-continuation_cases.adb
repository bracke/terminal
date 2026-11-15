separate (Core_Graphics_Stream_Smoke)
procedure Continuation_Cases is
   T    : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
begin
   Terminal.Core.Initialize (T, 2, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "continuation cases initialize");
   Terminal.Core.Set_Graphics_Stream_ID (T, 42);
   declare
      Interleave_T : Terminal.Core.Terminal;
      Interleave_Init : Terminal.Core.Initialize_Status;
      Interleave_Status : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;

      procedure Interleave_Feed (Text : String) is
      begin
         Terminal.Core.Feed
           (Interleave_T, To_Bytes (Text), Interleave_Status);
         Assert
           (Interleave_Status = Terminal.Core.Ok,
            "chunk interleave feed");
      end Interleave_Feed;
   begin
      Terminal.Core.Initialize
        (Interleave_T, 2, 10, 20, Interleave_Init);
      Assert
        (Interleave_Init = Terminal.Core.Ok,
         "chunk interleave initialize");

      Interleave_Feed
        (ASCII.ESC & "_Gq=2,a=t,i=130,f=32,s=1,v=1,m=1;/wAA"
         & ASCII.ESC & "\" & "x");
      Terminal.Core.Peek_Graphics_Event (Interleave_T, Event);
      Assert
        (Event.Pending and then Event.Cancelled and then Event.Payload_Length > 0,
         "ordinary text invalidates a partial Kitty transaction");
      Terminal.Core.Discard_Graphics_Event (Interleave_T);

      Interleave_Feed
        (ASCII.ESC & "_Gq=2,a=t,i=131,f=32,s=1,v=1,m=1;/wAA"
         & ASCII.ESC & "\"
         & ASCII.ESC & "Pq~" & ASCII.ESC & "\");
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (Interleave_T) = 2,
         "another graphics protocol invalidates Kitty before queuing itself");
      Terminal.Core.Discard_Graphics_Event (Interleave_T);
      Terminal.Core.Discard_Graphics_Event (Interleave_T);

      Interleave_Feed
        (ASCII.ESC & "_Gq=2,a=t,i=132,f=32,s=1,v=1,m=1;/wAA"
         & ASCII.ESC & "\"
         & ASCII.ESC & "Ptmux;" & ASCII.ESC & ASCII.ESC
         & "_Gq=2,m=0;/w==" & ASCII.ESC & ASCII.ESC & "\"
         & ASCII.ESC & "\");
      Terminal.Core.Peek_Graphics_Event (Interleave_T, Event);
      Assert
        (Event.Pending and then not Event.Cancelled
         and then Terminal.Core.Pending_Graphics_Event_Count (Interleave_T) = 1
         and then Terminal.Core.Graphics_Event_Payload (Interleave_T, Event) =
           "Gq=2,a=t,i=132,f=32,s=1,v=1,m=0;/wAA/w==",
         "tmux-wrapped continuation completes the core-owned transaction");

      Terminal.Core.Finalize (Interleave_T);
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("interleaved continuations", E);
   end;

   declare
      Prefix : constant String := "Gf=100,a=t,i=23;";
      Large  : String
        (1 .. Terminal.Core.Max_Graphics_Preview_Length + 37);
   begin
      Large (Prefix'Range) := Prefix;
      Large (Prefix'Last + 1 .. Large'Last) := (others => 'A');
      Feed_Text (T, ASCII.ESC & "_" & Large & ASCII.ESC & "\");
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (T) = 1,
         "large Kitty command queued");
      Assert
        (Terminal.Core.Pending_Graphics_Byte_Count (T) = Large'Length,
         "large Kitty command retains complete payload");
      declare
         Snapshot : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Assert
           (Snapshot.Graphics.Payload_Length = Large'Length,
            "large command actual payload length");
         Assert
           (Snapshot.Graphics.Preview_Length =
              Terminal.Core.Max_Graphics_Preview_Length,
            "legacy large command preview remains bounded");
         Terminal.Core.Release (Snapshot);
      end;
      Drain_And_Assert (T, Large, "large event");
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("large payload", E);
   end;

   declare
   begin
      Feed_Text (T, ASCII.ESC & "_Gi=30,s=1,v=1,a=q,t=d,f=24;AAAA"
      & ASCII.ESC & "\");
   Assert
     (Terminal.Core.Pending_Graphics_Event_Count (T) = 1,
      "query must enter graphics event FIFO for backend validation");
   Complete_Kitty_Query (T, 30, Terminal.Core.Graphics_ENOTSUP);
   Assert_Response (T, ASCII.ESC & "_Gi=30;ENOTSUP:Unsupported graphics operation"
      & ASCII.ESC & "\",
      "disabled direct query");
   Feed_Text (T, ASCII.ESC & "]1337;Capabilities" & ASCII.ESC & "\");
   Assert_Response (T, ASCII.ESC & "]1337;Capabilities=" & ASCII.ESC & "\",
      "disabled graphics feature report");

   Terminal.Core.Set_Graphics_Capabilities
     (T,
      (Kitty_Direct_RGB         => True,
       Kitty_Direct_RGBA        => True,
       Kitty_Indexed_RGB        => True,
       Kitty_Indexed_RGBA       => True,
       Kitty_Direct_PNG         => True,
       Kitty_Direct_JPEG        => True,
       Kitty_Direct_GIF         => True,
       Kitty_Zlib_Compression   => True,
       Kitty_File_Transfer      => False,
       Kitty_Temporary_Transfer => False,
       Kitty_Shared_Memory      => False,
       Sixel                    => True,
       ITerm2_Inline_Images     => False,
       ITerm2_File_Downloads    => False));
   Feed_Text (T, ASCII.ESC & "]1337;Capabilities" & ASCII.ESC & "\");
   Assert_Response (T, ASCII.ESC & "]1337;Capabilities=Sx" & ASCII.ESC & "\",
      "truthful sixel feature report");
   Feed_Text (T, ASCII.ESC & "_Gi=31,p=7,s=1,v=1,a=q,t=d,f=24;AAAA"
      & ASCII.ESC & "\" & ASCII.ESC & "[c");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 0,
      "later DA response must wait for backend query validation");
   Complete_Kitty_Query (T, 31, Terminal.Core.Graphics_OK, Placement_ID => 7);
   Assert_Response (T, ASCII.ESC & "_Gi=31,p=7;OK" & ASCII.ESC & "\"
      & ASCII.ESC & "[?62;4;22c",
      "direct query before later DA response");

   Feed_Text (T, ASCII.ESC & "_Gi=39,s=1,v=1,a=q,t=d,f=24,o=z;AAAA"
      & ASCII.ESC & "\"
      & ASCII.ESC & "_Gi=40,s=1,v=1,a=q,t=d,f=24,o=x;AAAA"
      & ASCII.ESC & "\");
   Complete_Kitty_Query (T, 39, Terminal.Core.Graphics_OK);
   Complete_Kitty_Query (T, 40, Terminal.Core.Graphics_ENOTSUP);
   Assert_Response (T, ASCII.ESC & "_Gi=39;OK" & ASCII.ESC & "\"
      & ASCII.ESC & "_Gi=40;ENOTSUP:Unsupported graphics operation"
      & ASCII.ESC & "\",
      "compression capability queries");

   Feed_Text (T, ASCII.ESC & "Ptmux;"
      & ASCII.ESC & ASCII.ESC
      & "_Gi=35,s=1,v=1,a=q,t=d,f=24;AAAA"
      & ASCII.ESC & ASCII.ESC & "\"
      & ASCII.ESC & "\");
   Complete_Kitty_Query (T, 35, Terminal.Core.Graphics_OK);
   Assert_Response (T, ASCII.ESC & "_Gi=35;OK" & ASCII.ESC & "\",
      "tmux-passthrough direct query");
   Assert
     (Terminal.Core.Pending_Graphics_Event_Count (T) = 0,
      "tmux query should be consumed after backend validation");

   Feed_Text (T, ASCII.ESC & "_Gi=32,s=1,v=1,a=q,t=s,f=24,S=3;L2FiYw=="
      & ASCII.ESC & "\");
   Complete_Kitty_Query (T, 32, Terminal.Core.Graphics_ENOTSUP);
   Assert_Response (T, ASCII.ESC & "_Gi=32;ENOTSUP:Unsupported graphics operation"
      & ASCII.ESC & "\",
      "shared-memory query");

   Feed_Text (T, ASCII.ESC & "_Gi=36,s=1,v=1,a=q,t=direct,f=24;AAAA"
      & ASCII.ESC & "\"
      & ASCII.ESC & "_Gi=37,p=bad,s=1,v=1,a=q,t=d,f=24;AAAA"
      & ASCII.ESC & "\"
      & ASCII.ESC & "_Gi=38,s=1,v=1,a=q,t=d,f=24,q=9;AAAA"
      & ASCII.ESC & "\");
   Complete_Kitty_Query (T, 36, Terminal.Core.Graphics_EINVAL);
   Complete_Kitty_Query (T, 37, Terminal.Core.Graphics_EINVAL);
   Complete_Kitty_Query (T, 38, Terminal.Core.Graphics_EINVAL);
   Assert_Response (T, ASCII.ESC & "_Gi=36;EINVAL:Invalid control data" & ASCII.ESC & "\"
      & ASCII.ESC & "_Gi=37;EINVAL:Invalid control data" & ASCII.ESC & "\"
      & ASCII.ESC & "_Gi=38;EINVAL:Invalid control data" & ASCII.ESC & "\",
      "malformed query controls");
   Assert
     (Terminal.Core.Pending_Graphics_Event_Count (T) = 0,
      "malformed queries remain side-effect free");

   Feed_Text (T, ASCII.ESC & "_Gi=33,s=1,v=1,a=q,t=d,f=24,q=1;AAAA"
      & ASCII.ESC & "\"
      & ASCII.ESC & "_Gi=34,s=1,v=1,a=q,t=s,f=24,q=2;AAAA"
      & ASCII.ESC & "\");
   Complete_Kitty_Query (T, 33, Terminal.Core.Graphics_OK, Quiet => 1);
   Complete_Kitty_Query (T, 34, Terminal.Core.Graphics_ENOTSUP, Quiet => 2);
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 0,
      "query quiet modes suppress selected response class");
   Assert
     (Terminal.Core.Pending_Graphics_Event_Count (T) = 0,
      "quiet queries remain side-effect free");
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("capability queries", E);
   end;

end Continuation_Cases;

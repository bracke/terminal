separate (Core_Graphics_Stream_Smoke)
procedure Transaction_Cases is
begin
   declare
      Ordered_T      : Terminal.Core.Terminal;
      Ordered_Init   : Terminal.Core.Initialize_Status;
      Ordered_Status : Terminal.Core.Feed_Status;
      Event          : Terminal.Core.Graphics_Event;

      procedure Ordered_Feed (Text : String) is
      begin
         Terminal.Core.Feed
           (Ordered_T, To_Bytes (Text), Ordered_Status);
         Assert (Ordered_Status = Terminal.Core.Ok, "ordered graphics feed");
      end Ordered_Feed;
   begin
      Terminal.Core.Initialize (Ordered_T, 4, 10, 20, Ordered_Init);
      Assert (Ordered_Init = Terminal.Core.Ok, "ordered core initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Ordered_T, 314);

      Ordered_Feed
        (ASCII.ESC & "_Ga=p,i=77,p=3,c=2,r=1" & ASCII.ESC & "\" & "X");
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (Ordered_T) = 1,
         "cursor-moving placement queued");
      declare
         Before : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Ordered_T);
      begin
         Assert
           (Terminal.Core.Cell_At (Before, 1, 1).Text.Code_Point /=
              Character'Pos ('X'),
            "text after placement remains deferred before commit");
         Terminal.Core.Release (Before);
      end;

      Terminal.Core.Peek_Graphics_Event (Ordered_T, Event);
      Terminal.Core.Complete_Graphics_Event
        (Ordered_T,
         Event,
         (Code => Terminal.Core.Graphics_OK,
          Kitty_Response =>
            (Present => True, Image_ID => 77, Placement_ID => 3,
             Has_Placement_ID => True, others => <>),
          Cursor =>
            (Move => True, Placement_Columns => 2, Placement_Rows => 1,
             others => <>)));
      declare
         After : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Ordered_T);
      begin
         Assert
           (Terminal.Core.Cell_At (After, 2, 3).Text.Code_Point =
              Character'Pos ('X'),
            "deferred text uses committed image cursor movement");
         Terminal.Core.Release (After);
      end;

      Ordered_Feed (ASCII.ESC & "c");
      Ordered_Feed
        (ASCII.ESC & "[4;1H"
         & ASCII.ESC & "_Ga=p,i=79,q=2,c=1,r=1" & ASCII.ESC & "\" & "H");
      Terminal.Core.Peek_Graphics_Event (Ordered_T, Event);
      Terminal.Core.Complete_Graphics_Event
        (Ordered_T,
         Event,
         (Code => Terminal.Core.Graphics_OK,
          Kitty_Response =>
            (Present => True, Image_ID => 79, Quiet => 2, others => <>),
          Cursor =>
            (Move => True, Placement_Rows => Positive'Last, others => <>)));
      declare
         Bounded : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Ordered_T);
      begin
         Assert
           (Terminal.Core.Graphics_Scroll_Count (Bounded) = 1,
            "oversized Kitty cursor movement records one boundary scroll");
         Assert
           (Terminal.Core.Cell_At (Bounded, 4, 2).Text.Code_Point =
              Character'Pos ('H'),
            "oversized Kitty cursor movement resumes deferred input");
         Terminal.Core.Release (Bounded);
      end;

      Ordered_Feed (ASCII.ESC & "c");
      Ordered_Feed
        (ASCII.ESC & "[4;10H"
         & ASCII.ESC & "_Ga=p,i=78,p=6,c=2,r=1" & ASCII.ESC & "\" & "W");
      Terminal.Core.Peek_Graphics_Event (Ordered_T, Event);
      declare
         Resize_Result : Terminal.Core.Resize_Status;
      begin
         Terminal.Core.Resize (Ordered_T, 2, 3, Resize_Result);
         Assert
           (Resize_Result = Terminal.Core.Ok,
            "terminal shrinks while graphics completion is pending");
      end;
      Terminal.Core.Complete_Graphics_Event
        (Ordered_T,
         Event,
         (Code => Terminal.Core.Graphics_OK,
          Kitty_Response =>
            (Present => True, Image_ID => 78, Placement_ID => 6,
             Has_Placement_ID => True, others => <>),
          Cursor =>
            (Move => True, Placement_Columns => 2, Placement_Rows => 1,
             others => <>)));
      declare
         After_Resize : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Ordered_T);
      begin
         Assert
           (Terminal.Core.Cell_At (After_Resize, 2, 3).Text.Code_Point =
              Character'Pos ('W'),
            "completion clamps stale anchors after resize");
         Terminal.Core.Release (After_Resize);
      end;
      declare
         Resize_Result : Terminal.Core.Resize_Status;
      begin
         Terminal.Core.Resize (Ordered_T, 4, 10, Resize_Result);
         Assert (Resize_Result = Terminal.Core.Ok, "restore ordered test size");
      end;

      Ordered_Feed (ASCII.ESC & "c");
      Ordered_Feed
        (ASCII.ESC & "_Ga=p,i=88,p=4,c=2,r=1" & ASCII.ESC & "\" & "Y");
      Terminal.Core.Peek_Graphics_Event (Ordered_T, Event);
      Terminal.Core.Complete_Graphics_Event
        (Ordered_T,
         Event,
         Kitty_Completion
           (Terminal.Core.Graphics_ENOENT, 88, Placement_ID => 4));
      declare
         Failed : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Ordered_T);
      begin
         Assert
           (Terminal.Core.Cell_At (Failed, 1, 1).Text.Code_Point =
              Character'Pos ('Y'),
            "failed placement resumes text without cursor movement");
         Terminal.Core.Release (Failed);
      end;

      Ordered_Feed (ASCII.ESC & "c");
      Ordered_Feed
        (ASCII.ESC & "_Gq=2,a=p,i=99,p=5,c=2,r=1,C=1"
         & ASCII.ESC & "\" & "Z");
      declare
         No_Move : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Ordered_T);
      begin
         Assert
           (Terminal.Core.Cell_At (No_Move, 1, 1).Text.Code_Point =
              Character'Pos ('Z'),
            "C=1 placement does not defer following text");
         Terminal.Core.Release (No_Move);
      end;
      Terminal.Core.Discard_Graphics_Event (Ordered_T);

      Ordered_Feed (ASCII.ESC & "c");
      Ordered_Feed
        (ASCII.ESC & "_Gq=2,a=T,C=1,i=120,m=1;AAAA" & ASCII.ESC & "\"
         & ASCII.ESC & "_Gm=0;BBBB" & ASCII.ESC & "\" & "S");
      declare
         Chunk_No_Move : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Ordered_T);
      begin
         Assert
           (Terminal.Core.Cell_At (Chunk_No_Move, 1, 1).Text.Code_Point =
              Character'Pos ('S'),
            "chunked C=1 policy does not block following text");
         Terminal.Core.Release (Chunk_No_Move);
      end;
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (Ordered_T) = 1,
         "complete chunk transaction queues one logical event");
      Terminal.Core.Peek_Graphics_Event (Ordered_T, Event);
      Assert
        (not Event.Cancelled
         and then Event.Payload_Length =
           String'("Gq=2,a=T,C=1,i=120,m=0;AAAABBBB")'Length,
         "core owns assembled chunk payload");
      Assert
        (Terminal.Core.Graphics_Event_Payload (Ordered_T, Event) =
           "Gq=2,a=T,C=1,i=120,m=0;AAAABBBB",
         "assembled chunk preserves the first controls and concatenates data");
      Terminal.Core.Discard_Graphics_Event (Ordered_T);

      Ordered_Feed (ASCII.ESC & "c");
      Ordered_Feed
        (ASCII.ESC & "_Ga=T,f=32,s=1,v=1,C=1,m=1" & ASCII.ESC & "\");
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (Ordered_T) = 0,
         "metadata-only first chunk remains pending");
      Ordered_Feed
        (ASCII.ESC & "_Gm=1;/wAA" & ASCII.ESC & "\");
      Ordered_Feed
        (ASCII.ESC & "_Gm=0" & ASCII.ESC & "\");
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (Ordered_T) = 1,
         "empty final chunk completes one logical event");
      Terminal.Core.Peek_Graphics_Event (Ordered_T, Event);
      Assert
        (not Event.Cancelled
         and then Terminal.Core.Graphics_Event_Payload (Ordered_T, Event) =
           "Ga=T,f=32,s=1,v=1,C=1,m=0;/wAA",
         "metadata-only and empty-final chunks assemble for real clients");
      Terminal.Core.Discard_Graphics_Event (Ordered_T);

      Ordered_Feed (ASCII.ESC & "c");
      Ordered_Feed
        (ASCII.ESC & "_Ga=T,i=121,m=1;AAAA" & ASCII.ESC & "\"
         & ASCII.ESC & "_Gm=0;BBBB" & ASCII.ESC & "\" & "R");
      declare
         Chunk_Before : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Ordered_T);
      begin
         Assert
           (Terminal.Core.Cell_At (Chunk_Before, 1, 1).Text.Code_Point /=
              Character'Pos ('R'),
            "chunked moving placement defers following text");
         Terminal.Core.Release (Chunk_Before);
      end;
      Terminal.Core.Peek_Graphics_Event (Ordered_T, Event);
      Assert
        (not Event.Cancelled
         and then Event.Payload_Length > String'("Gm=0;BBBB")'Length,
         "moving chunk is assembled");
      Terminal.Core.Complete_Graphics_Event
        (Ordered_T,
         Event,
         (Code => Terminal.Core.Graphics_OK,
          Kitty_Response =>
            (Present => True, Image_ID => 121, others => <>),
          Cursor =>
            (Move => True, Placement_Columns => 1, Placement_Rows => 1,
             others => <>)));
      declare
         Chunk_After : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Ordered_T);
      begin
         Assert
           (Terminal.Core.Cell_At (Chunk_After, 2, 2).Text.Code_Point =
              Character'Pos ('R'),
            "chunked placement uses final-chunk cursor anchor");
         Terminal.Core.Release (Chunk_After);
      end;
      Terminal.Core.Finalize (Ordered_T);
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("ordered completion", E);
   end;

end Transaction_Cases;

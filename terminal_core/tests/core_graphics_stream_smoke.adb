with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Graphics_Stream_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Ignored_Graphics_Protocol;
   use type Terminal.Core.Graphics_Stream_ID;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Graphics_Screen_Generation;
   use type Terminal.Core.Graphics_Event_Sequence;
   use type Terminal.Core.Graphics_Resource_Limits;
   use type Terminal.Core.Initialize_Status;

   T      : Terminal.Core.Terminal;
   Init   : Terminal.Core.Initialize_Status;
   Status : Terminal.Core.Feed_Status;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   function Repeat_Char (Ch : Character; Count : Natural) return String is
      Result : String (1 .. Count);
   begin
      Result := (others => Ch);
      return Result;
   end Repeat_Char;

   procedure Feed_Text (Text : String) is
   begin
      Terminal.Core.Feed (T, To_Bytes (Text), Status);
      Assert (Status = Terminal.Core.Ok, "graphics stream feed");
   end Feed_Text;

   procedure Complete_Kitty_Query
     (Image_ID : Terminal.Core.Graphics_ID;
      Code     : Terminal.Core.Kitty_Graphics_Result_Code;
      Quiet    : Natural := 0;
      Placement_ID : Terminal.Core.Graphics_ID := 0)
   is
      Event : Terminal.Core.Graphics_Event;
   begin
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert
        (Event.Pending and then Event.Protocol = Terminal.Core.Kitty_Graphics,
         "Kitty query should be queued for backend validation");
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         (Code             => Code,
          Image_ID         => Image_ID,
          Placement_ID     => Placement_ID,
          Has_Placement_ID => Placement_ID /= 0,
          Quiet            => Quiet,
          others           => <>));
   end Complete_Kitty_Query;

   procedure Drain_And_Assert (Expected : String; Label_Text : String) is
      Buffer : Byte_Array (1 .. 7);
      Event  : Terminal.Core.Graphics_Event;
      Last   : Natural;
      Done   : Boolean := False;
      Offset : Natural := 0;
   begin
      while not Done loop
         Terminal.Core.Read_Graphics_Event
           (T, Event, Buffer, Last, Done);
         Assert (Event.Pending, Label_Text & " pending");
         Assert
           (Event.Protocol = Terminal.Core.Kitty_Graphics,
            Label_Text & " protocol");
         Assert
           (Event.Payload_Length = Expected'Length,
            Label_Text & " payload length");
         for I in 1 .. Last loop
            Offset := Offset + 1;
            Assert
              (Buffer (Buffer'First + I - 1) =
                 Byte (Character'Pos (Expected (Expected'First + Offset - 1))),
               Label_Text & " payload byte" & Natural'Image (Offset));
         end loop;
      end loop;
      Assert (Offset = Expected'Length, Label_Text & " drained length");
   end Drain_And_Assert;

   procedure Assert_Response (Expected : String; Label_Text : String) is
      Buffer : Byte_Array (1 .. 1024);
      Last   : Natural;
   begin
      Assert
        (Terminal.Core.Pending_Response_Length (T) = Expected'Length,
         Label_Text & " response length");
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert (Last = Expected'Length, Label_Text & " read length");
      for I in 1 .. Last loop
         Assert
           (Buffer (I) = Byte (Character'Pos (Expected (Expected'First + I - 1))),
            Label_Text & " byte" & Natural'Image (I));
      end loop;
   end Assert_Response;
begin
   Terminal.Core.Initialize (T, 2, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize");
   Terminal.Core.Set_Graphics_Stream_ID (T, 42);

   declare
      First  : constant String := "Gq=2,f=32,s=1,v=1,i=11;AAAAAA==";
      Second : constant String := "Gq=2,a=p,i=11,p=2";
   begin
      Feed_Text
        (ASCII.ESC & "_" & First & ASCII.ESC & "\"
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

      Drain_And_Assert (First, "first FIFO event");
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (T) = 1,
         "first event consumed");
      Drain_And_Assert (Second, "second FIFO event");
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (T) = 0
         and then Terminal.Core.Pending_Graphics_Byte_Count (T) = 0,
         "FIFO drained");
   end;

   declare
      Payload : constant String := "Gf=100,a=t,i=19;AAAA";
      Framed  : constant String :=
        ASCII.ESC & "_" & Payload & ASCII.ESC & "\";
   begin
      for Ch of Framed loop
         Feed_Text ((1 => Ch));
      end loop;
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (T) = 1,
         "arbitrary read boundaries");
      Drain_And_Assert (Payload, "byte-at-a-time event");
   end;

   Feed_Text (ASCII.ESC & "_Gf=100;AAAA" & ASCII.CAN & "x");
   Assert
     (Terminal.Core.Pending_Graphics_Event_Count (T) = 0,
      "CAN cancels APC command");
   declare
      Snapshot : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (Snapshot, 1, 1).Text.Code_Point =
           Character'Pos ('x'),
         "text resumes after cancelled APC");
      Terminal.Core.Release (Snapshot);
   end;

   declare
      Payload : constant String := "Ga=d,d=i,i=19";
      Event   : Terminal.Core.Graphics_Event;
   begin
      Feed_Text (ASCII.ESC & "_" & Payload & ASCII.ESC & "\");
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
   end;

   declare
      Event : Terminal.Core.Graphics_Event;
      Stale : Terminal.Core.Graphics_Event;
   begin
      Feed_Text
        (ASCII.ESC & "_Ga=p,i=77,p=3" & ASCII.ESC & "\");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Stale := Event;
      Stale.Sequence := Stale.Sequence + 1;
      Terminal.Core.Complete_Graphics_Event
        (T,
         Stale,
         (Code             => Terminal.Core.Kitty_OK,
          Image_ID         => 77,
          Image_Number     => 0,
          Has_Image_Number => False,
          Placement_ID     => 3,
          Has_Placement_ID => True,
          Quiet            => 0,
          others           => <>));
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (T) = 1,
         "stale completion must preserve FIFO head");
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         (Code             => Terminal.Core.Kitty_OK,
          Image_ID         => 77,
          Image_Number     => 0,
          Has_Image_Number => False,
          Placement_ID     => 3,
          Has_Placement_ID => True,
          Quiet            => 0,
          others           => <>));
      Assert_Response
        (ASCII.ESC & "_Gi=77,p=3;OK" & ASCII.ESC & "\",
         "committed placement response");

      Feed_Text
        (ASCII.ESC & "_Ga=p,I=88,q=1" & ASCII.ESC & "\");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         (Code             => Terminal.Core.Kitty_OK,
          Image_ID         => 123,
          Image_Number     => 88,
          Has_Image_Number => True,
          Placement_ID     => 0,
          Has_Placement_ID => False,
          Quiet            => 1,
          others           => <>));
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "q=1 completion suppresses OK response");

      Feed_Text
        (ASCII.ESC & "_Ga=p,i=99,q=2" & ASCII.ESC & "\");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         (Code             => Terminal.Core.Kitty_ENOENT,
          Image_ID         => 99,
          Image_Number     => 0,
          Has_Image_Number => False,
          Placement_ID     => 0,
          Has_Placement_ID => False,
          Quiet            => 2,
          others           => <>));
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "q=2 completion suppresses error response");

      Feed_Text
        (ASCII.ESC & "_Ga=p,i=99,q=2" & ASCII.ESC & "\");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         (Code             => Terminal.Core.Kitty_OK,
          Image_ID         => 99,
          Quiet            => 2,
          others           => <>));
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "q=2 completion suppresses success response");

      Feed_Text
        (ASCII.ESC & "_Gf=32,s=1,v=1,i=101,m=1;AAAA" & ASCII.ESC & "\"
         & ASCII.ESC & "_Gm=0,q=2;" & ASCII.ESC & "\");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert
        (Terminal.Core.Graphics_Event_Payload (T, Event) =
           "Gf=32,s=1,v=1,i=101,m=0,q=2;AAAA",
         "final chunk quiet mode is retained in the assembled command");
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         (Code     => Terminal.Core.Kitty_OK,
          Image_ID => 101,
          Quiet    => 2,
          others   => <>));
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "final chunk q=2 suppresses success response");

      Feed_Text
        (ASCII.ESC & "_Ga=t,f=32,s=1,v=1,i=102,q=0;AAAA"
         & ASCII.ESC & "\" & ASCII.ESC & "[c");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "later DA response waits for a transmitting command response");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         (Code     => Terminal.Core.Kitty_OK,
          Image_ID => 102,
          Quiet    => 0,
          others   => <>));
      Assert_Response
        (ASCII.ESC & "_Gi=102;OK" & ASCII.ESC & "\"
         & ASCII.ESC & "[?62;4;22c",
         "transmission response precedes later DA response");

      Feed_Text
        (ASCII.ESC & "_Ga=T,f=32,s=1,v=1;AAAA" & ASCII.ESC & "\");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         (Code      => Terminal.Core.Kitty_OK,
          Image_ID  => 0,
          Respond   => False,
          others    => <>));
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "anonymous transmission completion emits no response");

      Feed_Text
        (ASCII.ESC & "_Ga=p,i=101,p=4" & ASCII.ESC & "\");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         (Code             => Terminal.Core.Kitty_ECYCLE,
          Image_ID         => 101,
          Image_Number     => 0,
          Has_Image_Number => False,
          Placement_ID     => 4,
          Has_Placement_ID => True,
          Quiet            => 0,
          others           => <>));
      Assert_Response
        (ASCII.ESC
         & "_Gi=101,p=4;ECYCLE:Relative placement cycle"
         & ASCII.ESC & "\",
         "relative cycle completion response");
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
         (Code => Terminal.Core.Kitty_OK, Respond => False, others => <>));
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count (Stream_T) = 0,
         "enqueue-time stream event completes after stream change");
      Terminal.Core.Finalize (Stream_T);
   end;

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
         (Code              => Terminal.Core.Kitty_OK,
          Image_ID          => 77,
          Placement_ID      => 3,
          Has_Placement_ID  => True,
          Move_Cursor       => True,
          Placement_Columns => 2,
          Placement_Rows    => 1,
          others            => <>));
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
        (ASCII.ESC & "_Ga=p,i=88,p=4,c=2,r=1" & ASCII.ESC & "\" & "Y");
      Terminal.Core.Peek_Graphics_Event (Ordered_T, Event);
      Terminal.Core.Complete_Graphics_Event
        (Ordered_T,
         Event,
         (Code         => Terminal.Core.Kitty_ENOENT,
          Image_ID     => 88,
          Placement_ID => 4,
          others       => <>));
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
         (Code              => Terminal.Core.Kitty_OK,
          Image_ID          => 121,
          Move_Cursor       => True,
          Placement_Columns => 1,
          Placement_Rows    => 1,
          others            => <>));
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
   end;

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
   end;

   declare
      Prefix : constant String := "Gf=100,a=t,i=23;";
      Large  : String
        (1 .. Terminal.Core.Max_Graphics_Preview_Length + 37);
   begin
      Large (Prefix'Range) := Prefix;
      Large (Prefix'Last + 1 .. Large'Last) := (others => 'A');
      Feed_Text (ASCII.ESC & "_" & Large & ASCII.ESC & "\");
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
      Drain_And_Assert (Large, "large event");
   end;

   Feed_Text
     (ASCII.ESC & "_Gi=30,s=1,v=1,a=q,t=d,f=24;AAAA"
      & ASCII.ESC & "\");
   Assert
     (Terminal.Core.Pending_Graphics_Event_Count (T) = 1,
      "query must enter graphics event FIFO for backend validation");
   Complete_Kitty_Query (30, Terminal.Core.Kitty_ENOTSUP);
   Assert_Response
     (ASCII.ESC & "_Gi=30;ENOTSUP:Unsupported graphics operation"
      & ASCII.ESC & "\",
      "disabled direct query");
   Feed_Text (ASCII.ESC & "]1337;Capabilities" & ASCII.ESC & "\");
   Assert_Response
     (ASCII.ESC & "]1337;Capabilities=" & ASCII.ESC & "\",
      "disabled graphics feature report");

   Terminal.Core.Set_Graphics_Capabilities
     (T,
      (Kitty_Direct_RGB         => True,
       Kitty_Direct_RGBA        => True,
       Kitty_Indexed_RGB        => True,
       Kitty_Indexed_RGBA       => True,
       Kitty_Direct_PNG         => True,
       Kitty_Zlib_Compression   => True,
       Kitty_File_Transfer      => False,
       Kitty_Temporary_Transfer => False,
       Kitty_Shared_Memory      => False,
       Sixel                    => True,
       ITerm2_Inline_Images     => False,
       ITerm2_File_Downloads    => False));
   Feed_Text (ASCII.ESC & "]1337;Capabilities" & ASCII.ESC & "\");
   Assert_Response
     (ASCII.ESC & "]1337;Capabilities=Sx" & ASCII.ESC & "\",
      "truthful sixel feature report");
   Feed_Text
     (ASCII.ESC & "_Gi=31,p=7,s=1,v=1,a=q,t=d,f=24;AAAA"
      & ASCII.ESC & "\" & ASCII.ESC & "[c");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 0,
      "later DA response must wait for backend query validation");
   Complete_Kitty_Query
     (31, Terminal.Core.Kitty_OK, Placement_ID => 7);
   Assert_Response
     (ASCII.ESC & "_Gi=31,p=7;OK" & ASCII.ESC & "\"
      & ASCII.ESC & "[?62;4;22c",
      "direct query before later DA response");

   Feed_Text
     (ASCII.ESC & "_Gi=39,s=1,v=1,a=q,t=d,f=24,o=z;AAAA"
      & ASCII.ESC & "\"
      & ASCII.ESC & "_Gi=40,s=1,v=1,a=q,t=d,f=24,o=x;AAAA"
      & ASCII.ESC & "\");
   Complete_Kitty_Query (39, Terminal.Core.Kitty_OK);
   Complete_Kitty_Query (40, Terminal.Core.Kitty_ENOTSUP);
   Assert_Response
     (ASCII.ESC & "_Gi=39;OK" & ASCII.ESC & "\"
      & ASCII.ESC & "_Gi=40;ENOTSUP:Unsupported graphics operation"
      & ASCII.ESC & "\",
      "compression capability queries");

   Feed_Text
     (ASCII.ESC & "Ptmux;"
      & ASCII.ESC & ASCII.ESC
      & "_Gi=35,s=1,v=1,a=q,t=d,f=24;AAAA"
      & ASCII.ESC & ASCII.ESC & "\"
      & ASCII.ESC & "\");
   Complete_Kitty_Query (35, Terminal.Core.Kitty_OK);
   Assert_Response
     (ASCII.ESC & "_Gi=35;OK" & ASCII.ESC & "\",
      "tmux-passthrough direct query");
   Assert
     (Terminal.Core.Pending_Graphics_Event_Count (T) = 0,
      "tmux query should be consumed after backend validation");

   Feed_Text
     (ASCII.ESC & "_Gi=32,s=1,v=1,a=q,t=s,f=24,S=3;L2FiYw=="
      & ASCII.ESC & "\");
   Complete_Kitty_Query (32, Terminal.Core.Kitty_ENOTSUP);
   Assert_Response
     (ASCII.ESC & "_Gi=32;ENOTSUP:Unsupported graphics operation"
      & ASCII.ESC & "\",
      "shared-memory query");

   Feed_Text
     (ASCII.ESC & "_Gi=36,s=1,v=1,a=q,t=direct,f=24;AAAA"
      & ASCII.ESC & "\"
      & ASCII.ESC & "_Gi=37,p=bad,s=1,v=1,a=q,t=d,f=24;AAAA"
      & ASCII.ESC & "\"
      & ASCII.ESC & "_Gi=38,s=1,v=1,a=q,t=d,f=24,q=9;AAAA"
      & ASCII.ESC & "\");
   Complete_Kitty_Query (36, Terminal.Core.Kitty_EINVAL);
   Complete_Kitty_Query (37, Terminal.Core.Kitty_EINVAL);
   Complete_Kitty_Query (38, Terminal.Core.Kitty_EINVAL);
   Assert_Response
     (ASCII.ESC & "_Gi=36;EINVAL:Invalid control data" & ASCII.ESC & "\"
      & ASCII.ESC & "_Gi=37;EINVAL:Invalid control data" & ASCII.ESC & "\"
      & ASCII.ESC & "_Gi=38;EINVAL:Invalid control data" & ASCII.ESC & "\",
      "malformed query controls");
   Assert
     (Terminal.Core.Pending_Graphics_Event_Count (T) = 0,
      "malformed queries remain side-effect free");

   Feed_Text
     (ASCII.ESC & "_Gi=33,s=1,v=1,a=q,t=d,f=24,q=1;AAAA"
      & ASCII.ESC & "\"
      & ASCII.ESC & "_Gi=34,s=1,v=1,a=q,t=s,f=24,q=2;AAAA"
      & ASCII.ESC & "\");
   Complete_Kitty_Query (33, Terminal.Core.Kitty_OK, Quiet => 1);
   Complete_Kitty_Query (34, Terminal.Core.Kitty_ENOTSUP, Quiet => 2);
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 0,
      "query quiet modes suppress selected response class");
   Assert
     (Terminal.Core.Pending_Graphics_Event_Count (T) = 0,
      "quiet queries remain side-effect free");

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
   end;

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
   end;

   for I in 1 .. Terminal.Core.Max_Pending_Graphics_Events + 1 loop
      Feed_Text
        (ASCII.ESC & "_Gq=2,a=d,i=" & Integer'Image (I) & ASCII.ESC & "\");
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
end Core_Graphics_Stream_Smoke;

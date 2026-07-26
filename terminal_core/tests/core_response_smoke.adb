with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Response_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   Response_Capacity : constant Natural := Terminal.Core.Max_Title_Length + 16;

   T : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Assert_Bytes
     (Actual  : Byte_Array;
      Last    : Natural;
      Expect  : Byte_Array;
      Message : String)
   is
   begin
      Assert (Last = Expect'Length, Message & " length");
      for I in Expect'Range loop
         Assert
           (Actual (Actual'First + I - Expect'First) = Expect (I),
            Message & " byte" & Natural'Image (I - Expect'First + 1));
      end loop;
   end Assert_Bytes;
begin
   Terminal.Core.Initialize (T, 5, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "[1t"
            & ASCII.ESC & "[2t"
            & ASCII.ESC & "[3;10;20t"
            & ASCII.ESC & "[4;480;640t"
            & ASCII.ESC & "[8;24;80t"
            & ASCII.ESC & "[10t"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "XTWINOPS action no-op feed failed");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "XTWINOPS action no-ops should not queue responses");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before,
         "XTWINOPS action no-ops should be recognized");
   end;

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[5n"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "DSR status feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 4,
      "DSR status response length");

   declare
      Buffer : Byte_Array (1 .. 8);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes (Buffer, Last, To_Bytes (ASCII.ESC & "[0n"), "DSR status");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "DSR status should drain");
   end;

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[?5n"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "DEC DSR status feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 5,
      "DEC DSR status response length");

   declare
      Buffer : Byte_Array (1 .. 8);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "[?0n"),
         "DEC DSR status");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "DEC DSR status should drain");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "[5n"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "non-1 response buffer feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 4,
      "non-1 response buffer response length");

   declare
      Buffer : Byte_Array (10 .. 13);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert (Last = 4, "non-1 response buffer drain length");
      Assert
        (Buffer (10) = Byte (Character'Pos (ASCII.ESC))
         and then Buffer (11) = Byte (Character'Pos ('['))
         and then Buffer (12) = Byte (Character'Pos ('0'))
         and then Buffer (13) = Byte (Character'Pos ('n')),
         "non-1 response buffer contents");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "non-1 response buffer should drain");
   end;

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "[5;0n"
            & ASCII.ESC & "[6;0n"
            & ASCII.ESC & "[?15;0n"),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "malformed DSR feed failed");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "malformed DSR should not queue responses");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before + 3,
         "malformed DSR should be diagnosed");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "P$q" & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "empty DECRQSS feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 7,
      "empty DECRQSS response length");

   declare
      Buffer : Byte_Array (1 .. 8);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "P0$r" & ASCII.ESC & "\"),
         "empty DECRQSS");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "empty DECRQSS should drain");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[?15n"
         & ASCII.ESC & "[?25n"
         & ASCII.ESC & "[?26n"
         & ASCII.ESC & "[?53n"
         & ASCII.ESC & "[?55n"
         & ASCII.ESC & "[?56n"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "DEC DSR probes feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 44,
      "DEC DSR probes response length");

   declare
      Buffer : Byte_Array (1 .. 48);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes
           (ASCII.ESC & "[?11n"
            & ASCII.ESC & "[?20n"
            & ASCII.ESC & "[?27;1;0;0n"
            & ASCII.ESC & "[?50n"
            & ASCII.ESC & "[?50n"
            & ASCII.ESC & "[?57;0n"),
         "DEC DSR probes");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "DEC DSR probes should drain");
   end;

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "[i"
            & ASCII.ESC & "[4i"
            & ASCII.ESC & "[5i"
            & ASCII.ESC & "[?1i"
            & ASCII.ESC & "[?4i"
            & ASCII.ESC & "[?5i"
            & ASCII.ESC & "[?10i"
            & ASCII.ESC & "[?11i"
            & ASCII.ESC & "[0;4;5i"
            & ASCII.ESC & "[?1;4;5;10;11i"),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "media-copy no-op feed failed");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "media-copy no-ops should not queue responses");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before,
         "media-copy no-ops should be recognized");

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "[9;4i"
            & ASCII.ESC & "[?1;99;11i"),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "unknown media-copy feed failed");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before + 2,
         "unknown media-copy should be diagnosed");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "[3;4H" & ASCII.ESC & "[6n"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "CPR feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 6,
      "CPR response length");

   declare
      First  : Byte_Array (1 .. 3);
      Second : Byte_Array (1 .. 8);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, First, Last);
      Assert_Bytes (First, Last, To_Bytes (ASCII.ESC & "[3"), "CPR first drain");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 3,
         "CPR partial response length");

      Terminal.Core.Read_Response (T, Second, Last);
      Assert_Bytes (Second, Last, To_Bytes (";4R"), "CPR second drain");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "CPR should drain");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "[2;7H" & ASCII.ESC & "[?6n"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "DEC CPR feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 7,
      "DEC CPR response length");

   declare
      Buffer : Byte_Array (1 .. 8);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "[?2;7R"),
         "DEC CPR");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "DEC CPR should drain");
   end;

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[c"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "primary DA feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 11,
      "primary DA response length");

   declare
      Buffer : Byte_Array (1 .. 16);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "[?62;4;22c"),
         "primary DA");
   end;

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "[0;1c"
            & ASCII.ESC & "[>0;1c"),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "malformed DA feed failed");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "malformed DA should not queue responses");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before + 2,
         "malformed DA should be diagnosed");
   end;

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "Z"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "DECID feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 11,
      "DECID response length");

   declare
      Buffer : Byte_Array (1 .. 16);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "[?62;4;22c"),
         "DECID");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "DECID should drain");
   end;

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[>c"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "secondary DA feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 9,
      "secondary DA response length");

   declare
      Buffer : Byte_Array (1 .. 16);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "[>0;1;0c"),
         "secondary DA");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "secondary DA should drain");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "[>" & ASCII.ESC & "c" & ASCII.ESC & "[c"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "RIS parser reset feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 11,
      "RIS should clear pending CSI private marker before primary DA");

   declare
      Buffer : Byte_Array (1 .. 16);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "[?62;4;22c"),
         "primary DA after RIS parser reset");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "primary DA after RIS parser reset should drain");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[?2004h"
         & ASCII.ESC & "[?66h"
         & ASCII.ESC & "[?67h"
         & ASCII.ESC & "[?1049h"
         & ASCII.ESC & "[?2026h"
         & ASCII.ESC & "[?12h"
         & ASCII.ESC & "[?25l"
         & ASCII.ESC & "[?7$p"
         & ASCII.ESC & "[?12$p"
         & ASCII.ESC & "[?25$p"
         & ASCII.ESC & "[?66$p"
         & ASCII.ESC & "[?67$p"
         & ASCII.ESC & "[?2004$p"
         & ASCII.ESC & "[?2026$p"
         & ASCII.ESC & "[?1000$p"
         & ASCII.ESC & "[?1048$p"
         & ASCII.ESC & "[?1049$p"
         & ASCII.ESC & "[?9999$p"
         & ASCII.ESC & "[2h"
         & ASCII.ESC & "[2$p"
         & ASCII.ESC & "[4$p"
         & ASCII.ESC & "[20$p"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "DECRQM feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 132,
      "DECRQM response length");

   declare
      Buffer : Byte_Array (1 .. 144);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes
            (ASCII.ESC & "[?7;1$y"
            & ASCII.ESC & "[?12;1$y"
            & ASCII.ESC & "[?25;2$y"
            & ASCII.ESC & "[?66;1$y"
            & ASCII.ESC & "[?67;1$y"
            & ASCII.ESC & "[?2004;1$y"
            & ASCII.ESC & "[?2026;1$y"
            & ASCII.ESC & "[?1000;2$y"
            & ASCII.ESC & "[?1048;2$y"
            & ASCII.ESC & "[?1049;1$y"
            & ASCII.ESC & "[?9999;0$y"
            & ASCII.ESC & "[2;1$y"
            & ASCII.ESC & "[4;2$y"
            & ASCII.ESC & "[20;2$y"),
         "DECRQM");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "DECRQM should drain");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[?7$p"
         & ASCII.ESC & "[?25$p"
         & ASCII.ESC & "[2$p"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "partial DECRQM feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 24,
      "partial DECRQM response length");

   declare
      First  : Byte_Array (1 .. 10);
      Second : Byte_Array (1 .. 24);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, First, Last);
      Assert_Bytes
        (First,
         Last,
         To_Bytes (ASCII.ESC & "[?7;1$y" & ASCII.ESC & "["),
         "partial DECRQM first drain");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 14,
         "partial DECRQM remaining length");

      Terminal.Core.Read_Response (T, Second, Last);
      Assert_Bytes
        (Second,
         Last,
         To_Bytes ("?25;2$y" & ASCII.ESC & "[2;1$y"),
         "partial DECRQM second drain");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "partial DECRQM should drain");
   end;

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "[$p"
            & ASCII.ESC & "[4;20$p"
            & ASCII.ESC & "[>4$p"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "malformed DECRQM feed failed");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "malformed DECRQM should not queue responses");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before + 3,
         "malformed DECRQM should be diagnosed");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[1;3;31;48;5;200m"
         & ASCII.ESC & "P$qm" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "DECRQSS SGR feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 23,
      "DECRQSS SGR response length");

   declare
      Buffer : Byte_Array (1 .. 32);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes
           (ASCII.ESC & "P1$r1;3;31;48;5;200m" & ASCII.ESC & "\"),
         "DECRQSS SGR");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "DECRQSS SGR should drain");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[0;4:3;58;5;42m"
         & ASCII.ESC & "P$qm" & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "DECRQSS underline SGR feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 19,
      "DECRQSS underline SGR response length");

   declare
      Buffer : Byte_Array (1 .. 24);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "P1$r4:3;58;5;42m" & ASCII.ESC & "\"),
         "DECRQSS underline SGR");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "DECRQSS underline SGR should drain");
   end;

   Terminal.Core.Feed
     (T,
      (1 => 16#1B#,
       2 => Byte (Character'Pos ('[')),
       3 => Byte (Character'Pos ('0')),
       4 => Byte (Character'Pos ('m')),
       5 => 16#90#,
       6 => Byte (Character'Pos ('$')),
       7 => Byte (Character'Pos ('q')),
       8 => Byte (Character'Pos ('m')),
       9 => 16#9C#),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "C1 DECRQSS SGR feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 9,
      "C1 DECRQSS SGR response length");

   declare
      Buffer : Byte_Array (1 .. 16);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "P1$r0m" & ASCII.ESC & "\"),
         "C1 DECRQSS SGR");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "C1 DECRQSS SGR should drain");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[2;4r"
         & ASCII.ESC & "P$qr" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "DECRQSS margins feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 11,
      "DECRQSS margins response length");

   declare
      Buffer : Byte_Array (1 .. 16);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "P1$r2;4r" & ASCII.ESC & "\"),
         "DECRQSS margins");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "DECRQSS margins should drain");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[1;5r"
         & ASCII.ESC & "P$qr" & ASCII.BEL),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "BEL DECRQSS margins feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 11,
      "BEL DECRQSS margins response length");

   declare
      Buffer : Byte_Array (1 .. 16);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "P1$r1;5r" & ASCII.ESC & "\"),
         "BEL DECRQSS margins");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "BEL DECRQSS margins should drain");
   end;

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "P$qx" & ASCII.ESC & "\"),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "DECRQSS invalid feed failed");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 7,
         "DECRQSS invalid response length");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before,
         "DECRQSS invalid query should return a negative response");

      declare
         Buffer : Byte_Array (1 .. 8);
         Last   : Natural;
      begin
         Terminal.Core.Read_Response (T, Buffer, Last);
         Assert_Bytes
           (Buffer,
            Last,
            To_Bytes (ASCII.ESC & "P0$r" & ASCII.ESC & "\"),
            "DECRQSS invalid");
         Assert
           (Terminal.Core.Pending_Response_Length (T) = 0,
            "DECRQSS invalid should drain");
      end;
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "P$qmextra" & ASCII.ESC & "\"
         & ASCII.ESC & "P$qr0" & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "malformed DECRQSS feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 14,
      "malformed DECRQSS response length");

   declare
      Buffer : Byte_Array (1 .. 16);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes
           (ASCII.ESC & "P0$r" & ASCII.ESC & "\"
            & ASCII.ESC & "P0$r" & ASCII.ESC & "\"),
         "malformed DECRQSS");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "malformed DECRQSS should drain");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[5 q"
         & ASCII.ESC & "P$q q" & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "DECRQSS cursor style feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 10,
      "DECRQSS cursor style response length");

   declare
      Buffer : Byte_Array (1 .. 16);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "P1$r5 q" & ASCII.ESC & "\"),
         "DECRQSS cursor style");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "DECRQSS cursor style should drain");
   end;

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[18t"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "XTWINOPS text area feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 9,
      "XTWINOPS text area response length");

   declare
      Buffer : Byte_Array (1 .. 16);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "[8;5;10t"),
         "XTWINOPS text area");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "XTWINOPS text area should drain");
   end;

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[19t"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "XTWINOPS screen area feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 9,
      "XTWINOPS screen area response length");

   declare
      Buffer : Byte_Array (1 .. 16);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "[9;5;10t"),
         "XTWINOPS screen area");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "XTWINOPS screen area should drain");
   end;

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[11t"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "XTWINOPS window state feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 4,
      "XTWINOPS window state response length");

   declare
      Buffer : Byte_Array (1 .. 16);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "[1t"),
         "XTWINOPS window state");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "XTWINOPS window state should drain");
   end;

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[13t"), Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "XTWINOPS window position feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 8,
      "XTWINOPS window position response length");

   declare
      Buffer : Byte_Array (1 .. 16);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "[3;0;0t"),
         "XTWINOPS window position");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "XTWINOPS window position should drain");
   end;

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "[14t" & ASCII.ESC & "[15t" & ASCII.ESC & "[16t"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "XTWINOPS unknown pixel metrics feed failed");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before,
         "XTWINOPS unknown pixel metrics should be recognized");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 24,
         "XTWINOPS unknown pixel metrics response length");

      declare
         Buffer : Byte_Array (1 .. 32);
         Last   : Natural;
      begin
         Terminal.Core.Read_Response (T, Buffer, Last);
         Assert_Bytes
           (Buffer,
            Last,
            To_Bytes
              (ASCII.ESC & "[4;0;0t"
               & ASCII.ESC & "[5;0;0t"
               & ASCII.ESC & "[6;0;0t"),
            "XTWINOPS unknown pixel metrics");
         Assert
           (Terminal.Core.Pending_Response_Length (T) = 0,
            "XTWINOPS unknown pixel metrics should drain");
      end;
   end;

   Terminal.Core.Set_Cell_Pixel_Size (T, Width => 8, Height => 15);
   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[16t"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "XTWINOPS cell size feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 9,
      "XTWINOPS cell size response length");

   declare
      Buffer : Byte_Array (1 .. 16);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "[6;15;8t"),
         "XTWINOPS cell size");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "XTWINOPS cell size should drain");
   end;

   Terminal.Core.Set_Window_Pixel_Size (T, Width => 640, Height => 480);
   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[14t"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "XTWINOPS window size feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 12,
      "XTWINOPS window size response length");

   declare
      Buffer : Byte_Array (1 .. 16);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "[4;480;640t"),
         "XTWINOPS window size");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "XTWINOPS window size should drain");
   end;

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[15t"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "XTWINOPS screen size feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 12,
      "XTWINOPS screen size response length");

   declare
      Buffer : Byte_Array (1 .. 16);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "[5;480;640t"),
         "XTWINOPS screen size");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "XTWINOPS screen size should drain");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]2;Ada Terminal" & ASCII.BEL
         & ASCII.ESC & "[20t"
         & ASCII.ESC & "[21t"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "XTWINOPS title feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 34,
      "XTWINOPS title response length");

   declare
      Buffer : Byte_Array (1 .. 40);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes
           (ASCII.ESC & "]LAda Terminal" & ASCII.ESC & "\"
            & ASCII.ESC & "]lAda Terminal" & ASCII.ESC & "\"),
         "XTWINOPS title");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "XTWINOPS title should drain");
   end;

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "]2;saved" & ASCII.BEL
            & ASCII.ESC & "[22t"
            & ASCII.ESC & "]2;temporary" & ASCII.BEL
            & ASCII.ESC & "[23t"
            & ASCII.ESC & "[21t"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "XTWINOPS title stack feed failed");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before,
         "XTWINOPS title stack should be recognized");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 10,
         "XTWINOPS restored title response length");

      declare
         Buffer : Byte_Array (1 .. 16);
         Last   : Natural;
      begin
         Terminal.Core.Read_Response (T, Buffer, Last);
         Assert_Bytes
           (Buffer,
            Last,
            To_Bytes (ASCII.ESC & "]lsaved" & ASCII.ESC & "\"),
            "XTWINOPS restored title");
         Assert
           (Terminal.Core.Pending_Response_Length (T) = 0,
            "XTWINOPS restored title should drain");
      end;
   end;

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "]2;param" & ASCII.BEL
            & ASCII.ESC & "[22;0t"
            & ASCII.ESC & "]2;temporary" & ASCII.BEL
            & ASCII.ESC & "[23;0t"
            & ASCII.ESC & "[22;1t"
            & ASCII.ESC & "[23;1t"
            & ASCII.ESC & "[22;2t"
            & ASCII.ESC & "[23;2t"
            & ASCII.ESC & "[21t"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "XTWINOPS parameterized title stack feed failed");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before,
         "XTWINOPS parameterized title stack should be recognized");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 10,
         "XTWINOPS parameterized restored title response length");

      declare
         Buffer : Byte_Array (1 .. 16);
         Last   : Natural;
      begin
         Terminal.Core.Read_Response (T, Buffer, Last);
         Assert_Bytes
           (Buffer,
            Last,
            To_Bytes (ASCII.ESC & "]lparam" & ASCII.ESC & "\"),
            "XTWINOPS parameterized restored title");
         Assert
           (Terminal.Core.Pending_Response_Length (T) = 0,
            "XTWINOPS parameterized restored title should drain");
      end;
   end;

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Terminal.Core.Feed
        (T, To_Bytes (ASCII.ESC & "[22;3t" & ASCII.ESC & "[23;3t"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "XTWINOPS unsupported title stack target feed failed");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before + 2,
         "XTWINOPS unsupported title stack targets should be diagnosed");
   end;

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "[11;0t"
            & ASCII.ESC & "[13;0t"
            & ASCII.ESC & "[14;0t"
            & ASCII.ESC & "[15;0t"
            & ASCII.ESC & "[16;0t"
            & ASCII.ESC & "[18;0t"
            & ASCII.ESC & "[19;0t"
            & ASCII.ESC & "[20;0t"
            & ASCII.ESC & "[21;0t"
            & ASCII.ESC & "[22;0;0t"
            & ASCII.ESC & "[23;0;0t"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "malformed XTWINOPS reports feed failed");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "malformed XTWINOPS reports should not queue responses");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before + 11,
         "malformed XTWINOPS reports should be diagnosed");
   end;

   Terminal.Core.Initialize (T, 5, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "response overflow initialize failed");

   declare
      Fixture : Byte_Array (1 .. 400);
      Index   : Positive := Fixture'First;
      Before  : constant Natural :=
        Terminal.Core.Diagnostics (T).Parser_Overflow;
   begin
      for N in 1 .. 100 loop
         Fixture (Index) := Byte (Character'Pos (ASCII.ESC));
         Index := Index + 1;
         Fixture (Index) := Byte (Character'Pos ('['));
         Index := Index + 1;
         Fixture (Index) := Byte (Character'Pos ('5'));
         Index := Index + 1;
         Fixture (Index) := Byte (Character'Pos ('n'));
         Index := Index + 1;
      end loop;

      Terminal.Core.Feed (T, Fixture, Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "response overflow feed failed");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = Response_Capacity,
         "response queue should cap at bounded capacity");
      Assert
        (Terminal.Core.Diagnostics (T).Parser_Overflow =
           Before + Fixture'Length - Response_Capacity,
         "response queue overflow should be diagnosed per dropped byte");

      declare
         Buffer : Byte_Array (1 .. Response_Capacity);
         Last   : Natural;
      begin
         Terminal.Core.Read_Response (T, Buffer, Last);
         Assert (Last = Response_Capacity, "response overflow drain length");
         for Offset in 0 .. Response_Capacity / 4 - 1 loop
            Assert
              (Buffer (Offset * 4 + 1) = Byte (Character'Pos (ASCII.ESC)),
               "response overflow preserved ESC" & Natural'Image (Offset));
            Assert
              (Buffer (Offset * 4 + 2) = Byte (Character'Pos ('[')),
               "response overflow preserved CSI" & Natural'Image (Offset));
            Assert
              (Buffer (Offset * 4 + 3) = Byte (Character'Pos ('0')),
               "response overflow preserved status" & Natural'Image (Offset));
            Assert
              (Buffer (Offset * 4 + 4) = Byte (Character'Pos ('n')),
               "response overflow preserved final" & Natural'Image (Offset));
         end loop;
         Assert
           (Terminal.Core.Pending_Response_Length (T) = 0,
            "response overflow drain should empty queue");
      end;
   end;
end Core_Response_Smoke;

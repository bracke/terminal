separate (Core_Response_Smoke)
procedure Run_Mode_And_Status_String_Cases is
begin
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
end Run_Mode_And_Status_String_Cases;

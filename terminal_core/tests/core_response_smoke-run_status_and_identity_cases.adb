separate (Core_Response_Smoke)
procedure Run_Status_And_Identity_Cases is
begin
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
end Run_Status_And_Identity_Cases;

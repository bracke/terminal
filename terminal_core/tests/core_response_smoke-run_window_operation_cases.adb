separate (Core_Response_Smoke)
procedure Run_Window_Operation_Cases is
begin
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
end Run_Window_Operation_Cases;

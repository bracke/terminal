with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Response_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

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
      To_Bytes
        (ASCII.ESC & "[?2004h"
         & ASCII.ESC & "[?2026h"
         & ASCII.ESC & "[?12h"
         & ASCII.ESC & "[?12$p"
         & ASCII.ESC & "[?2004$p"
         & ASCII.ESC & "[?2026$p"
         & ASCII.ESC & "[?1000$p"
         & ASCII.ESC & "[?9999$p"
         & ASCII.ESC & "[4$p"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "DECRQM feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 60,
      "DECRQM response length");

   declare
      Buffer : Byte_Array (1 .. 64);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes
           (ASCII.ESC & "[?12;1$y"
            & ASCII.ESC & "[?2004;1$y"
            & ASCII.ESC & "[?2026;1$y"
            & ASCII.ESC & "[?1000;2$y"
            & ASCII.ESC & "[?9999;0$y"
            & ASCII.ESC & "[4;2$y"),
         "DECRQM");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "DECRQM should drain");
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

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]2;Ada Terminal" & ASCII.BEL
         & ASCII.ESC & "[21t"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "XTWINOPS title feed failed");
   Assert
     (Terminal.Core.Pending_Response_Length (T) = 17,
      "XTWINOPS title response length");

   declare
      Buffer : Byte_Array (1 .. 32);
      Last   : Natural;
   begin
      Terminal.Core.Read_Response (T, Buffer, Last);
      Assert_Bytes
        (Buffer,
         Last,
         To_Bytes (ASCII.ESC & "]lAda Terminal" & ASCII.ESC & "\"),
         "XTWINOPS title");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "XTWINOPS title should drain");
   end;
end Core_Response_Smoke;

separate (Core_Response_Smoke)
procedure Run_Overflow_Cases is
begin
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
           Before + 100 - Response_Capacity / 4,
         "response queue overflow should be diagnosed per dropped response");

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

   Terminal.Core.Initialize (T, 5, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "atomic response overflow initialize failed");
   declare
      Fixture : Byte_Array (1 .. 67 * 4);
      Index   : Positive := Fixture'First;
      Before  : constant Natural :=
        Terminal.Core.Diagnostics (T).Parser_Overflow;
   begin
      for N in 1 .. 67 loop
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
      Assert (Feed_Status = Terminal.Core.Ok, "atomic response fill feed failed");
      Terminal.Core.Feed
        (T, To_Bytes (ASCII.ESC & "[6n"), Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "atomic response reject feed failed");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 67 * 4,
         "overflow must reject the complete response");
      Assert
        (Terminal.Core.Diagnostics (T).Parser_Overflow = Before + 1,
         "atomic response overflow diagnosed once");
      declare
         Buffer : Byte_Array (1 .. Response_Capacity);
         Last   : Natural;
      begin
         Terminal.Core.Read_Response (T, Buffer, Last);
         Assert (Last = 67 * 4, "atomic response drain length");
         Assert
           (Buffer (Last - 3 .. Last) = To_Bytes (ASCII.ESC & "[0n"),
            "atomic response queue ends at a frame boundary");
      end;
   end;
end Run_Overflow_Cases;

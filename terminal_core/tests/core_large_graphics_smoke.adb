with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Large_Graphics_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Ignored_Graphics_Protocol;
   use type Terminal.Core.Initialize_Status;

   T      : Terminal.Core.Terminal;
   Init   : Terminal.Core.Initialize_Status;
   Status : Terminal.Core.Feed_Status;

   Large_Length : constant Natural :=
     Terminal.Core.Max_Graphics_Preview_Length + 257;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Feed (Text : String) is
   begin
      Terminal.Core.Feed (T, To_Bytes (Text), Status);
      Assert (Status = Terminal.Core.Ok, "large graphics feed");
   end Feed;

   procedure Feed_Repeated (Ch : Character; Count : Natural) is
      Remaining : Natural := Count;
   begin
      while Remaining >= 4_096 loop
         Feed ((1 .. 4_096 => Ch));
         Remaining := Remaining - 4_096;
      end loop;
      if Remaining > 0 then
         Feed ((1 .. Remaining => Ch));
      end if;
   end Feed_Repeated;

   procedure Drain_And_Check
     (Protocol : Terminal.Core.Ignored_Graphics_Protocol;
      Prefix   : String;
      Fill     : Character;
      Length   : Natural;
      Label_Text : String)
   is
      Buffer : Byte_Array (1 .. 4_096);
      Event  : Terminal.Core.Graphics_Event;
      Last   : Natural;
      Done   : Boolean := False;
      Offset : Natural := 0;
   begin
      while not Done loop
         Terminal.Core.Read_Graphics_Event
           (T, Event, Buffer, Last, Done);
         Assert
           (Event.Pending and then Event.Protocol = Protocol,
            Label_Text & " protocol");
         Assert (Event.Payload_Length = Length, Label_Text & " length");
         for I in 1 .. Last loop
            Offset := Offset + 1;
            if Offset <= Prefix'Length then
               Assert
                 (Buffer (I) =
                    Byte (Character'Pos (Prefix (Prefix'First + Offset - 1))),
                  Label_Text & " prefix");
            else
               Assert
                 (Buffer (I) = Byte (Character'Pos (Fill)),
                  Label_Text & " body");
            end if;
         end loop;
      end loop;
      Assert (Offset = Length, Label_Text & " drained");
   end Drain_And_Check;
begin
   Terminal.Core.Initialize (T, 2, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize");
   Terminal.Core.Set_Graphics_Stream_ID (T, 9_001);

   --  Sixel DCS payloads use the full streaming transaction store, while the
   --  public event preview remains bounded.
   Feed (ASCII.ESC & "Pq");
   Feed_Repeated ('?', Large_Length);
   Feed (ASCII.ESC & "\");
   declare
      Event : Terminal.Core.Graphics_Event;
   begin
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert
        (Event.Pending
         and then Event.Protocol = Terminal.Core.Sixel_Graphics
         and then Event.Payload_Length = Large_Length + 1
         and then Event.Preview_Length =
           Terminal.Core.Max_Graphics_Preview_Length,
         "large Sixel is retained beyond preview");
   end;
   Drain_And_Check
     (Terminal.Core.Sixel_Graphics,
      "q",
      '?',
      Large_Length + 1,
      "large Sixel");

   --  tmux passthrough must not truncate an inner graphics command at the
   --  legacy DCS preview boundary.
   declare
      Prefix : constant String := "Gf=100,a=t,i=77;";
   begin
      Feed (ASCII.ESC & "Ptmux;" & ASCII.ESC & ASCII.ESC & "_");
      Feed (Prefix);
      Feed_Repeated ('A', Large_Length);
      Feed (ASCII.ESC & ASCII.ESC & "\" & ASCII.ESC & "\");
      Drain_And_Check
        (Terminal.Core.Kitty_Graphics,
         Prefix,
         'A',
         Prefix'Length + Large_Length,
         "large tmux Kitty");
   end;

   Terminal.Core.Finalize (T);
end Core_Large_Graphics_Smoke;

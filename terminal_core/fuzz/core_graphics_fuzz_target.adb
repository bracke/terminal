with Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;

with Terminal.Common;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Graphics_Fuzz_Target is
   use type Ada.Streams.Stream_Element_Offset;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   Maximum_Input_Length : constant := 1_048_576;

   package SIO renames Ada.Streams.Stream_IO;
   package Bytes renames Terminal.Common.Bytes;

   T           : Terminal.Core.Terminal;
   Init_Status : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
   Saw_Graphics_Event : Boolean := False;

   procedure Check_Feed is
   begin
      if Feed_Status = Terminal.Core.Invalid_State then
         raise Program_Error with "graphics parser entered Invalid_State";
      end if;
   end Check_Feed;

   procedure Feed_String (Value : String) is
      Data : Bytes.Byte_Array (1 .. Value'Length);
   begin
      for I in Value'Range loop
         Data (I - Value'First + 1) :=
           Bytes.Byte (Character'Pos (Value (I)));
      end loop;
      Terminal.Core.Feed (T, Data, Feed_Status);
      Check_Feed;
   end Feed_String;

   procedure Drain is
      Response : Bytes.Byte_Array (1 .. 4_096);
      Last     : Natural;
   begin
      if Terminal.Core.Pending_Graphics_Event_Count (T) > 0 then
         Saw_Graphics_Event := True;
      end if;
      while Terminal.Core.Pending_Graphics_Event_Count (T) > 0 loop
         Terminal.Core.Discard_Graphics_Event (T);
      end loop;
      while Terminal.Core.Pending_Response_Length (T) > 0 loop
         Terminal.Core.Read_Response (T, Response, Last);
         exit when Last = 0;
      end loop;
      declare
         View : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.Core.Release (View);
      end;
   end Drain;

begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   declare
      Input_File : SIO.File_Type;
   begin
      SIO.Open (Input_File, SIO.In_File, Ada.Command_Line.Argument (1));
      declare
         Available : constant Ada.Streams.Stream_Element_Offset :=
           Ada.Streams.Stream_Element_Offset'Min
             (Ada.Streams.Stream_Element_Offset (SIO.Size (Input_File)),
              Ada.Streams.Stream_Element_Offset (Maximum_Input_Length));
         Raw : Ada.Streams.Stream_Element_Array (1 .. Available);
         Last : Ada.Streams.Stream_Element_Offset;
      begin
         if Available > 0 then
            SIO.Read (Input_File, Raw, Last);
         else
            Last := 0;
         end if;
         SIO.Close (Input_File);

         Terminal.Core.Initialize (T, 24, 80, 256, Init_Status);
         if Init_Status /= Terminal.Core.Ok then
            raise Program_Error with "graphics fuzz initialization failed";
         end if;
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
             ITerm2_Inline_Images     => True,
             ITerm2_File_Downloads    => False));
         Terminal.Core.Set_Graphics_Resource_Limits
           (T,
            (Transaction_Length   => 256 * 1_024,
             Pending_Events       => 64,
             Pending_Bytes        => 512 * 1_024,
             Deferred_Input_Bytes => 512 * 1_024,
             Pixel_Dimension      => 4_096));

         if Last > 0 then
            declare
               Mode : constant Character :=
                 Character'Val (Raw (Raw'First));
               Fragmented : constant Boolean :=
                 Mode in 'k' | 's' | 'i' | 't' | 'r';

               procedure Feed_Payload is
               begin
                  if Last <= Raw'First then
                     return;
                  elsif Fragmented then
                     for I in Raw'First + 1 .. Last loop
                        Terminal.Core.Feed
                          (T,
                           (1 => Bytes.Byte (Raw (I))),
                           Feed_Status);
                        Check_Feed;
                     end loop;
                  else
                     declare
                        Data : Bytes.Byte_Array
                          (1 .. Natural (Last - Raw'First));
                     begin
                        for I in Raw'First + 1 .. Last loop
                           Data (Natural (I - Raw'First)) :=
                             Bytes.Byte (Raw (I));
                        end loop;
                        Terminal.Core.Feed (T, Data, Feed_Status);
                        Check_Feed;
                     end;
                  end if;
               end Feed_Payload;
            begin
               case Mode is
                  when 'K' | 'k' =>
                     Feed_String (ASCII.ESC & "_G");
                     Feed_Payload;
                     Feed_String (ASCII.ESC & "\");
                  when 'S' | 's' =>
                     Feed_String (ASCII.ESC & "Pq");
                     Feed_Payload;
                     Feed_String (ASCII.ESC & "\");
                  when 'I' | 'i' =>
                     Feed_String (ASCII.ESC & "]1337;File=");
                     Feed_Payload;
                     Feed_String (ASCII.BEL & "");
                  when 'T' | 't' =>
                     --  tmux DCS passthrough doubles the nested escape.
                     Feed_String (ASCII.ESC & "Ptmux;" & ASCII.ESC
                                  & ASCII.ESC & "_G");
                     Feed_Payload;
                     Feed_String (ASCII.ESC & ASCII.ESC & "\" & ASCII.ESC & "\");
                  when others =>
                     --  Raw mode includes its selector byte so framing and
                     --  cancellation controls remain fully fuzzable.
                     declare
                        Data : Bytes.Byte_Array (1 .. Natural (Last));
                     begin
                        for I in Raw'First .. Last loop
                           Data (Natural (I)) := Bytes.Byte (Raw (I));
                        end loop;
                        Terminal.Core.Feed (T, Data, Feed_Status);
                        Check_Feed;
                     end;
               end case;
            end;
         end if;

         Drain;
         if Ada.Environment_Variables.Exists
           ("TERMINAL_REQUIRE_GRAPHICS_EVENT")
           and then not Saw_Graphics_Event
         then
            raise Program_Error with
              "input produced no recognized graphics event";
         end if;
         --  Recovery after arbitrary input is part of the invariant checked
         --  by every testcase, not merely a seed-corpus smoke assertion.
         Feed_String ("OK");
         Drain;
         Terminal.Core.Finalize (T);
      end;
   end;
end Core_Graphics_Fuzz_Target;

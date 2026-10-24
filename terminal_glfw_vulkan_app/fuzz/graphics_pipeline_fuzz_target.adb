with Ada.Command_Line;
with Ada.Streams;
with Ada.Streams.Stream_IO;

with Terminal.App.Renderer;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Graphics_Pipeline_Fuzz_Target is
   use type Ada.Streams.Stream_Element_Offset;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   package SIO renames Ada.Streams.Stream_IO;
   package Bytes renames Terminal.Common.Bytes;

   Maximum_Input_Length : constant := 1_048_576;
   T : Terminal.Core.Terminal;
   R : Terminal.App.Renderer.Renderer;
   Core_Status : Terminal.Core.Initialize_Status;
   Renderer_Status : Terminal.App.Renderer.Init_Status;
   Feed_Status : Terminal.Core.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status;

   procedure Drain is
      Response : Bytes.Byte_Array (1 .. 4_096);
      Last : Natural;
   begin
      while Terminal.Core.Pending_Graphics_Event_Count (T) > 0 loop
         declare
            Event : Terminal.Core.Graphics_Event;
            Result : Terminal.Core.Kitty_Graphics_Result;
            Snapshot : Terminal.Core.Render_Snapshot;
         begin
            Terminal.Core.Peek_Graphics_Event (T, Event);
            Snapshot := Terminal.Core.Snapshot (T);
            Snapshot.Graphics := Event;
            Terminal.App.Renderer.Render (R, Snapshot, Render_Status);
            Terminal.Core.Release (Snapshot);
            if Render_Status /= Terminal.App.Renderer.Ok then
               raise Program_Error with "graphics renderer entered failure state";
            end if;
            Result := Terminal.App.Renderer.Graphics_Result (R, Event);
            Terminal.Core.Complete_Graphics_Event (T, Event, Result);
            Terminal.App.Renderer.Commit_Graphics_Events (R);
         end;
      end loop;
      while Terminal.Core.Pending_Response_Length (T) > 0 loop
         Terminal.Core.Read_Response (T, Response, Last);
         exit when Last = 0;
      end loop;
   end Drain;

   procedure Feed_String (Value : String; Fragmented : Boolean) is
      Data : Bytes.Byte_Array (1 .. Value'Length);
   begin
      for I in Value'Range loop
         Data (I - Value'First + 1) :=
           Bytes.Byte (Character'Pos (Value (I)));
      end loop;
      if Fragmented then
         for I in Data'Range loop
            Terminal.Core.Feed (T, [1 => Data (I)], Feed_Status);
            if Feed_Status = Terminal.Core.Invalid_State then
               raise Program_Error with "fragmented feed entered invalid state";
            end if;
            Drain;
         end loop;
      else
         Terminal.Core.Feed (T, Data, Feed_Status);
         if Feed_Status = Terminal.Core.Invalid_State then
            raise Program_Error with "feed entered invalid state";
         end if;
         Drain;
      end if;
   end Feed_String;
begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Terminal.Core.Initialize (T, 24, 80, 256, Core_Status);
   if Core_Status /= Terminal.Core.Ok then
      raise Program_Error with "core initialization failed";
   end if;
   Terminal.Core.Set_Graphics_Stream_ID (T, 16#F022#);
   Terminal.Core.Set_Graphics_Capabilities
     (T,
      (Kitty_Direct_RGB         => True,
       Kitty_Direct_RGBA        => True,
       Kitty_Indexed_RGB        => True,
       Kitty_Indexed_RGBA       => True,
       Kitty_Direct_PNG         => True,
       Kitty_Direct_JPEG        => True,
       Kitty_Direct_GIF         => True,
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
       Pixel_Dimension      => 1_024));
   Terminal.App.Renderer.Initialize_Headless (R, Renderer_Status);
   if Renderer_Status /= Terminal.App.Renderer.Ok then
      raise Program_Error with "headless renderer initialization failed";
   end if;
   declare
      Limits : Terminal.App.Renderer.Graphics_Resource_Limits :=
        Terminal.App.Renderer.Default_Graphics_Resource_Limits;
   begin
      Limits.Image_Objects := 16;
      Limits.Image_Bytes := 4 * 1_024 * 1_024;
      Limits.Placements := 256;
      Limits.Animation_Frames := 64;
      Limits.Per_Image_Bytes := 1 * 1_024 * 1_024;
      Limits.Pixel_Dimension := 1_024;
      Terminal.App.Renderer.Set_Graphics_Resource_Limits (R, Limits);
   end;

   declare
      Input : SIO.File_Type;
   begin
      SIO.Open (Input, SIO.In_File, Ada.Command_Line.Argument (1));
      declare
         Available : constant Ada.Streams.Stream_Element_Offset :=
           Ada.Streams.Stream_Element_Offset'Min
             (Ada.Streams.Stream_Element_Offset (SIO.Size (Input)),
              Maximum_Input_Length);
         Raw : Ada.Streams.Stream_Element_Array (1 .. Available);
         Last : Ada.Streams.Stream_Element_Offset := 0;
      begin
         if Available > 0 then
            SIO.Read (Input, Raw, Last);
         end if;
         SIO.Close (Input);
         if Last > 0 then
            declare
               Mode : constant Character := Character'Val (Raw (Raw'First));
               Fragmented : constant Boolean :=
                 Mode in 'k' | 's' | 'i' | 't' | 'r';
               Payload : String (1 .. Natural'Max (0, Natural (Last) - 1));
            begin
               for I in Raw'First + 1 .. Last loop
                  Payload (Natural (I - Raw'First)) := Character'Val (Raw (I));
               end loop;
               case Mode is
                  when 'K' | 'k' =>
                     Feed_String
                       (ASCII.ESC & "_G" & Payload & ASCII.ESC & "\",
                        Fragmented);
                  when 'S' | 's' =>
                     Feed_String
                       (ASCII.ESC & "Pq" & Payload & ASCII.ESC & "\",
                        Fragmented);
                  when 'I' | 'i' =>
                     Feed_String
                       (ASCII.ESC & "]1337;File=" & Payload & ASCII.BEL,
                        Fragmented);
                  when 'T' | 't' =>
                     Feed_String
                       (ASCII.ESC & "Ptmux;"
                        & ASCII.ESC & ASCII.ESC & "_G"
                        & Payload
                        & ASCII.ESC & ASCII.ESC & "\"
                        & ASCII.ESC & "\",
                        Fragmented);
                  when others =>
                     Feed_String (Mode & Payload, Fragmented);
               end case;
            end;
         end if;
      end;
   end;

   Drain;
   declare
      Snapshot : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Diagnostics : Terminal.App.Renderer.Renderer_Diagnostics;
      Limits : constant Terminal.App.Renderer.Graphics_Resource_Limits :=
        Terminal.App.Renderer.Graphics_Resource_Limit (R);
   begin
      Snapshot.Graphics := (others => <>);
      Terminal.App.Renderer.Render (R, Snapshot, Render_Status);
      Terminal.Core.Release (Snapshot);
      if Render_Status /= Terminal.App.Renderer.Ok then
         raise Program_Error with "retained render entered failure state";
      end if;
      Diagnostics := Terminal.App.Renderer.Diagnostics (R);
      if Diagnostics.Image_Object_Count > Limits.Image_Objects
        or else Diagnostics.Image_Object_Bytes > Limits.Image_Bytes
        or else Diagnostics.Placement_Count > Limits.Placements
        or else Diagnostics.Kitty_Animation_Frame_Count > Limits.Animation_Frames
      then
         raise Program_Error with "graphics resource limit was exceeded";
      end if;
   end;
   Terminal.App.Renderer.Release_Graphics_Stream (R, 16#F022#);
   Terminal.App.Renderer.Finalize (R);
   Terminal.Core.Finalize (T);
end Graphics_Pipeline_Fuzz_Target;

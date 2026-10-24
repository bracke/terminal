with Ada.Command_Line;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;
with AUnit.Assertions;
with Interfaces;

with Terminal.App.Renderer;
with Terminal.App.Renderer.Testing;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure External_Graphics_Stream_Probe is
   use AUnit.Assertions;
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_64;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   package SIO renames Ada.Streams.Stream_IO;
   package Bytes renames Terminal.Common.Bytes;

   Maximum_Input_Length : constant := 8 * 1_024 * 1_024;
   T : Terminal.Core.Terminal;
   R : Terminal.App.Renderer.Renderer;
   Core_Status : Terminal.Core.Initialize_Status;
   Renderer_Status : Terminal.App.Renderer.Init_Status;
   Feed_Status : Terminal.Core.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status;

   procedure Render_Pending is
   begin
      while Terminal.Core.Pending_Graphics_Event_Count (T) > 0 loop
         declare
            Event : Terminal.Core.Graphics_Event;
            Result : Terminal.Core.Kitty_Graphics_Result;
            Snapshot : Terminal.Core.Render_Snapshot;
         begin
            Terminal.Core.Peek_Graphics_Event (T, Event);
            Assert (Event.Pending, "queued graphics event is pending");
            Assert (not Event.Cancelled, "external graphics event is valid");
            Ada.Text_IO.Put_Line
              (Ada.Command_Line.Argument (1)
               & ": event="
               & Terminal.Core.Graphics_Event_Sequence'Image (Event.Sequence)
               & " protocol="
               & Terminal.Core.Ignored_Graphics_Protocol'Image (Event.Protocol)
               & " cancelled=" & Boolean'Image (Event.Cancelled)
               & " bytes=" & Natural'Image (Event.Payload_Length));
            Snapshot := Terminal.Core.Snapshot (T);
            Snapshot.Graphics := Event;
            Terminal.App.Renderer.Render (R, Snapshot, Render_Status);
            Terminal.Core.Release (Snapshot);
            Ada.Text_IO.Put_Line
              (Ada.Command_Line.Argument (1)
               & ": render_status="
               & Terminal.App.Renderer.Render_Status'Image (Render_Status));
            Assert
              (Render_Status = Terminal.App.Renderer.Ok,
               "external graphics stream renders");
            Result := Terminal.App.Renderer.Graphics_Result (R, Event);
            Ada.Text_IO.Put_Line
              (Ada.Command_Line.Argument (1)
               & ": graphics_result="
               & Terminal.Core.Kitty_Graphics_Result_Code'Image (Result.Code)
               & " images="
               & Natural'Image
                   (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count));
            Terminal.Core.Complete_Graphics_Event (T, Event, Result);
            Terminal.App.Renderer.Commit_Graphics_Events (R);
         end;
      end loop;
   end Render_Pending;
begin
   if Ada.Command_Line.Argument_Count not in 1 .. 2
     or else
       (Ada.Command_Line.Argument_Count = 2
        and then Ada.Command_Line.Argument (2) /= "--allow-unrelated")
   then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Terminal.Core.Initialize (T, 24, 80, 256, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "core initializes");
   Terminal.Core.Set_Graphics_Stream_ID (T, 9_001);
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
   Terminal.App.Renderer.Initialize_Headless (R, Renderer_Status);
   Assert
     (Renderer_Status = Terminal.App.Renderer.Ok,
      "headless renderer initializes");

   declare
      Input_File : SIO.File_Type;
   begin
      SIO.Open (Input_File, SIO.In_File, Ada.Command_Line.Argument (1));
      declare
         Available : constant Ada.Streams.Stream_Element_Offset :=
           Ada.Streams.Stream_Element_Offset'Min
             (Ada.Streams.Stream_Element_Offset (SIO.Size (Input_File)),
              Maximum_Input_Length);
         Raw : Ada.Streams.Stream_Element_Array (1 .. Available);
         Last : Ada.Streams.Stream_Element_Offset;
      begin
         Assert (Available > 0, "external graphics stream is nonempty");
         SIO.Read (Input_File, Raw, Last);
         SIO.Close (Input_File);
         declare
            Data : Bytes.Byte_Array (1 .. Natural (Last));
         begin
            for I in Raw'First .. Last loop
               Data (Natural (I)) := Bytes.Byte (Raw (I));
            end loop;
            Terminal.Core.Feed (T, Data, Feed_Status);
            Ada.Text_IO.Put_Line
              (Ada.Command_Line.Argument (1)
               & ": feed_status="
               & Terminal.Core.Feed_Status'Image (Feed_Status)
               & " queued="
               & Natural'Image
                   (Terminal.Core.Pending_Graphics_Event_Count (T))
               & " malformed_utf8="
               & Natural'Image (Terminal.Core.Diagnostics (T).Malformed_UTF8)
               & " unsupported="
               & Natural'Image
                   (Terminal.Core.Diagnostics (T).Unsupported_Sequence));
            Assert
              (Feed_Status in Terminal.Core.Ok | Terminal.Core.Parser_Recovered,
               "external stream feed");
            Assert
              (Terminal.Core.Diagnostics (T).Malformed_UTF8 = 0
               and then Terminal.Core.Diagnostics (T).Parser_Overflow = 0
               and then
                 (Ada.Command_Line.Argument_Count = 2
                  or else
                    Terminal.Core.Diagnostics (T).Unsupported_Sequence = 0),
               "external stream has no malformed or unexpected content");
         end;
      end;
   end;

   Render_Pending;
   declare
      Snapshot : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Snapshot.Graphics := (others => <>);
      Terminal.App.Renderer.Render (R, Snapshot, Render_Status);
      Terminal.Core.Release (Snapshot);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "retained render");
   Ada.Text_IO.Put_Line
     (Ada.Command_Line.Argument (1)
      & ": graphics_events="
      & Interfaces.Unsigned_64'Image
          (Terminal.App.Renderer.Diagnostics (R).Graphics_Event_Count)
      & " retained_images="
      & Natural'Image (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count)
      & " objects="
      & Natural'Image
          (Terminal.App.Renderer.Diagnostics (R).Image_Object_Count)
      & " placements="
      & Natural'Image
          (Terminal.App.Renderer.Diagnostics (R).Placement_Count)
      & " installs="
      & Interfaces.Unsigned_64'Image
          (Terminal.App.Renderer.Diagnostics (R).Image_Install_Count)
      & " decode_failures="
      & Interfaces.Unsigned_64'Image
          (Terminal.App.Renderer.Diagnostics (R).Decode_Failure_Count));
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Graphics_Event_Count > 0,
      "external client produced a graphics event");
   if Ada.Command_Line.Argument_Count = 2 then
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Image_Install_Count > 0
         and then Terminal.App.Renderer.Diagnostics (R).Image_Object_Count > 0
         and then Terminal.App.Renderer.Diagnostics (R).Placement_Count > 0,
         "tmux capture installed a decoded image and placement");
   else
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count > 0,
         "external client produced a retained decoded image");
   end if;

   Terminal.App.Renderer.Release_Graphics_Stream (R, 9_001);
   Terminal.App.Renderer.Finalize (R);
   Terminal.Core.Finalize (T);
end External_Graphics_Stream_Probe;

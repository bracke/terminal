with AUnit.Assertions;

with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure ITerm2_Media_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   Finite_GIF_Base64 : constant String :=
     "R0lGODlhAQABAPAAAP8AAAAAACH/C05FVFNDQVBFMi4wAwEBAAAh+QQABQAAACwA"
     & "AAAAAQABAAACAkQBACH5BAAHAAAALAAAAAABAAEAgAAA/wAAAAICRAEAOw==";
   Infinite_GIF_Base64 : constant String :=
     "R0lGODlhAQABAPAAAP8AAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQABQAAACwA"
     & "AAAAAQABAAACAkQBACH5BAAHAAAALAAAAAABAAEAgAAA/wAAAAICRAEAOw==";
   Single_Play_GIF_Base64 : constant String :=
     "R0lGODlhAQABAPAAAP8AAAAAACH5BAAFAAAALAAAAAABAAEAAAICRAEAIfkEAAcA"
     & "AAAsAAAAAAEAAQCAAAD/AAAAAgJEAQA7";

   type Loop_Expectation is (Finite_Two_Plays, Infinite_Plays, Single_Play);

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Check_Playback
     (Encoded    : String;
      Expected   : Loop_Expectation;
      Stream_ID  : Terminal.Core.Graphics_Stream_ID;
      Label_Text : String)
   is
      R : Terminal.App.Renderer.Renderer;
      T : Terminal.Core.Terminal;
      Renderer_Init : Terminal.App.Renderer.Init_Status;
      Core_Init : Terminal.Core.Initialize_Status;
      Feed_Status : Terminal.Core.Feed_Status;
      Render_Status : Terminal.App.Renderer.Render_Status;

      procedure Render_Retained is
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Snap.Graphics := (others => <>);
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            Label_Text & " retained animation render");
      end Render_Retained;

      procedure Assert_Pixel
        (Red, Green, Blue : Byte;
         Phase : String)
      is
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Last_Frame (R);
      begin
         Assert
           (Frame.Image_Count = 1
            and then Frame.Images (1).Protocol =
              Terminal.App.Render_Model.Image_ITerm2
            and then
              Terminal.App.Render_Model.Image_Decoded_Row_Byte
                (Frame.Images (1), 0, 0) = Red
            and then
              Terminal.App.Render_Model.Image_Decoded_Row_Byte
                (Frame.Images (1), 0, 1) = Green
            and then
              Terminal.App.Render_Model.Image_Decoded_Row_Byte
                (Frame.Images (1), 0, 2) = Blue
            and then
              Terminal.App.Render_Model.Image_Decoded_Row_Byte
                (Frame.Images (1), 0, 3) = 16#FF#,
            Label_Text & " " & Phase);
      end Assert_Pixel;
   begin
      Terminal.App.Renderer.Initialize_Headless (R, Renderer_Init);
      Assert
        (Renderer_Init = Terminal.App.Renderer.Ok,
         Label_Text & " renderer initialization");
      Terminal.Core.Initialize (T, 2, 4, 16, Core_Init);
      Assert (Core_Init = Terminal.Core.Ok, Label_Text & " core initialization");
      Terminal.Core.Set_Graphics_Stream_ID (T, Stream_ID);

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "]1337;File=inline=1;doNotMoveCursor=1;width=1;height=1:"
            & Encoded
            & ASCII.BEL),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, Label_Text & " event feed");
      declare
         Event : Terminal.Core.Graphics_Event;
         Result : Terminal.Core.Kitty_Graphics_Result;
         Snap : Terminal.Core.Render_Snapshot;
      begin
         Terminal.Core.Peek_Graphics_Event (T, Event);
         Assert (Event.Pending, Label_Text & " event queued");
         Snap := Terminal.Core.Snapshot (T);
         Snap.Graphics := Event;
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            Label_Text & " event render");
         Result := Terminal.App.Renderer.Graphics_Result (R, Event);
         Terminal.Core.Complete_Graphics_Event (T, Event, Result);
         Terminal.App.Renderer.Commit_Graphics_Events (R);
      end;

      Render_Retained;
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Image_Object_Count = 1
         and then Terminal.App.Renderer.Diagnostics (R).Placement_Count = 1
         and then
           Terminal.App.Renderer.Diagnostics (R).Kitty_Animation_Frame_Count = 1,
         Label_Text & " bounded image store");
      Assert_Pixel (16#FF#, 0, 0, "starts on red frame");

      delay 0.060;
      Render_Retained;
      Assert_Pixel (0, 0, 16#FF#, "advances to blue frame");

      delay 0.080;
      Render_Retained;
      case Expected is
         when Single_Play =>
            Assert_Pixel (0, 0, 16#FF#, "stops after one play");
         when Infinite_Plays =>
            Assert_Pixel (16#FF#, 0, 0, "restarts indefinitely");
         when Finite_Two_Plays =>
            Assert_Pixel (16#FF#, 0, 0, "starts its second play");
            delay 0.060;
            Render_Retained;
            Assert_Pixel (0, 0, 16#FF#, "finishes its second play");
            delay 0.080;
            Render_Retained;
            Assert_Pixel (0, 0, 16#FF#, "stops after two plays");
      end case;

      Terminal.App.Renderer.Release_Graphics_Stream (R, Stream_ID);
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Image_Object_Count = 0
         and then Terminal.App.Renderer.Diagnostics (R).Placement_Count = 0
         and then
           Terminal.App.Renderer.Diagnostics (R).Kitty_Animation_Frame_Count = 0,
         Label_Text & " resources released with graphics stream");
      Terminal.Core.Finalize (T);
      Terminal.App.Renderer.Finalize (R);
   end Check_Playback;
begin
   Check_Playback
     (Finite_GIF_Base64, Finite_Two_Plays, 7_301, "finite-loop GIF");
   Check_Playback
     (Infinite_GIF_Base64, Infinite_Plays, 7_302, "infinite-loop GIF");
   Check_Playback
     (Single_Play_GIF_Base64, Single_Play, 7_303, "single-play GIF");
end ITerm2_Media_Smoke;

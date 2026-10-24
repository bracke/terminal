with Ada.Strings.Fixed;
with AUnit.Assertions;

with Terminal.App.Image_Media;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Vulkan_Submit;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure PICT_Renderer_Smoke is
   use AUnit.Assertions;
   use type Terminal.Common.Bytes.Byte;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Terminal.App.Render_Model.Image_Decoded_Source_Kind;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.App.Image_Media.Decode_Status;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Vulkan_Submit.Build_Status;
   use type Terminal.App.Vulkan_Submit.Texture_Source;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   PICT_Base64 : constant String :=
     "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA9AAAAAAACQAVABEC/wwA"
     & "/////wAAAAAAAAAAABUAAAAJAAAAAAAAAAEACgAAAAAACQAVAJiAFQAAAAAACQAV"
     & "AAAAAAAAAAAASAAAAEgAAAAAAAgAAQAIAAAAAAAAAAAAAAAAAAAAAAAAAAMAAAAA"
     & "AAAAAAABAACAgP//AAL///////8AA///AAAAAAAAAAAACQAVAAAAAAAJABUAAALs"
     & "AgcBAgL6A/UCDAECAvoD/gL6AQECAgwBAgL6A/4C+gEBAgIMAQIC+gP+AvoBAQIC"
     & "DAECAvoD/gL6AQECAgf1AvoBAQICB/UC+gEBAgIE7QIAAAD/";
   Truncated_PICT_Base64 : constant String :=
     "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
     & "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA9AAAAAAACQAV";
   Compatible_PICT_Base64 : constant String :=
     "AAAAAAAAABgAMAARAv8MAP/+AAAASAAAAEgAAAAAAAAAGAAwAAAAAAAECAAA"
     & "KAAPAAICSGkAAP8=";
   Red_PNG_Base64 : constant String :=
     "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4"
     & "z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg==";

   function To_Bytes (Text : String) return Terminal.Common.Bytes.Byte_Array is
      Result : Terminal.Common.Bytes.Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) :=
           Terminal.Common.Bytes.Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   R : Terminal.App.Renderer.Renderer;
   Init : Terminal.App.Renderer.Init_Status;
   T : Terminal.Core.Terminal;
   Core_Init : Terminal.Core.Initialize_Status;
   Feed : Terminal.Core.Feed_Status;
   Render : Terminal.App.Renderer.Render_Status;
begin
   Terminal.App.Renderer.Initialize_Headless (R, Init);
   Assert (Init = Terminal.App.Renderer.Ok, "PICT renderer initialize");
   Terminal.Core.Initialize (T, 2, 2, 10, Core_Init);
   Assert (Core_Init = Terminal.Core.Ok, "PICT core initialize");
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_190);
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC
         & "]1337;File=name=sample.pict;size=756;inline=1;"
         & "doNotMoveCursor=1:"
         & PICT_Base64 & ASCII.BEL),
      Feed);
   Assert (Feed = Terminal.Core.Ok, "PICT iTerm2 feed");

   declare
      Event : Terminal.Core.Graphics_Event;
      Snapshot : Terminal.Core.Render_Snapshot;
      Outcome : Terminal.Core.Kitty_Graphics_Result;
   begin
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert (Event.Pending, "PICT graphics event");
      Snapshot := Terminal.Core.Snapshot (T);
      Snapshot.Graphics := Event;
      Terminal.App.Renderer.Render (R, Snapshot, Render);
      Outcome := Terminal.App.Renderer.Graphics_Result (R, Event);
      Terminal.Core.Release (Snapshot);
      Assert (Render = Terminal.App.Renderer.Ok, "PICT renderer render");
      Terminal.Core.Complete_Graphics_Event (T, Event, Outcome);
      Terminal.App.Renderer.Commit_Graphics_Events (R);
   end;

   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
      Batch : Terminal.App.Vulkan_Submit.Submission_Batch;
      Batch_Status : Terminal.App.Vulkan_Submit.Build_Status;
   begin
      Assert
        (Frame.Image_Count = 1
         and then Diagnostics.Last_Image_Protocol =
           Terminal.App.Render_Model.Image_ITerm2
         and then Diagnostics.Last_Image_Raw_Format = 32
         and then Diagnostics.Last_Image_Pixel_Width = 21
         and then Diagnostics.Last_Image_Pixel_Height = 9
         and then Diagnostics.Last_Image_Decoded_Preview_Length = 756
         and then Diagnostics.Last_Media_Adapter_Buffer_Bytes = 756
         and then Diagnostics.Last_Media_Decoder_Configured_Bytes > 0
         and then Diagnostics.Last_Media_Warning_Count = 0
         and then not Diagnostics.Last_Media_Diagnostic.Present,
         "PICT renderer metadata");
      Assert
        (Ada.Strings.Fixed.Index
           (Terminal.App.Renderer.Media_Status_Label (Diagnostics),
            "media memory adapter_buffers=756 decoder_configured=") > 0,
         "PICT memory accounting should be human-readable");
      Assert
        (Diagnostics.Last_Image_Decoded_Preview_Bytes (93) = 255
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (94) = 0
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (95) = 0
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (96) = 255,
         "PICT renderer RGBA pixel oracle");
      Assert
        (Frame.Images (1).Decoded_Bytes /= null
         and then Frame.Images (1).Decoded_Source =
           Terminal.App.Render_Model.Image_Decoded_Source_Buffer
         and then Frame.Images (1).Decoded_Bytes (93) = 255
         and then Frame.Images (1).Decoded_Bytes (94) = 0
         and then Frame.Images (1).Decoded_Bytes (95) = 0
         and then Frame.Images (1).Decoded_Bytes (96) = 255,
         "PICT retained Vulkan source pixel oracle");
      Terminal.App.Vulkan_Submit.Build (Frame, Batch, Batch_Status);
      Assert
        (Batch_Status = Terminal.App.Vulkan_Submit.Ok
         and then Terminal.App.Vulkan_Submit.Last_Image_Texture_Source (Batch) =
           Terminal.App.Vulkan_Submit.Texture_Image
         and then Terminal.App.Vulkan_Submit.Last_Image_Decoded_Data_Byte
           (Batch, 93) = 255
         and then Terminal.App.Vulkan_Submit.Last_Image_Decoded_Data_Byte
           (Batch, 94) = 0
         and then Terminal.App.Vulkan_Submit.Last_Image_Decoded_Data_Byte
           (Batch, 95) = 0
         and then Terminal.App.Vulkan_Submit.Last_Image_Decoded_Data_Byte
           (Batch, 96) = 255,
         "PICT Vulkan submission pixel oracle");
      Terminal.App.Vulkan_Submit.Release (Batch);
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]1337;File=name=compatible.pict;inline=1:"
         & Compatible_PICT_Base64 & ASCII.BEL),
      Feed);
   Assert (Feed = Terminal.Core.Ok, "compatible PICT iTerm2 feed");
   declare
      Event : Terminal.Core.Graphics_Event;
      Snapshot : Terminal.Core.Render_Snapshot;
      Outcome : Terminal.Core.Kitty_Graphics_Result;
   begin
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert (Event.Pending, "compatible PICT graphics event");
      Snapshot := Terminal.Core.Snapshot (T);
      Snapshot.Graphics := Event;
      Terminal.App.Renderer.Render (R, Snapshot, Render);
      Outcome := Terminal.App.Renderer.Graphics_Result (R, Event);
      Terminal.Core.Release (Snapshot);
      Assert (Render = Terminal.App.Renderer.Ok, "compatible PICT render");
      Terminal.Core.Complete_Graphics_Event (T, Event, Outcome);
      Terminal.App.Renderer.Commit_Graphics_Events (R);
      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
      begin
         Assert
           (Diagnostics.Last_Media_Warning_Count > 0
            and then Diagnostics.Last_Media_First_Warning.Present
            and then Ada.Strings.Fixed.Index
              (Terminal.App.Renderer.Media_Status_Label (Diagnostics),
               "media warning=pict.warning.approximated") = 1,
            "compatible PICT warning should be human-readable");
      end;
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]1337;File=name=red.png;inline=1:"
         & Red_PNG_Base64 & ASCII.BEL),
      Feed);
   Assert (Feed = Terminal.Core.Ok, "PNG after compatible PICT feed");
   declare
      Event : Terminal.Core.Graphics_Event;
      Snapshot : Terminal.Core.Render_Snapshot;
      Outcome : Terminal.Core.Kitty_Graphics_Result;
   begin
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Snapshot := Terminal.Core.Snapshot (T);
      Snapshot.Graphics := Event;
      Terminal.App.Renderer.Render (R, Snapshot, Render);
      Outcome := Terminal.App.Renderer.Graphics_Result (R, Event);
      Terminal.Core.Release (Snapshot);
      Assert (Render = Terminal.App.Renderer.Ok, "PNG after PICT render");
      Terminal.Core.Complete_Graphics_Event (T, Event, Outcome);
      Terminal.App.Renderer.Commit_Graphics_Events (R);
      Assert
        (Terminal.App.Renderer.Media_Status_Label
           (Terminal.App.Renderer.Diagnostics (R)) = "",
         "a later built-in image should clear stale media diagnostics");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]1337;File=name=truncated.pict;inline=1:"
         & Truncated_PICT_Base64 & ASCII.BEL),
      Feed);
   Assert (Feed = Terminal.Core.Ok, "truncated PICT iTerm2 feed");
   declare
      Event : Terminal.Core.Graphics_Event;
      Snapshot : Terminal.Core.Render_Snapshot;
      Outcome : Terminal.Core.Kitty_Graphics_Result;
      Image_Count_Before : Natural;
   begin
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert (Event.Pending, "truncated PICT graphics event");
      Snapshot := Terminal.Core.Snapshot (T);
      Snapshot.Graphics := Event;
      Terminal.App.Renderer.Render (R, Snapshot, Render);
      Outcome := Terminal.App.Renderer.Graphics_Result (R, Event);
      Terminal.Core.Release (Snapshot);
      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
      begin
         Assert
           (Diagnostics.Last_Media_Diagnostic.Present
            and then Diagnostics.Last_Media_Diagnostic.Identifier_Length > 0
            and then Diagnostics.Last_Media_Decode_Attempted
            and then Diagnostics.Last_Media_Decode_Status =
              Terminal.App.Image_Media.Decode_Invalid
            and then Ada.Strings.Fixed.Index
              (Terminal.App.Renderer.Media_Status_Label (Diagnostics),
               "media error=") = 1,
            "renderer retains structured PICT failure diagnostics");
      end;
      Image_Count_Before :=
        Terminal.App.Renderer.Diagnostics (R).Last_Image_Count;
      Terminal.Core.Complete_Graphics_Event (T, Event, Outcome);
      Terminal.App.Renderer.Commit_Graphics_Events (R);

      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "]1337;File=name=ignored.png;inline=1;width=invalid:"
            & ASCII.BEL),
         Feed);
      Assert (Feed = Terminal.Core.Ok, "invalid iTerm2 dimensions feed");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert (Event.Pending, "invalid iTerm2 dimensions graphics event");
      Snapshot := Terminal.Core.Snapshot (T);
      Snapshot.Graphics := Event;
      Terminal.App.Renderer.Render (R, Snapshot, Render);
      Outcome := Terminal.App.Renderer.Graphics_Result (R, Event);
      Terminal.Core.Release (Snapshot);
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count =
           Image_Count_Before,
         "rejected iTerm2 input should not create a fallback image");
      Assert
        (Terminal.App.Renderer.Media_Status_Label
           (Terminal.App.Renderer.Diagnostics (R)) = "",
         "iTerm2 commands bypassing decode clear stale media diagnostics");
      Terminal.Core.Complete_Graphics_Event (T, Event, Outcome);
      Terminal.App.Renderer.Commit_Graphics_Events (R);
   end;

   Terminal.App.Renderer.Finalize (R);
   Terminal.Core.Finalize (T);
end PICT_Renderer_Smoke;

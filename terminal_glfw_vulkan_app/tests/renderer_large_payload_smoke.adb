with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;

procedure Renderer_Large_Payload_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;

   R             : Terminal.App.Renderer.Renderer;
   T             : Terminal.Core.Terminal;
   Init_Status   : Terminal.App.Renderer.Init_Status;
   Core_Status   : Terminal.Core.Initialize_Status;
   Feed_Status   : Terminal.Core.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status;
   Event         : Terminal.Core.Graphics_Event;
   Data_Length   : constant Natural :=
     Terminal.Core.Max_Graphics_Preview_Length + 257;
   Red_PNG_Base64 : constant String :=
     "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4"
     & "z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg==";
   Padding_Length : constant Natural := Data_Length - Red_PNG_Base64'Length;

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
      Terminal.Core.Feed (T, To_Bytes (Text), Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "large graphics payload feed");
   end Feed;
begin
   Terminal.App.Renderer.Initialize_Headless (R, Init_Status);
   Assert (Init_Status = Terminal.App.Renderer.Ok, "renderer initialize");
   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "core initialize");
   Terminal.Core.Set_Graphics_Stream_ID (T, 3_101);

   Feed (ASCII.ESC & "]1337;MultipartFile=inline=1" & ASCII.BEL);
   Feed (ASCII.ESC & "]1337;FilePart=");
   for Chunk in 1 .. Padding_Length / 4_096 loop
      Feed ((1 .. 4_096 => ' '));
   end loop;
   Feed ((1 .. Padding_Length mod 4_096 => ' '));
   Feed (Red_PNG_Base64);
   Feed (ASCII.BEL & ASCII.ESC & "]1337;FileEnd" & ASCII.BEL);

   Terminal.Core.Peek_Graphics_Event (T, Event);
   Assert (Event.Pending, "large graphics event pending");
   Terminal.App.Renderer.Stage_Graphics_Event
     (R, Event, Terminal.Core.Graphics_Event_Payload (T, Event));
   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Snap.Graphics := Event;
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
   begin
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "large staged payload render status");
      Assert
        (Diagnostics.Last_Image_Protocol =
           Terminal.App.Render_Model.Image_ITerm2,
         "large staged payload image protocol");
      Assert
        (Event.Payload_Length > Terminal.Core.Max_Graphics_Preview_Length,
         "graphics event exceeds the snapshot preview");
      Assert
        (Diagnostics.Last_Image_Payload_Preview_Complete,
         "renderer consumes complete staged payload beyond snapshot preview");
   end;

   Terminal.App.Renderer.Release_Graphics_Stream (R, 3_101);
   Terminal.Core.Finalize (T);
   Terminal.App.Renderer.Finalize (R);
end Renderer_Large_Payload_Smoke;

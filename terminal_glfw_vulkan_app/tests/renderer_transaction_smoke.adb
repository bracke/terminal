with AUnit.Assertions;

with Terminal.App.Renderer;
with Terminal.App.Renderer.Testing;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Renderer_Transaction_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   Red_PNG_Base64 : constant String :=
     "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4"
     & "z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg==";
   Animated_GIF_Base64 : constant String :=
     "R0lGODlhAQABAPAAAP8AAAAAACH/C05FVFNDQVBFMi4wAwEBAAAh+QQABQAAACwA"
     & "AAAAAQABAAACAkQBACH5BAAHAAAALAAAAAABAAEAgAAA/wAAAAICRAEAOw==";

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   R : Terminal.App.Renderer.Renderer;
   T : Terminal.Core.Terminal;
   Renderer_Init : Terminal.App.Renderer.Init_Status;
   Core_Init : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status;

   procedure Reject_At_Allocation
     (Command : String;
      Failure_Attempt : Positive;
      Label_Text : String)
   is
      Event : Terminal.Core.Graphics_Event;
      Snapshot : Terminal.Core.Render_Snapshot;
      Result : Terminal.Core.Kitty_Graphics_Result;
      D : Terminal.App.Renderer.Renderer_Diagnostics;
   begin
      Terminal.Core.Feed (T, To_Bytes (Command), Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, Label_Text & " feed");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert (Event.Pending, Label_Text & " event");

      Terminal.App.Renderer.Testing.Fail_Image_Allocation_After
        (R, Failure_Attempt);
      Snapshot := Terminal.Core.Snapshot (T);
      Snapshot.Graphics := Event;
      Terminal.App.Renderer.Render (R, Snapshot, Render_Status);
      Terminal.Core.Release (Snapshot);
      Assert (Render_Status = Terminal.App.Renderer.Ok, Label_Text & " render");

      D := Terminal.App.Renderer.Diagnostics (R);
      Assert
        (D.Image_Object_Count = 0
         and then D.Placement_Count = 0
         and then D.Image_Object_Bytes = 0,
         Label_Text & " rejection rolls back retained state");

      Result := Terminal.App.Renderer.Graphics_Result (R, Event);
      Terminal.Core.Complete_Graphics_Event (T, Event, Result);
      Terminal.App.Renderer.Commit_Graphics_Events (R);
   end Reject_At_Allocation;
begin
   Terminal.App.Renderer.Initialize_Headless (R, Renderer_Init);
   Assert (Renderer_Init = Terminal.App.Renderer.Ok, "renderer initialize");
   Terminal.Core.Initialize (T, 2, 4, 16, Core_Init);
   Assert (Core_Init = Terminal.Core.Ok, "core initialize");
   Terminal.Core.Set_Graphics_Stream_ID (T, 8_201);

   Reject_At_Allocation
     (ASCII.ESC & "]1337;File=inline=1;doNotMoveCursor=1:"
      & Red_PNG_Base64 & ASCII.BEL,
      2,
      "iTerm2 placement allocation");
   Reject_At_Allocation
     (ASCII.ESC & "Pq~" & ASCII.ESC & "\",
      2,
      "Sixel placement allocation");
   Reject_At_Allocation
     (ASCII.ESC & "]1337;File=inline=1;doNotMoveCursor=1:"
      & Animated_GIF_Base64 & ASCII.BEL,
      2,
      "animation frame allocation");

   Terminal.Core.Finalize (T);
   Terminal.App.Renderer.Finalize (R);
end Renderer_Transaction_Smoke;

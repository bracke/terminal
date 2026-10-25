with AUnit.Assertions;

with Terminal.App.Renderer;
with Terminal.App.Renderer.Testing;
with Terminal.App.Splits;
with Terminal.App.Tabs;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Renderer_Transaction_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Kitty_Graphics_Result_Code;

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
   Tabs : Terminal.App.Tabs.Tab_State;
   Splits : Terminal.App.Splits.Split_State;

   procedure Reject_At_Allocation
     (Command : String;
      Failure_Attempt : Positive;
      Label_Text : String)
   is
      Event : Terminal.Core.Graphics_Event;
      Snapshots : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
      Result : Terminal.Core.Kitty_Graphics_Result;
      D : Terminal.App.Renderer.Renderer_Diagnostics;
   begin
      Terminal.Core.Feed (T, To_Bytes (Command), Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, Label_Text & " feed");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert (Event.Pending, Label_Text & " event");

      Terminal.App.Renderer.Testing.Fail_Image_Allocation_After
        (R, Failure_Attempt);
      Snapshots (1) := Terminal.Core.Snapshot (T);
      Snapshots (1).Graphics := Event;
      Terminal.App.Renderer.Render_App
        (R,
         Snapshots,
         1,
         Terminal.App.Tabs.Snapshot (Tabs),
         Terminal.App.Splits.Snapshot (Splits),
         Render_Status);
      Terminal.Core.Release (Snapshots (1));
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

   procedure Process_Kitty
     (Command  : String;
      Expected : Terminal.Core.Kitty_Graphics_Result_Code;
      Label_Text : String)
   is
      Event : Terminal.Core.Graphics_Event;
      Snapshots : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
      Result : Terminal.Core.Kitty_Graphics_Result;
   begin
      Terminal.Core.Feed
        (T, To_Bytes (ASCII.ESC & "_" & Command & ASCII.ESC & "\"),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, Label_Text & " feed");
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert (Event.Pending, Label_Text & " event");
      Snapshots (1) := Terminal.Core.Snapshot (T);
      Snapshots (1).Graphics := Event;
      Terminal.App.Renderer.Render_App
        (R,
         Snapshots,
         1,
         Terminal.App.Tabs.Snapshot (Tabs),
         Terminal.App.Splits.Snapshot (Splits),
         Render_Status);
      Terminal.Core.Release (Snapshots (1));
      Assert (Render_Status = Terminal.App.Renderer.Ok, Label_Text & " render");
      Result := Terminal.App.Renderer.Graphics_Result (R, Event);
      if Result.Code /= Expected then
         raise Program_Error with
           Label_Text & " result: expected "
           & Terminal.Core.Kitty_Graphics_Result_Code'Image (Expected)
           & ", got "
           & Terminal.Core.Kitty_Graphics_Result_Code'Image (Result.Code);
      end if;
      Terminal.Core.Complete_Graphics_Event (T, Event, Result);
      Terminal.App.Renderer.Commit_Graphics_Events (R);
   end Process_Kitty;
begin
   Terminal.App.Renderer.Initialize_Headless (R, Renderer_Init);
   Assert (Renderer_Init = Terminal.App.Renderer.Ok, "renderer initialize");
   Terminal.Core.Initialize (T, 2, 4, 16, Core_Init);
   Assert (Core_Init = Terminal.Core.Ok, "core initialize");
   Terminal.Core.Set_Graphics_Stream_ID (T, 8_201);
   Terminal.App.Tabs.Initialize (Tabs);
   Terminal.App.Splits.Initialize (Splits);

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
   Terminal.App.Renderer.Initialize_Headless (R, Renderer_Init);
   Assert (Renderer_Init = Terminal.App.Renderer.Ok, "kitty renderer initialize");
   Terminal.Core.Initialize (T, 2, 4, 16, Core_Init);
   Assert (Core_Init = Terminal.Core.Ok, "kitty core initialize");
   Terminal.Core.Set_Graphics_Stream_ID (T, 8_202);

   declare
      Original : constant Terminal.App.Renderer.Graphics_Resource_Limits :=
        Terminal.App.Renderer.Graphics_Resource_Limit (R);
      Tight : Terminal.App.Renderer.Graphics_Resource_Limits := Original;
      D : Terminal.App.Renderer.Renderer_Diagnostics;
      Original_X : Float;
      Original_Y : Float;
      Original_Width : Float;
   begin
      Tight.Placements := 1;
      Terminal.App.Renderer.Set_Graphics_Resource_Limits (R, Tight);
      Process_Kitty
        ("Gq=2,a=T,i=10,p=1,f=32,s=1,v=1,c=1,r=1,C=1;/wAA/w==",
         Terminal.Core.Kitty_OK,
         "initial combined placement");
      Original_X :=
        Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).X;
      Original_Y :=
        Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Y;
      Original_Width :=
        Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Width;

      Terminal.Core.Feed
        (T, To_Bytes (ASCII.ESC & "[2;2H"), Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "failed replacement cursor movement feed");
      Process_Kitty
        ("Gq=2,a=T,i=10,p=1,f=32,s=1,v=1,c=2,r=1,C=1;!!!!",
         Terminal.Core.Kitty_EINVAL,
         "malformed combined replacement");
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1
         and then
           Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).X =
             Original_X
         and then
           Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Y =
             Original_Y
         and then
           Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Width =
             Original_Width,
         "failed combined replacement preserves exact placement");
      Process_Kitty
        ("Gq=2,a=T,i=11,p=1,f=32,s=1,v=1,c=1,r=1,C=1;AP8A/w==",
         Terminal.Core.Kitty_ENOMEM,
         "placement quota rejection");
      D := Terminal.App.Renderer.Diagnostics (R);
      Assert
        (D.Image_Object_Count = 1
         and then D.Placement_Count = 1
         and then D.Image_Object_Bytes = 4,
         "placement quota rejection publishes no image object");

      Process_Kitty
        ("Gq=2,a=T,i=10,p=1,f=32,s=1,v=1,x=2,c=1,r=1,C=1;AP8A/w==",
         Terminal.Core.Kitty_EINVAL,
         "invalid replacement geometry");
      D := Terminal.App.Renderer.Diagnostics (R);
      Assert
        (D.Image_Object_Count = 1
         and then D.Placement_Count = 1
         and then D.Image_Object_Bytes = 4
         and then
           Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1
         and then
           Terminal.App.Renderer.Testing.Last_Frame (R).Images (1)
             .Decoded_Bytes (1) = 255,
         "failed combined replacement preserves prior image and placement");

      Tight.Placements := 2;
      Terminal.App.Renderer.Set_Graphics_Resource_Limits (R, Tight);
      Process_Kitty
        ("Gq=2,a=t,i=20,f=32,s=1,v=1;/wAA/w==",
         Terminal.Core.Kitty_OK,
         "unplaced object for allocation test");
      Terminal.App.Renderer.Testing.Fail_Image_Allocation_After (R, 1);
      Process_Kitty
        ("Gq=2,a=p,i=20,p=1,c=1,r=1,C=1",
         Terminal.Core.Kitty_ENOMEM,
         "placement allocation rejection");
      D := Terminal.App.Renderer.Diagnostics (R);
      Assert
        (D.Image_Object_Count = 2 and then D.Placement_Count = 1,
         "placement allocation failure preserves existing objects");
      Terminal.App.Renderer.Set_Graphics_Resource_Limits (R, Original);
   end;

   Terminal.Core.Finalize (T);
   Terminal.App.Renderer.Finalize (R);
end Renderer_Transaction_Smoke;

with AUnit.Assertions;

with Terminal.App.Renderer;
with Terminal.App.Renderer.Testing;
with Terminal.App.Splits;
with Terminal.App.Tabs;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Renderer_Relative_Placement_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Kitty_Graphics_Result_Code;

   R : Terminal.App.Renderer.Renderer;
   T : Terminal.Core.Terminal;
   Renderer_Status : Terminal.App.Renderer.Init_Status;
   Core_Status : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status;
   Tabs : Terminal.App.Tabs.Tab_State;
   Splits : Terminal.App.Splits.Split_State;
   Allocated_ID : Terminal.Core.Graphics_ID := 0;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for Index in Text'Range loop
         Result (Index - Text'First + 1) :=
           Byte (Character'Pos (Text (Index)));
      end loop;
      return Result;
   end To_Bytes;

   function Trimmed (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Trimmed;

   procedure Process
     (Command  : String;
      Expected : Terminal.Core.Kitty_Graphics_Result_Code;
      Label_Text : String)
   is
      Snapshots : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
      Outcome : Terminal.Core.Kitty_Graphics_Result;
   begin
      Terminal.Core.Feed (T, To_Bytes (Command), Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, Label_Text & " feed");
      Snapshots (1) := Terminal.Core.Snapshot (T);
      Terminal.App.Renderer.Render_App
        (R,
         Snapshots,
         1,
         Terminal.App.Tabs.Snapshot (Tabs),
         Terminal.App.Splits.Snapshot (Splits),
         Render_Status);
      Assert (Render_Status = Terminal.App.Renderer.Ok, Label_Text & " render");
      Outcome := Terminal.App.Renderer.Graphics_Result
        (R, Snapshots (1).Graphics);
      Assert (Outcome.Code = Expected, Label_Text & " result");
      Assert (not Outcome.Move_Cursor, Label_Text & " cursor movement");
      Terminal.Core.Complete_Graphics_Event
        (T, Snapshots (1).Graphics, Outcome);
      Terminal.App.Renderer.Commit_Graphics_Events (R);
      Terminal.Core.Release (Snapshots (1));
   end Process;
begin
   Terminal.App.Renderer.Initialize_Headless (R, Renderer_Status);
   Assert (Renderer_Status = Terminal.App.Renderer.Ok, "renderer initialize");
   Terminal.Core.Initialize (T, 1, 4, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "core initialize");
   Terminal.Core.Set_Graphics_Stream_ID (T, 999);
   Terminal.App.Tabs.Initialize (Tabs);
   Terminal.App.Splits.Initialize (Splits);

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC
         & "_Gq=0,a=T,I=700,p=1,f=32,s=1,v=1,c=1,r=1;"
         & "/wAA/w==" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "retry graphics feed");
   declare
      Snapshots : Terminal.App.Renderer.Snapshot_Array (1 .. 1) :=
        (1 => Terminal.Core.Snapshot (T));
      Outcome : Terminal.Core.Kitty_Graphics_Result;
   begin
      Terminal.App.Renderer.Render_App
        (R, Snapshots, 1,
         Terminal.App.Tabs.Snapshot (Tabs),
         Terminal.App.Splits.Snapshot (Splits), Render_Status);
      Assert (Render_Status = Terminal.App.Renderer.Ok, "initial render");
      Terminal.App.Renderer.Render_App
        (R, Snapshots, 1,
         Terminal.App.Tabs.Snapshot (Tabs),
         Terminal.App.Splits.Snapshot (Splits), Render_Status);
      Assert (Render_Status = Terminal.App.Renderer.Ok, "retry render");
      Outcome := Terminal.App.Renderer.Graphics_Result
        (R, Snapshots (1).Graphics);
      Assert
        (Outcome.Code = Terminal.Core.Kitty_OK
         and then Outcome.Image_ID /= 0
         and then Outcome.Image_Number = 700
         and then Outcome.Placement_ID = 1
         and then Outcome.Move_Cursor,
         "numbered transmission response");
      Allocated_ID := Outcome.Image_ID;
      Terminal.Core.Complete_Graphics_Event
        (T, Snapshots (1).Graphics, Outcome);
      Terminal.Core.Release (Snapshots (1));
   end;
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Image_Object_Count = 1
      and then Terminal.App.Renderer.Diagnostics (R).Placement_Count = 1
      and then Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1,
      "retry does not duplicate graphics state");
   Terminal.App.Renderer.Commit_Graphics_Events (R);

   Process
     (ASCII.ESC & "_Gq=2,a=p,I=700,p=2,P=999,Q=1,H=1,V=0,c=1,r=1;"
      & ASCII.ESC & "\",
      Terminal.Core.Kitty_ENOPARENT,
      "missing parent");
   Process
     (ASCII.ESC & "_Gq=1,a=p,I=700,p=2,P="
      & Trimmed (Natural (Allocated_ID))
      & ",Q=1,H=1,V=0,c=1,r=1;" & ASCII.ESC & "\",
      Terminal.Core.Kitty_OK,
      "valid child");
   Process
     (ASCII.ESC & "_Gq=2,a=p,I=700,p=1,P="
      & Trimmed (Natural (Allocated_ID))
      & ",Q=2,H=1,V=0,c=1,r=1;" & ASCII.ESC & "\",
      Terminal.Core.Kitty_ECYCLE,
      "relative cycle");

   Terminal.Core.Finalize (T);
   Terminal.App.Renderer.Finalize (R);
end Renderer_Relative_Placement_Smoke;

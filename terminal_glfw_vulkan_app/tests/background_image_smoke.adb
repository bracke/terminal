with Ada.Streams;
with Ada.Streams.Stream_IO;
with AUnit.Assertions;

with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Renderer.Testing;
with Terminal.Core;
with Test_Support;

procedure Background_Image_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Renderer.Background_Update_Status;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Render_Model.Image_Array_View;
   use type Terminal.Core.Initialize_Status;

   Fixture : Test_Support.Temporary_File;
   File : Ada.Streams.Stream_IO.File_Type;
   GIF : constant Ada.Streams.Stream_Element_Array :=
     [71, 73, 70, 56, 55, 97,
      1, 0, 1, 0, 16#80#, 0, 0,
      255, 0, 0, 0, 0, 0,
      16#2C#, 0, 0, 0, 0, 1, 0, 1, 0, 0,
      2, 2, 16#44#, 1, 0, 16#3B#];
   R : Terminal.App.Renderer.Renderer;
   T : Terminal.Core.Terminal;
   Init : Terminal.App.Renderer.Init_Status;
   Core_Init : Terminal.Core.Initialize_Status;
   Background : Terminal.App.Renderer.Background_Update_Status;
   Render : Terminal.App.Renderer.Render_Status;
begin
   Test_Support.Reserve (Fixture, "bracke-terminal-background.gif");
   Ada.Streams.Stream_IO.Create
     (File, Ada.Streams.Stream_IO.Out_File, Test_Support.Path (Fixture));
   Ada.Streams.Stream_IO.Write (File, GIF);
   Ada.Streams.Stream_IO.Close (File);

   Terminal.App.Renderer.Initialize_Headless (R, Init);
   Assert (Init = Terminal.App.Renderer.Ok, "headless renderer initializes");
   Terminal.App.Renderer.Set_Background_Image
     (R, Test_Support.Path (Fixture) & ".missing", 42, Background);
   Assert
     (Background = Terminal.App.Renderer.Background_Invalid_Path,
      "missing background image is rejected without changing state");
   Terminal.App.Renderer.Set_Background_Image
     (R, Test_Support.Path (Fixture), 42, Background);
   Assert
     (Background = Terminal.App.Renderer.Background_Ok,
      "bounded GIF background is decoded and installed");

   Terminal.Core.Initialize (T, 1, 1, 10, Core_Init);
   Assert (Core_Init = Terminal.Core.Ok, "core initializes");
   declare
      Snapshot : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snapshot, Render);
      Terminal.Core.Release (Snapshot);
   end;
   Assert (Render = Terminal.App.Renderer.Ok, "background frame renders");
   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
   begin
      Assert (Frame.Image_Count = 1, "background contributes one image command");
      Assert
        (Frame.Images /= null
         and then Frame.Images (1).Z_Index = Integer'First
         and then abs (Frame.Images (1).Tint.A - 0.42) < 0.001,
         "background is below cell colors with configured opacity");
   end;

   Terminal.App.Renderer.Set_Background_Image (R, "", 100, Background);
   Assert
     (Background = Terminal.App.Renderer.Background_Cleared,
      "empty background path clears the installed image");
   Terminal.App.Renderer.Finalize (R);
exception
   when others =>
      if Ada.Streams.Stream_IO.Is_Open (File) then
         Ada.Streams.Stream_IO.Close (File);
      end if;
      raise;
end Background_Image_Smoke;

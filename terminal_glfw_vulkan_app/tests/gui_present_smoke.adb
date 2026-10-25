with Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;
with AUnit.Assertions;
with Interfaces;

with GLFW_Vulkan;
with GLFW_Vulkan.Events;
with GLFW_Vulkan.Windows;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Renderer.Testing;
with Terminal.App.Vulkan_Context;
with Terminal.App.Vulkan_Presenter;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure GUI_Present_Smoke is
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_64;
   use Terminal.Common.Bytes;
   use type GLFW_Vulkan.Init_Status;
   use type GLFW_Vulkan.Windows.Create_Status;
   use type GLFW_Vulkan.Windows.Cursor_Status;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Vulkan_Context.Init_Status;
   use type Terminal.App.Vulkan_Presenter.Init_Status;
   use type Terminal.App.Vulkan_Presenter.Present_Status;
   use type Terminal.App.Vulkan_Presenter.Readback_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Ignored_Graphics_Protocol;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Kitty_Graphics_Result_Code;

   --  AUnit's Assert outside a test case raises with no word of what
   --  failed; say it on standard error first, so a CI log names the check.
   procedure Assert (Condition : Boolean; Message : String);

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAILED: " & Message);
         AUnit.Assertions.Assert (False, Message);
      end if;
   end Assert;

   Ctx : GLFW_Vulkan.Context;
   W   : GLFW_Vulkan.Windows.Window;
   Init : GLFW_Vulkan.Init_Status;
   Window_Status : GLFW_Vulkan.Windows.Create_Status;
   Vk_Ctx : Terminal.App.Vulkan_Context.Context;
   Vk_Status : Terminal.App.Vulkan_Context.Init_Status;
   Presenter : Terminal.App.Vulkan_Presenter.Presenter;
   Presenter_Status : Terminal.App.Vulkan_Presenter.Init_Status;
   R : Terminal.App.Renderer.Renderer;
   Renderer_Status : Terminal.App.Renderer.Init_Status;
   T : Terminal.Core.Terminal;
   Core_Status : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status;
   Present_Status : Terminal.App.Vulkan_Presenter.Present_Status;
   Readback_Status : Terminal.App.Vulkan_Presenter.Readback_Status;
   FB_Width  : Natural := 0;
   FB_Height : Natural := 0;
   Cursor_Status : GLFW_Vulkan.Windows.Cursor_Status;
   Stream_Mode : constant Boolean := Ada.Command_Line.Argument_Count = 1;
   Require_Presentation : constant Boolean :=
     Stream_Mode
     or else
       (Ada.Environment_Variables.Exists ("TERMINAL_REQUIRE_GUI_PRESENT")
        and then
          Ada.Environment_Variables.Value ("TERMINAL_REQUIRE_GUI_PRESENT") =
            "1");
   Saw_Stream_Image : Boolean := False;
   Presented_Stream_Image : Boolean := False;
   Pixel_Oracle_Passed : Boolean := False;
   Kitty_Pixel_Oracle_Passed : Boolean := False;
   PICT_Pixel_Oracle_Passed : Boolean := False;

   function Display_Available return Boolean is
     (Ada.Environment_Variables.Exists ("DISPLAY")
      or else Ada.Environment_Variables.Exists ("WAYLAND_DISPLAY"));

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Skip (Reason : String) is
   begin
      Ada.Text_IO.Put_Line ("gui_present_smoke: skipped: " & Reason);
      if Require_Presentation then
         --  A captured stream or the CI requirement explicitly requests
         --  physical presentation.  Missing window-system/Vulkan support
         --  must not turn that requirement into a false positive.
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   end Skip;

   procedure Process_Pending_Graphics is
   begin
      while Terminal.Core.Pending_Graphics_Event_Count (T) > 0 loop
         declare
            Event : Terminal.Core.Graphics_Event;
            Result : Terminal.Core.Kitty_Graphics_Result;
            Snap : Terminal.Core.Render_Snapshot;
         begin
            Terminal.Core.Peek_Graphics_Event (T, Event);
            Assert
              (Event.Pending and then not Event.Cancelled,
               "tmux graphics event should be complete");
            Snap := Terminal.Core.Snapshot (T);
            Snap.Graphics := Event;
            Terminal.App.Renderer.Render (R, Snap, Render_Status);
            Terminal.Core.Release (Snap);
            Assert
              (Render_Status = Terminal.App.Renderer.Ok,
               "tmux graphics event should render");
            Result := Terminal.App.Renderer.Graphics_Result (R, Event);
            Terminal.Core.Complete_Graphics_Event (T, Event, Result);
            Terminal.App.Renderer.Commit_Graphics_Events (R);

            --  Render immediately after commit, before subsequent bytes can
            --  switch screens or erase the placement as tmux exits.
            Snap := Terminal.Core.Snapshot (T);
            Snap.Graphics := (others => <>);
            Terminal.App.Renderer.Render (R, Snap, Render_Status);
            Terminal.Core.Release (Snap);
            Assert
              (Render_Status = Terminal.App.Renderer.Ok,
               "committed tmux image should render");
            if Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count > 0 then
               declare
                  Frame : constant Terminal.App.Render_Model.Frame_Commands :=
                    Terminal.App.Renderer.Testing.Last_Frame (R);
                  Expected_Protocol : constant
                    Terminal.App.Render_Model.Image_Protocol :=
                      (case Event.Protocol is
                          when Terminal.Core.Kitty_Graphics =>
                            Terminal.App.Render_Model.Image_Kitty,
                          when Terminal.Core.ITerm2_Graphics =>
                            Terminal.App.Render_Model.Image_ITerm2,
                          when others =>
                            Terminal.App.Render_Model.Image_Sixel);
                  Target_Index : Natural := 0;
               begin
                  Assert
                    (Result.Code = Terminal.Core.Kitty_OK,
                     "graphics event should install successfully");
                  for Index in 1 .. Frame.Image_Count loop
                     if Frame.Images (Index).Protocol = Expected_Protocol then
                        Target_Index := Index;
                     end if;
                  end loop;
                  Assert
                    (Target_Index > 0,
                     "current graphics event should own a frame command");
                  if Target_Index > 0 then
                     declare
                        Image : constant Terminal.App.Render_Model.Image_Command :=
                          Frame.Images (Target_Index);
                        Pixel_X : constant Natural :=
                          Natural
                            (Float'Max (0.0, Image.X + Image.Width / 2.0));
                        Pixel_Y : constant Natural :=
                          Natural
                            (Float'Max (0.0, Image.Y + Image.Height / 2.0));
                        Red, Green, Blue, Alpha : Byte := 0;
                        Expect_Green : constant Boolean :=
                          Event.Protocol = Terminal.Core.ITerm2_Graphics;
                     begin
                        Saw_Stream_Image := True;
                        Terminal.App.Renderer.Present
                          (R, Vk_Ctx, Presenter, Present_Status);
                        Assert
                          (Present_Status = Terminal.App.Vulkan_Presenter.Ok,
                           "image frame should reach Vulkan presentation");
                        Presented_Stream_Image := True;
                        Terminal.App.Vulkan_Presenter.Readback_Pixel
                          (Presenter,
                           Pixel_X,
                           Pixel_Y,
                           Red,
                           Green,
                           Blue,
                           Alpha,
                           Readback_Status);
                        Assert
                          (Readback_Status =
                             Terminal.App.Vulkan_Presenter.Readback_Ok,
                           "presented image pixel should be readable");
                        Assert
                          ((if Expect_Green
                            then Natural (Red) <= 16
                              and then Natural (Green) >= 240
                              and then Natural (Blue) <= 16
                            else Natural (Red) >= 240
                              and then Natural (Green) <= 16
                              and then Natural (Blue) <= 16)
                           and then Natural (Alpha) >= 240,
                           "presented image center should match its pixel oracle");
                        case Event.Protocol is
                           when Terminal.Core.Kitty_Graphics =>
                              Kitty_Pixel_Oracle_Passed := True;
                           when Terminal.Core.ITerm2_Graphics =>
                              PICT_Pixel_Oracle_Passed := True;
                           when others =>
                              null;
                        end case;
                        Terminal.App.Vulkan_Presenter.Readback_Pixel
                          (Presenter,
                           FB_Width - 1,
                           FB_Height - 1,
                           Red,
                           Green,
                           Blue,
                           Alpha,
                           Readback_Status);
                        Assert
                          (Readback_Status =
                             Terminal.App.Vulkan_Presenter.Readback_Ok
                           and then Natural (Red) <= 80
                           and then Natural (Green) <= 80
                           and then Natural (Blue) <= 80
                           and then abs (Integer (Red) - Integer (Green)) <= 16
                           and then abs (Integer (Green) - Integer (Blue)) <= 16
                           and then Natural (Alpha) >= 240,
                           "presented framebuffer corner should match the dark background oracle");
                        Pixel_Oracle_Passed := True;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
   end Process_Pending_Graphics;

   procedure Feed_Stream_File (Path : String) is
      package SIO renames Ada.Streams.Stream_IO;
      Maximum_Input_Length : constant := 8 * 1_024 * 1_024;
      Input_File : SIO.File_Type;
   begin
      SIO.Open (Input_File, SIO.In_File, Path);
      declare
         Available : constant Ada.Streams.Stream_Element_Offset :=
           Ada.Streams.Stream_Element_Offset'Min
             (Ada.Streams.Stream_Element_Offset (SIO.Size (Input_File)),
              Maximum_Input_Length);
         Raw : Ada.Streams.Stream_Element_Array (1 .. Available);
         Last : Ada.Streams.Stream_Element_Offset;
      begin
         Assert (Available > 0, "graphics stream is nonempty");
         SIO.Read (Input_File, Raw, Last);
         SIO.Close (Input_File);
         declare
            Data : Byte_Array (1 .. 1);
         begin
            for I in Raw'First .. Last loop
               Data (1) := Byte (Raw (I));
               Terminal.Core.Feed (T, Data, Feed_Status);
               Assert
                 (Feed_Status in
                    Terminal.Core.Ok | Terminal.Core.Parser_Recovered,
                  "tmux graphics byte feed should recover deterministically");
               Process_Pending_Graphics;
            end loop;
            Assert
              (Feed_Status in Terminal.Core.Ok | Terminal.Core.Parser_Recovered,
               "tmux graphics stream feed should recover deterministically");
         end;
      end;
   end Feed_Stream_File;
begin
   Assert
     (Ada.Command_Line.Argument_Count <= 1,
      "usage: gui_present_smoke [terminal-stream.bin]");
   GLFW_Vulkan.Windows.Set_Standard_Cursor
     (W, GLFW_Vulkan.Windows.Hand_Cursor, Cursor_Status);
   Assert
     (Cursor_Status = GLFW_Vulkan.Windows.Window_Invalid,
      "invalid window cursor set should be explicit");

   if not Display_Available then
      Skip ("no DISPLAY or WAYLAND_DISPLAY");
      return;
   end if;

   GLFW_Vulkan.Initialize (Ctx, Init);
   if Init /= GLFW_Vulkan.Ok then
      Skip ("GLFW init failed: " & GLFW_Vulkan.Init_Status'Image (Init));
      return;
   end if;

   GLFW_Vulkan.Windows.Create
     (Ctx, W, 320, 200, "Terminal GUI Smoke", Window_Status);
   if Window_Status /= GLFW_Vulkan.Windows.Ok then
      GLFW_Vulkan.Finalize (Ctx);
      Skip
        ("window creation failed: "
         & GLFW_Vulkan.Windows.Create_Status'Image (Window_Status));
      return;
   end if;

   GLFW_Vulkan.Events.Poll;
   Assert (GLFW_Vulkan.Windows.Is_Valid (W), "window should be valid");
   GLFW_Vulkan.Windows.Set_Standard_Cursor
     (W, GLFW_Vulkan.Windows.Hand_Cursor, Cursor_Status);
   Assert
     (Cursor_Status = GLFW_Vulkan.Windows.Ok,
      "hand cursor should be set on valid window");
   GLFW_Vulkan.Windows.Set_Standard_Cursor
     (W, GLFW_Vulkan.Windows.Default_Cursor, Cursor_Status);
   Assert
     (Cursor_Status = GLFW_Vulkan.Windows.Ok,
      "default cursor should be restored on valid window");

   Terminal.App.Vulkan_Context.Initialize (Vk_Ctx, W, Vk_Status);
   if Vk_Status /= Terminal.App.Vulkan_Context.Ok then
      GLFW_Vulkan.Windows.Destroy (W);
      GLFW_Vulkan.Finalize (Ctx);
      Skip
        ("Vulkan context init failed: "
         & Terminal.App.Vulkan_Context.Init_Status'Image (Vk_Status));
      return;
   end if;

   GLFW_Vulkan.Windows.Framebuffer_Size (W, FB_Width, FB_Height);
   if FB_Width = 0 or else FB_Height = 0 then
      Terminal.App.Vulkan_Context.Finalize (Vk_Ctx);
      GLFW_Vulkan.Windows.Destroy (W);
      GLFW_Vulkan.Finalize (Ctx);
      Skip ("zero-sized framebuffer");
      return;
   end if;

   Terminal.App.Vulkan_Presenter.Initialize
     (P              => Presenter,
      Context        => Vk_Ctx,
      Status         => Presenter_Status,
      Desired_Width  => FB_Width,
      Desired_Height => FB_Height);
   if Presenter_Status /= Terminal.App.Vulkan_Presenter.Ok then
      Terminal.App.Vulkan_Context.Finalize (Vk_Ctx);
      GLFW_Vulkan.Windows.Destroy (W);
      GLFW_Vulkan.Finalize (Ctx);
      Skip
        ("presenter init failed: "
         & Terminal.App.Vulkan_Presenter.Init_Status'Image (Presenter_Status));
      return;
   end if;

   Terminal.App.Vulkan_Presenter.Enable_Framebuffer_Readback
     (Presenter, Readback_Status);
   Assert
     (Readback_Status = Terminal.App.Vulkan_Presenter.Readback_Ok,
      "framebuffer readback should be available for visual comparison");

   Terminal.App.Renderer.Initialize (R, Vk_Ctx, Renderer_Status);
   Assert
     (Renderer_Status = Terminal.App.Renderer.Ok,
      "renderer should initialize with live Vulkan context");

   Terminal.App.Renderer.Set_Framebuffer_Size (R, FB_Width, FB_Height);
   Terminal.Core.Initialize (T, 4, 16, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "core should initialize");
   Terminal.Core.Feed (T, To_Bytes ("GUI smoke"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "core feed should succeed");

   if Stream_Mode then
      Feed_Stream_File (Ada.Command_Line.Argument (1));
   else
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=T,i=777,f=32,s=1,v=1,c=2,r=1,C=1;/wAA/w=="
            & ASCII.ESC & "\"),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "Kitty visual-oracle image feed");
      Process_Pending_Graphics;
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "]1337;File=name=green.pict;inline=1;width=2;"
            & "height=1;preserveAspectRatio=0;doNotMoveCursor=1:"
            & "AAAAAAAAAAAABAAEABEC/wwA//4AAABIAAAASAAAAAAAAAAEAAQAAAAA"
            & "ABoAAP//AAAAMQAAAAAABAAEAP8=" & ASCII.BEL),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "PICT visual-oracle image feed");
      Process_Pending_Graphics;
   end if;

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "render should succeed");
   if Stream_Mode then
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Graphics_Event_Count > 0
         and then Saw_Stream_Image
         and then Presented_Stream_Image
         and then Pixel_Oracle_Passed,
         "released-tmux image should reach a real Vulkan presentation");
   else
      Assert
        (Pixel_Oracle_Passed
         and then Kitty_Pixel_Oracle_Passed
         and then PICT_Pixel_Oracle_Passed
         and then Terminal.App.Renderer.Diagnostics (R).Last_Media_Diagnostic.Present = False,
         "Kitty and native PICT should pass live GPU pixel oracles");
   end if;
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Vertex_Count > 0,
      "render should produce Vulkan vertices");

   Terminal.App.Renderer.Present (R, Vk_Ctx, Presenter, Present_Status);
   Assert
     (Present_Status = Terminal.App.Vulkan_Presenter.Ok
      or else Present_Status = Terminal.App.Vulkan_Presenter.Validated_Not_Presented,
      "present should succeed or validate without presentation");

   --  An unchanged compositor frame must draw the resident GPU data without
   --  uploading either the text atlas or image atlas again.
   if Present_Status = Terminal.App.Vulkan_Presenter.Ok then
      declare
         Before : constant Terminal.App.Vulkan_Presenter.Diagnostic_Snapshot :=
           Terminal.App.Vulkan_Presenter.Diagnostics (Presenter);
      begin
         Terminal.App.Renderer.Present_Retained
           (R, Vk_Ctx, Presenter, Present_Status);
         declare
            After : constant Terminal.App.Vulkan_Presenter.Diagnostic_Snapshot :=
              Terminal.App.Vulkan_Presenter.Diagnostics (Presenter);
         begin
            Assert
              (Present_Status = Terminal.App.Vulkan_Presenter.Ok,
               "retained GPU frame should present successfully");
            Assert
              (After.Logical_Device.Atlas_Upload_Count =
                 Before.Logical_Device.Atlas_Upload_Count,
               "retained frame must not upload the text atlas");
            Assert
              (After.Logical_Device.Image_Texture_Upload_Count =
                 Before.Logical_Device.Image_Texture_Upload_Count,
               "retained frame must not upload image textures");
            Assert
              (After.Logical_Device.Rendered_Frame_Count =
                 Before.Logical_Device.Rendered_Frame_Count + 1,
               "retained frame should still submit one presentation");
         end;
      end;
   end if;

   --  Exercise the same full resource teardown/reconstruction path used after
   --  VK_ERROR_DEVICE_LOST.  A real device-loss injection is not portable,
   --  but this proves that the retained CPU batch can populate and present on
   --  a fresh logical device without rebuilding terminal state.
   Terminal.App.Vulkan_Presenter.Finalize (Presenter);
   Terminal.App.Vulkan_Presenter.Initialize
     (P              => Presenter,
      Context        => Vk_Ctx,
      Status         => Presenter_Status,
      Desired_Width  => FB_Width,
      Desired_Height => FB_Height);
   Assert
     (Presenter_Status = Terminal.App.Vulkan_Presenter.Ok,
      "presenter should reconstruct after device teardown");
   Terminal.App.Renderer.Present (R, Vk_Ctx, Presenter, Present_Status);
   Assert
     (Present_Status = Terminal.App.Vulkan_Presenter.Ok
      or else Present_Status = Terminal.App.Vulkan_Presenter.Validated_Not_Presented,
      "reconstructed presenter should accept the retained frame");

   Terminal.App.Renderer.Finalize (R);
   Terminal.App.Vulkan_Presenter.Finalize (Presenter);
   Terminal.App.Vulkan_Context.Finalize (Vk_Ctx);
   GLFW_Vulkan.Windows.Destroy (W);
   GLFW_Vulkan.Finalize (Ctx);
end GUI_Present_Smoke;

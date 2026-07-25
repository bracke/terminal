with GLFW_Vulkan;
with GLFW_Vulkan.Clipboard;
with GLFW_Vulkan.Events;
with GLFW_Vulkan.Input;
with GLFW_Vulkan.Windows;
with Terminal.Core;
with Terminal.App.Diagnostics;
with Terminal.App.Input_Map;
with Terminal.App.PTY_Reader;
with Terminal.App.PTY_Write;
with Terminal.App.Queues;
with Terminal.App.Renderer;
with Terminal.App.Resize;
with Terminal.App.Scrollback_View;
with Terminal.App.Selection;
with Terminal.App.Vulkan_Context;
with Terminal.App.Vulkan_Presenter;
with Terminal.PTY.POSIX;

package body Terminal.App.Main_Loop is
   use type GLFW_Vulkan.Init_Status;
   use type GLFW_Vulkan.Windows.Create_Status;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Vulkan_Context.Init_Status;
   use type Terminal.App.Vulkan_Presenter.Init_Status;
   use type Terminal.App.Vulkan_Presenter.Present_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Resize_Status;
   use type Terminal.PTY.POSIX.Spawn_Status;
   use type Terminal.PTY.POSIX.Resize_Status;
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type GLFW_Vulkan.Input.Key;
   use type GLFW_Vulkan.Input.Key_Action;
   use type GLFW_Vulkan.Input.Mouse_Button;

   Input_Queue : access Terminal.App.Queues.Input_Event_Queue := null;

   procedure On_Key (Event : GLFW_Vulkan.Input.Key_Event) is
   begin
      if Input_Queue /= null then
         Input_Queue.Push
           ((Kind            => Terminal.App.Queues.Key,
             Width           => 0,
             Height          => 0,
             Bytes           => (others => <>),
             Key_Event       => Event,
             Character_Event => (others => <>),
             Button_Event    => (others => <>),
             Cursor_Event    => (others => <>)));
      end if;
   end On_Key;

   procedure On_Character (Event : GLFW_Vulkan.Input.Character_Event) is
   begin
      if Input_Queue /= null then
         Input_Queue.Push
           ((Kind            => Terminal.App.Queues.Character,
             Width           => 0,
             Height          => 0,
             Bytes           => (others => <>),
             Key_Event       => (others => <>),
             Character_Event => Event,
             Button_Event    => (others => <>),
             Cursor_Event    => (others => <>)));
      end if;
   end On_Character;

   procedure On_Mouse_Button (Event : GLFW_Vulkan.Input.Mouse_Button_Event) is
   begin
      if Input_Queue /= null then
         Input_Queue.Push
           ((Kind            => Terminal.App.Queues.Mouse_Button,
             Width           => 0,
             Height          => 0,
             Bytes           => (others => <>),
             Key_Event       => (others => <>),
             Character_Event => (others => <>),
             Button_Event    => Event,
             Cursor_Event    => (others => <>)));
      end if;
   end On_Mouse_Button;

   procedure On_Cursor_Position
     (Event : GLFW_Vulkan.Input.Cursor_Position_Event)
   is
   begin
      if Input_Queue /= null then
         Input_Queue.Push
           ((Kind            => Terminal.App.Queues.Cursor_Position,
             Width           => 0,
             Height          => 0,
             Bytes           => (others => <>),
             Key_Event       => (others => <>),
             Character_Event => (others => <>),
             Button_Event    => (others => <>),
             Cursor_Event    => Event));
      end if;
   end On_Cursor_Position;

   function Same_Title
     (Left  : Terminal.Core.Title_Text;
      Right : Terminal.Core.Title_Text) return Boolean
   is
   begin
      if Left.Length /= Right.Length then
         return False;
      end if;

      for I in 1 .. Left.Length loop
         if Left.Text (I) /= Right.Text (I) then
            return False;
         end if;
      end loop;

      return True;
   end Same_Title;

   procedure Apply_Title
     (W          : GLFW_Vulkan.Windows.Window;
      New_Title  : Terminal.Core.Title_Text;
      Last_Title : in out Terminal.Core.Title_Text)
   is
   begin
      if Same_Title (New_Title, Last_Title) then
         return;
      end if;

      if New_Title.Length = 0 then
         GLFW_Vulkan.Windows.Set_Title (W, "");
      else
         GLFW_Vulkan.Windows.Set_Title
           (W, New_Title.Text (1 .. New_Title.Length));
      end if;
      Last_Title := New_Title;
   end Apply_Title;

   function Is_Scrollback_Key
     (Event : GLFW_Vulkan.Input.Key_Event) return Boolean
   is
   begin
      return Event.Action /= GLFW_Vulkan.Input.Release
        and then Event.Modifiers.Shift
        and then
          (Event.Key = GLFW_Vulkan.Input.Page_Up
           or else Event.Key = GLFW_Vulkan.Input.Page_Down);
   end Is_Scrollback_Key;

   function Mouse_Button_Code
     (Button : GLFW_Vulkan.Input.Mouse_Button) return Natural
   is
   begin
      case Button is
         when GLFW_Vulkan.Input.Left   => return 0;
         when GLFW_Vulkan.Input.Middle => return 1;
         when GLFW_Vulkan.Input.Right  => return 2;
         when others                   => return 0;
      end case;
   end Mouse_Button_Code;

   procedure Run is
      Ctx : GLFW_Vulkan.Context;
      W   : GLFW_Vulkan.Windows.Window;
      Init_Status : GLFW_Vulkan.Init_Status;
      Window_Status : GLFW_Vulkan.Windows.Create_Status;
      T : Terminal.Core.Terminal;
      Core_Status : Terminal.Core.Initialize_Status;
      S : aliased Terminal.PTY.POSIX.Session;
      Spawn_Status : Terminal.PTY.POSIX.Spawn_Status;
      PTY_Q : aliased Terminal.App.Queues.PTY_Output_Queue;
      In_Q  : aliased Terminal.App.Queues.Input_Event_Queue;
      R     : Terminal.App.Renderer.Renderer;
      Vk_Ctx : Terminal.App.Vulkan_Context.Context;
      Vk_Status : Terminal.App.Vulkan_Context.Init_Status;
      Presenter : Terminal.App.Vulkan_Presenter.Presenter;
      Presenter_Status : Terminal.App.Vulkan_Presenter.Init_Status;
      Renderer_Status : Terminal.App.Renderer.Init_Status;
      FB_Width  : Natural := 0;
      FB_Height : Natural := 0;
      Last_Rows : Positive := 24;
      Last_Cols : Positive := 80;
      Need_Redraw : Boolean := True;
      Scroll_Offset : Natural := 0;
      Last_Title : Terminal.Core.Title_Text;
      Selection : Terminal.App.Selection.Selection_State;
      Mouse_Button_Down : Boolean := False;
      Mouse_Button_Code_Value : Natural := 0;
      Mouse_Modifiers : GLFW_Vulkan.Input.Modifier_Set;
   begin
      GLFW_Vulkan.Initialize (Ctx, Init_Status);
      if Init_Status /= GLFW_Vulkan.Ok then
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("glfw", GLFW_Vulkan.Init_Status'Image (Init_Status));
         return;
      end if;

      GLFW_Vulkan.Windows.Create (Ctx, W, 960, 600, "Ada Terminal", Window_Status);
      if Window_Status /= GLFW_Vulkan.Windows.Ok then
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("window", GLFW_Vulkan.Windows.Create_Status'Image (Window_Status));
         GLFW_Vulkan.Finalize (Ctx);
         return;
      end if;

      Terminal.App.Vulkan_Context.Initialize (Vk_Ctx, W, Vk_Status);
      if Vk_Status /= Terminal.App.Vulkan_Context.Ok then
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("vulkan-context",
            Terminal.App.Vulkan_Context.Init_Status'Image (Vk_Status));
         GLFW_Vulkan.Windows.Destroy (W);
         GLFW_Vulkan.Finalize (Ctx);
         return;
      end if;

      GLFW_Vulkan.Windows.Framebuffer_Size (W, FB_Width, FB_Height);
      Terminal.App.Vulkan_Presenter.Initialize
        (P              => Presenter,
         Context        => Vk_Ctx,
         Status         => Presenter_Status,
         Desired_Width  => FB_Width,
         Desired_Height => FB_Height);
      if Presenter_Status /= Terminal.App.Vulkan_Presenter.Ok then
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("vulkan-presenter",
            Terminal.App.Vulkan_Presenter.Init_Status'Image (Presenter_Status));
         Terminal.App.Vulkan_Context.Finalize (Vk_Ctx);
         GLFW_Vulkan.Windows.Destroy (W);
         GLFW_Vulkan.Finalize (Ctx);
         return;
      end if;

      Terminal.App.Renderer.Initialize (R, Vk_Ctx, Renderer_Status);
      Terminal.Core.Initialize (T, 24, 80, 10_000, Core_Status);
      Terminal.PTY.POSIX.Spawn_Default_Shell (S, 24, 80, Spawn_Status);

      if Core_Status /= Terminal.Core.Ok
        or else Spawn_Status /= Terminal.PTY.POSIX.Ok
        or else Renderer_Status /= Terminal.App.Renderer.Ok
      then
         if Core_Status /= Terminal.Core.Ok then
            Terminal.App.Diagnostics.Log_Startup_Failure
              ("terminal-core",
               Terminal.Core.Initialize_Status'Image (Core_Status));
         end if;
         if Spawn_Status /= Terminal.PTY.POSIX.Ok then
            Terminal.App.Diagnostics.Log_Startup_Failure
              ("pty",
               Terminal.PTY.POSIX.Spawn_Status'Image (Spawn_Status));
         end if;
         if Renderer_Status /= Terminal.App.Renderer.Ok then
            Terminal.App.Diagnostics.Log_Startup_Failure
              ("renderer",
               Terminal.App.Renderer.Init_Status'Image (Renderer_Status));
         end if;
         Terminal.PTY.POSIX.Close (S);
         Terminal.App.Vulkan_Presenter.Finalize (Presenter);
         Terminal.App.Vulkan_Context.Finalize (Vk_Ctx);
         GLFW_Vulkan.Windows.Destroy (W);
         GLFW_Vulkan.Finalize (Ctx);
         return;
      end if;

      Input_Queue := In_Q'Unchecked_Access;
      GLFW_Vulkan.Input.Set_Key_Callback (W, On_Key'Access);
      GLFW_Vulkan.Input.Set_Character_Callback (W, On_Character'Access);
      GLFW_Vulkan.Input.Set_Mouse_Button_Callback (W, On_Mouse_Button'Access);
      GLFW_Vulkan.Input.Set_Cursor_Position_Callback
        (W, On_Cursor_Position'Access);

      declare
         Reader_Task : Terminal.App.PTY_Reader.Reader
           (S'Unchecked_Access, PTY_Q'Unchecked_Access);
      begin
         while not GLFW_Vulkan.Windows.Should_Close (W) loop
            declare
               Chunk      : Terminal.App.Queues.Byte_Chunk;
               Has_Chunk  : Boolean;
               Event      : Terminal.App.Queues.Input_Event;
               Has_Event  : Boolean;
               Feed       : Terminal.Core.Feed_Status;
               Write_Stat : Terminal.App.PTY_Write.Write_All_Status;
               Dirty      : Boolean := Need_Redraw;
            begin
               GLFW_Vulkan.Events.Wait_Timeout (0.016);

               loop
                  PTY_Q.Pop (Chunk, Has_Chunk);
                  exit when not Has_Chunk;
                  if Chunk.Length > 0 then
                     Terminal.Core.Feed (T, Chunk.Data (1 .. Chunk.Length), Feed);
                     Scroll_Offset :=
                       Terminal.App.Scrollback_View.Clamp_Offset
                         (T, Scroll_Offset);
                     Dirty := True;
                  end if;
               end loop;
               Apply_Title (W, Terminal.Core.Title (T), Last_Title);

               while Terminal.Core.Pending_Response_Length (T) > 0 loop
                  Chunk := (others => <>);
                  Terminal.Core.Read_Response (T, Chunk.Data, Chunk.Length);
                  if Chunk.Length > 0 then
                     Terminal.App.PTY_Write.Write_All (S, Chunk, Write_Stat);
                     if Write_Stat /= Terminal.App.PTY_Write.Ok then
                        GLFW_Vulkan.Windows.Set_Should_Close (W, True);
                        exit;
                     end if;
                  end if;
               end loop;

               loop
                  In_Q.Pop (Event, Has_Event);
                  exit when not Has_Event;
                  case Event.Kind is
                     when Terminal.App.Queues.Key =>
                        if Is_Scrollback_Key (Event.Key_Event) then
                           if Terminal.App.Selection.Has_Selection (Selection) then
                              Terminal.App.Selection.Clear (Selection);
                           end if;
                           if Event.Key_Event.Key = GLFW_Vulkan.Input.Page_Up then
                              Scroll_Offset :=
                                Terminal.App.Scrollback_View.Clamp_Offset
                                  (T, Scroll_Offset + Last_Rows);
                           elsif Scroll_Offset > Last_Rows then
                              Scroll_Offset := Scroll_Offset - Last_Rows;
                           else
                              Scroll_Offset := 0;
                           end if;
                           Dirty := True;
                           Need_Redraw := True;
                           Chunk := (others => <>);
                        elsif Terminal.App.Input_Map.Is_Paste_Shortcut
                          (Event.Key_Event)
                        then
                           Scroll_Offset := 0;
                           if Terminal.App.Selection.Has_Selection (Selection) then
                              Terminal.App.Selection.Clear (Selection);
                              Dirty := True;
                           end if;
                           Terminal.App.Input_Map.Encode_Paste_Text
                             (GLFW_Vulkan.Clipboard.Get_Text (W),
                              Terminal.Core.Modes (T),
                              Chunk);
                        else
                           Scroll_Offset := 0;
                           if Terminal.App.Selection.Has_Selection (Selection) then
                              Terminal.App.Selection.Clear (Selection);
                              Dirty := True;
                           end if;
                           Terminal.App.Input_Map.Encode_Key
                             (Event.Key_Event, Terminal.Core.Modes (T), Chunk);
                        end if;
                     when Terminal.App.Queues.Character =>
                        Scroll_Offset := 0;
                        if Terminal.App.Selection.Has_Selection (Selection) then
                           Terminal.App.Selection.Clear (Selection);
                           Dirty := True;
                        end if;
                        Terminal.App.Input_Map.Encode_Character
                          (Event.Character_Event, Chunk);
                     when Terminal.App.Queues.Bytes =>
                        Chunk := Event.Bytes;
                     when Terminal.App.Queues.Mouse_Button =>
                        Chunk := (others => <>);
                        declare
                           Pos : constant Terminal.App.Selection.Cell_Position :=
                             Terminal.App.Selection.Cell_From_Pixels
                               (Event.Button_Event.X,
                                Event.Button_Event.Y,
                                Terminal.App.Renderer.Cell_Width (R),
                                Terminal.App.Renderer.Cell_Height (R),
                                Terminal.App.Renderer.Content_Margin,
                                Last_Rows,
                                Last_Cols);
                           Modes : constant Terminal.Core.Mode_Snapshot :=
                             Terminal.Core.Modes (T);
                        begin
                           if Terminal.App.Input_Map.Mouse_Reporting_Enabled
                             (Modes)
                           then
                              if Terminal.App.Selection.Has_Selection
                                (Selection)
                              then
                                 Terminal.App.Selection.Clear (Selection);
                                 Dirty := True;
                                 Need_Redraw := True;
                              end if;
                              Terminal.App.Input_Map.Encode_Mouse_Button
                                (Event.Button_Event, Modes, Pos.Row, Pos.Col, Chunk);
                              if Event.Button_Event.Action =
                                GLFW_Vulkan.Input.Press
                                and then Event.Button_Event.Button /=
                                  GLFW_Vulkan.Input.Other
                              then
                                 Mouse_Button_Down := True;
                                 Mouse_Button_Code_Value :=
                                   Mouse_Button_Code (Event.Button_Event.Button);
                                 Mouse_Modifiers := Event.Button_Event.Modifiers;
                              elsif Event.Button_Event.Action =
                                GLFW_Vulkan.Input.Release
                              then
                                 Mouse_Button_Down := False;
                                 Mouse_Modifiers := Event.Button_Event.Modifiers;
                              end if;
                           elsif Event.Button_Event.Button = GLFW_Vulkan.Input.Left
                           then
                              if Event.Button_Event.Action =
                                GLFW_Vulkan.Input.Press
                              then
                                 Terminal.App.Selection.Begin_Selection
                                   (Selection, Pos);
                                 Dirty := True;
                                 Need_Redraw := True;
                              elsif Event.Button_Event.Action =
                                GLFW_Vulkan.Input.Release
                              then
                                 Terminal.App.Selection.Finish_Selection
                                   (Selection, Pos);
                                 declare
                                    Copy_Snap : Terminal.Core.Render_Snapshot :=
                                      Terminal.App.Scrollback_View.Snapshot
                                        (T, Scroll_Offset);
                                    Text : constant String :=
                                      Terminal.App.Selection.Selected_Text
                                        (Copy_Snap, Selection);
                                 begin
                                    if Text'Length > 0 then
                                       GLFW_Vulkan.Clipboard.Set_Text (W, Text);
                                    end if;
                                    Terminal.Core.Release (Copy_Snap);
                                 end;
                                 Dirty := True;
                                 Need_Redraw := True;
                              end if;
                           end if;
                        end;
                     when Terminal.App.Queues.Cursor_Position =>
                        Chunk := (others => <>);
                        declare
                           Pos : constant Terminal.App.Selection.Cell_Position :=
                             Terminal.App.Selection.Cell_From_Pixels
                               (Event.Cursor_Event.X,
                                Event.Cursor_Event.Y,
                                Terminal.App.Renderer.Cell_Width (R),
                                Terminal.App.Renderer.Cell_Height (R),
                                Terminal.App.Renderer.Content_Margin,
                                Last_Rows,
                                Last_Cols);
                           Modes : constant Terminal.Core.Mode_Snapshot :=
                             Terminal.Core.Modes (T);
                        begin
                           if Terminal.App.Input_Map.Mouse_Reporting_Enabled
                             (Modes)
                           then
                              Terminal.App.Input_Map.Encode_Mouse_Motion
                                (Event.Cursor_Event,
                                 Modes,
                                 Pos.Row,
                                 Pos.Col,
                                 Mouse_Button_Down,
                                 Mouse_Button_Code_Value,
                                 Mouse_Modifiers,
                                 Chunk);
                           elsif Terminal.App.Selection.Is_Active (Selection) then
                              Terminal.App.Selection.Update_Selection
                                (Selection, Pos);
                              Dirty := True;
                              Need_Redraw := True;
                           end if;
                        end;
                     when Terminal.App.Queues.Close_Request =>
                        GLFW_Vulkan.Windows.Set_Should_Close (W, True);
                        Chunk := (others => <>);
                     when Terminal.App.Queues.Resize_Request =>
                        Chunk := (others => <>);
                  end case;

                  if Chunk.Length > 0 then
                     Terminal.App.PTY_Write.Write_All (S, Chunk, Write_Stat);
                     if Write_Stat /= Terminal.App.PTY_Write.Ok then
                        GLFW_Vulkan.Windows.Set_Should_Close (W, True);
                     end if;
                  end if;
               end loop;

               GLFW_Vulkan.Windows.Framebuffer_Size (W, FB_Width, FB_Height);
               Terminal.App.Renderer.Set_Framebuffer_Size
                 (R, FB_Width, FB_Height);
               if FB_Width > 0 and then FB_Height > 0 then
                  declare
                     New_Rows : Positive;
                     New_Cols : Positive;
                     Core_Resize : Terminal.Core.Resize_Status;
                     PTY_Resize  : Terminal.PTY.POSIX.Resize_Status;
                  begin
                     Terminal.App.Resize.Pixels_To_Cells
                       (FB_Width,
                        FB_Height,
                        Terminal.App.Renderer.Cell_Width (R),
                        Terminal.App.Renderer.Cell_Height (R),
                        Terminal.App.Renderer.Content_Margin,
                        New_Rows,
                        New_Cols);
                     if New_Rows /= Last_Rows or else New_Cols /= Last_Cols then
                        Terminal.Core.Resize (T, New_Rows, New_Cols, Core_Resize);
                        Terminal.PTY.POSIX.Resize (S, New_Rows, New_Cols, PTY_Resize);
                        if Core_Resize = Terminal.Core.Ok
                          and then PTY_Resize = Terminal.PTY.POSIX.Ok
                        then
                           Last_Rows := New_Rows;
                           Last_Cols := New_Cols;
                           Scroll_Offset :=
                             Terminal.App.Scrollback_View.Clamp_Offset
                               (T, Scroll_Offset);
                           Terminal.App.Selection.Clear (Selection);
                           Dirty := True;
                           Need_Redraw := True;
                        end if;
                     end if;
                  end;
               end if;

               if Dirty then
                  declare
                     Snap : Terminal.Core.Render_Snapshot :=
                       Terminal.App.Scrollback_View.Snapshot
                         (T, Scroll_Offset);
                     Render_Status : Terminal.App.Renderer.Render_Status;
                     Present_Status : Terminal.App.Vulkan_Presenter.Present_Status;
                     Can_Present : Boolean := True;
                  begin
                     Terminal.App.Selection.Apply_To_Snapshot (Snap, Selection);
                     if not
                       Terminal.App.Vulkan_Presenter.Diagnostics
                         (Presenter).Initialized
                     then
                        GLFW_Vulkan.Windows.Framebuffer_Size
                          (W, FB_Width, FB_Height);
                        if FB_Width > 0 and then FB_Height > 0 then
                           Terminal.App.Vulkan_Presenter.Initialize
                             (P              => Presenter,
                              Context        => Vk_Ctx,
                              Status         => Presenter_Status,
                              Desired_Width  => FB_Width,
                              Desired_Height => FB_Height);
                           if Presenter_Status /=
                             Terminal.App.Vulkan_Presenter.Ok
                           then
                              GLFW_Vulkan.Windows.Set_Should_Close (W, True);
                              Can_Present := False;
                           end if;
                        else
                           Present_Status :=
                             Terminal.App.Vulkan_Presenter.Swapchain_Out_Of_Date;
                           Can_Present := False;
                        end if;
                     end if;

                     if Can_Present then
                        Terminal.App.Renderer.Render (R, Snap, Render_Status);
                        if Render_Status = Terminal.App.Renderer.Ok then
                           Terminal.App.Renderer.Present
                             (R, Vk_Ctx, Presenter, Present_Status);
                        else
                           Present_Status := Terminal.App.Vulkan_Presenter.Invalid_Batch;
                        end if;
                     else
                        Render_Status := Terminal.App.Renderer.Not_Initialized;
                     end if;
                     if Present_Status =
                       Terminal.App.Vulkan_Presenter.Swapchain_Out_Of_Date
                     then
                        Terminal.App.Vulkan_Presenter.Finalize (Presenter);
                        GLFW_Vulkan.Windows.Framebuffer_Size
                          (W, FB_Width, FB_Height);
                        if FB_Width = 0 or else FB_Height = 0 then
                           Need_Redraw := True;
                        else
                           Terminal.App.Vulkan_Presenter.Initialize
                             (P              => Presenter,
                              Context        => Vk_Ctx,
                              Status         => Presenter_Status,
                              Desired_Width  => FB_Width,
                              Desired_Height => FB_Height);
                           Need_Redraw :=
                             Presenter_Status = Terminal.App.Vulkan_Presenter.Ok;
                           if Presenter_Status /=
                             Terminal.App.Vulkan_Presenter.Ok
                           then
                              GLFW_Vulkan.Windows.Set_Should_Close (W, True);
                           end if;
                        end if;
                     end if;
                     declare
                        Diag : constant Terminal.App.Diagnostics.Snapshot :=
                          Terminal.App.Diagnostics.Collect
                            (T, PTY_Q, In_Q, R, Presenter);
                     begin
                        Terminal.App.Diagnostics.Log_If_Changed (Diag);
                     end;
                     Terminal.Core.Release (Snap);
                     if Render_Status = Terminal.App.Renderer.Ok
                       and then
                         (Present_Status = Terminal.App.Vulkan_Presenter.Ok
                          or else Present_Status =
                            Terminal.App.Vulkan_Presenter.Validated_Not_Presented)
                     then
                        Terminal.Core.Clear_Damage (T);
                        Need_Redraw := False;
                     elsif Present_Status /=
                       Terminal.App.Vulkan_Presenter.Swapchain_Out_Of_Date
                     then
                        Need_Redraw := False;
                     end if;
                  end;
               end if;
            end;
         end loop;

         Reader_Task.Stop;
         Terminal.PTY.POSIX.Close (S);
      end;

      Input_Queue := null;
      Terminal.App.Renderer.Finalize (R);
      Terminal.App.Vulkan_Presenter.Finalize (Presenter);
      Terminal.App.Vulkan_Context.Finalize (Vk_Ctx);
      GLFW_Vulkan.Windows.Destroy (W);
      GLFW_Vulkan.Finalize (Ctx);
   end Run;
end Terminal.App.Main_Loop;

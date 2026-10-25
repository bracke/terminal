separate (Terminal.App.Main_Loop.Run)
   procedure Run_Frame is
      Chunk      : Terminal.App.Queues.Byte_Chunk;
      Event      : Terminal.App.Queues.Input_Event;
      Has_Event  : Boolean;
      Write_Stat : Terminal.App.PTY_Write.Write_All_Status;
      Dirty      : Boolean := Need_Redraw;
      Local_Redraw : Boolean := False;
      Current_Blink_Tick : Natural := Last_Blink_Tick;

      procedure Handle_Input_Event (Stop : out Boolean) is separate;
      procedure Poll_Backends is separate;
      procedure Resize_Surface is separate;

      procedure Handle_Present_Status
        (Status : Terminal.App.Vulkan_Presenter.Present_Status) is
      begin
         if Status in
           Terminal.App.Vulkan_Presenter.Swapchain_Out_Of_Date
             | Terminal.App.Vulkan_Presenter.Device_Lost
         then
            Terminal.App.Vulkan_Presenter.Finalize (Presenter);
            Terminal.App.Vulkan_Recovery.Begin_Recovery
              (Vulkan_Recovery,
               (if Status = Terminal.App.Vulkan_Presenter.Device_Lost
                then Terminal.App.Vulkan_Recovery.Device_Lost
                else Terminal.App.Vulkan_Recovery.Swapchain_Invalid),
               Recovery_Tick);
            Need_Redraw := True;
         elsif Status = Terminal.App.Vulkan_Presenter.Resources_In_Flight then
            Need_Redraw := True;
         end if;
      end Handle_Present_Status;
   begin
      if Recovery_Tick < Natural'Last then
         Recovery_Tick := Recovery_Tick + 1;
      end if;
      --  Wait a frame's worth instead of spinning at ~60 fps. Present is
      --  already skipped for unchanged frames, so this timeout alone sets
      --  the idle rate and a short fixed wait keeps it cheap. Do not sleep
      --  longer when idle: once we stop presenting, nothing drives
      --  compositor wakeups, so a long block genuinely delays input. A
      --  frame's wait still catches each cursor/text blink edge within a
      --  frame (checked just below; present-skip drops the between frames),
      --  and input and PTY output (via Post_Empty_Event) wake it at once.
      GLFW_Vulkan.Events.Wait_Timeout (0.016);

      Current_Blink_Tick :=
        Terminal.App.Cursor_Blink.Tick
          (Ada.Real_Time.To_Duration
             (Ada.Real_Time.Clock - Blink_Origin));
      if Current_Blink_Tick /= Last_Blink_Tick
        and then
          (Terminal.Core.Modes (Active_Core.all).Cursor_Blinking
           or else Blinking_Text_Active)
      then
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      end if;
      Last_Blink_Tick := Current_Blink_Tick;

      Poll_Backends;
      Scroll_Offset :=
        Terminal.App.Scrollback_View.Clamp_Offset
          (Active_Core.all, Scroll_Offset);
      Apply_Title
        (W,
         Terminal.Core.Title (Active_Core.all),
         Hovered_Link,
         Has_Link_Activation,
         Link_Activation,
         Tabs,
         Splits);
      declare
         Clipboard_Ok : Boolean;
      begin
         Apply_Clipboard_Request
           (W,
            Active_Runtime.all,
            Clipboard_Targets,
            Active_Core.all,
            Clipboard_Ok,
            Last_Write_Status,
            Last_Clipboard_Target);
         if not Clipboard_Ok then
            if Terminal.App.Session_Table.Count (Sessions) = 1 then
               GLFW_Vulkan.Windows.Set_Should_Close (W, True);
            end if;
         end if;
      end;

      loop
         exit when Terminal.App.Session_Runtime.State
           (Active_Runtime.all) /= Terminal.App.Session_Runtime.Active;
         exit when Terminal.App.Session_Runtime.Has_Pending_Write
           (Active_Runtime.all);
         In_Q.Pop (Event, Has_Event);
         exit when not Has_Event;
         declare
            Stop : Boolean;
         begin
            Handle_Input_Event (Stop);
            exit when Stop;
         end;
      end loop;

      Resize_Surface;

      declare
         Render_Policy_Status : constant String :=
           Terminal.App.Render_Policy.Status_Label
             (Modes                => Terminal.Core.Modes (Active_Core.all),
              Scrollback_Offset    => Scroll_Offset,
              Selection_Active     =>
                Terminal.App.Selection.Has_Selection (Selection),
              Local_Redraw_Request => Local_Redraw);
         --  Whether the input grace window is still open this frame; while
         --  it is we present unconditionally (bypassing the defer policy)
         --  so the compositor keeps waking us and input stays responsive.
         Grace_Active : constant Boolean := Input_Grace > 0;
      begin
      if Input_Grace > 0 then
         Input_Grace := Input_Grace - 1;
      end if;
      if Dirty
        and then not Grace_Active
        and then Terminal.App.Render_Policy.Should_Defer_Render
          (Modes                => Terminal.Core.Modes (Active_Core.all),
           Scrollback_Offset    => Scroll_Offset,
           Selection_Active     =>
             Terminal.App.Selection.Has_Selection (Selection),
           Local_Redraw_Request => Local_Redraw)
      then
         Need_Redraw := True;
      elsif Grace_Active
        and then not Dirty
        and then
          Terminal.App.Vulkan_Presenter.Is_Initialized (Presenter)
      then
         --  Input grace exists to keep presenting on the compositor's
         --  frame clock.  The terminal state has not changed, so reuse
         --  the existing renderer batch instead of rebuilding terminal
         --  snapshots, image tiles, and Vulkan vertices 24 times.
         declare
            Present_Status :
              Terminal.App.Vulkan_Presenter.Present_Status;
         begin
            Terminal.App.Renderer.Present_Retained
              (R, Vk_Ctx, Presenter, Present_Status);
            Handle_Present_Status (Present_Status);
         end;
      elsif Dirty or else Grace_Active then
         declare
            Visible_Count : constant Positive :=
              (if Terminal.App.Splits.Count (Splits) > 1
               then Positive (Terminal.App.Splits.Count (Splits))
               else 1);
            Active_Render_Index : constant Positive :=
              (if Terminal.App.Splits.Count (Splits) > 1
               then Positive (Terminal.App.Splits.Active (Splits))
               else 1);
            Snaps : Terminal.App.Renderer.Snapshot_Array renames
              Snapshot_Cache (1 .. Visible_Count);
            Render_Status : Terminal.App.Renderer.Render_Status;
            Present_Status : Terminal.App.Vulkan_Presenter.Present_Status;
            Can_Present : Boolean := True;
         begin
            Resize_Visible_Runtimes;
            for I in Snaps'Range loop
               declare
                  Runtime : constant access
                    Terminal.App.Session_Runtime.Runtime :=
                      (if Visible_Count = 1
                       then Active_Runtime
                       else Terminal.App.Session_Table.Runtime_At
                         (Sessions,
                          Terminal.App.Sessions.Session_Index (I)));
                  Core : constant access Terminal.Core.Terminal :=
                    (if Runtime = null
                     then Active_Core
                     else Terminal.App.Session_Runtime.Core
                       (Runtime.all));
               begin
                  if Runtime = null then
                     Terminal.App.Scrollback_View.Snapshot
                       (Active_Core.all, 0, Snaps (I));
                  else
                     Terminal.App.Scrollback_View.Snapshot
                       (Terminal.App.Session_Runtime.Core
                          (Runtime.all).all,
                        (if I = Active_Render_Index
                         then Scroll_Offset
                         else 0),
                        Snaps (I));
                  end if;

                  --  Render the oldest unconsumed graphics command.
                  --  It is acknowledged only after a successful
                  --  presentation, so swapchain retries cannot lose
                  --  protocol events.
                  if I /= Active_Render_Index
                    or else Scroll_Offset = 0
                  then
                     Terminal.Core.Peek_Graphics_Event
                       (Core.all, Snaps (I).Graphics);
                     if Snaps (I).Graphics.Pending
                       and then Snaps (I).Graphics.Payload_Length >
                         Snaps (I).Graphics.Preview_Length
                     then
                        Terminal.App.Renderer.Stage_Graphics_Event
                          (R,
                           Snaps (I).Graphics,
                           Terminal.Core.Graphics_Event_Payload
                             (Core.all, Snaps (I).Graphics));
                     end if;
                  else
                     Snaps (I).Graphics := (others => <>);
                  end if;
               end;
            end loop;

            Terminal.App.Selection.Apply_To_Snapshot
              (Snaps (Active_Render_Index), Selection);
            Blinking_Text_Active :=
              Terminal.App.Text_Blink.Contains_Blinking_Text
                (Snaps (Active_Render_Index));
            for I in Snaps'Range loop
               Terminal.App.Text_Blink.Apply
                 (Snaps (I), Current_Blink_Tick);
               Terminal.App.Cursor_Blink.Apply
                 (Snaps (I), Current_Blink_Tick);
            end loop;
            if not Terminal.App.Vulkan_Presenter.Is_Initialized
              (Presenter)
            then
               GLFW_Vulkan.Windows.Framebuffer_Size
                 (W, FB_Width, FB_Height);
               if FB_Width > 0 and then FB_Height > 0 then
                  if not Terminal.App.Vulkan_Recovery.Is_Pending
                    (Vulkan_Recovery)
                  then
                     Terminal.App.Vulkan_Recovery.Begin_Recovery
                       (Vulkan_Recovery,
                        Terminal.App.Vulkan_Recovery
                          .Swapchain_Invalid,
                        Recovery_Tick);
                  end if;
                  if Terminal.App.Vulkan_Recovery.Attempt_Due
                    (Vulkan_Recovery, Recovery_Tick)
                  then
                     Terminal.App.Vulkan_Presenter.Initialize
                       (P              => Presenter,
                        Context        => Vk_Ctx,
                        Status         => Presenter_Status,
                        Desired_Width  => FB_Width,
                        Desired_Height => FB_Height);
                     Terminal.App.Vulkan_Recovery.Record_Attempt
                       (Vulkan_Recovery,
                        Recovery_Tick,
                        Presenter_Status =
                          Terminal.App.Vulkan_Presenter.Ok);
                     if Presenter_Status /=
                       Terminal.App.Vulkan_Presenter.Ok
                     then
                        --  Creation routines clean their own partial
                        --  work; Finalize also makes that guarantee
                        --  explicit before the next retry.
                        Terminal.App.Vulkan_Presenter.Finalize
                          (Presenter);
                        Present_Status :=
                          Terminal.App.Vulkan_Presenter
                            .Not_Initialized;
                        Can_Present := False;
                     end if;
                  else
                     Present_Status :=
                       Terminal.App.Vulkan_Presenter.Not_Initialized;
                     Can_Present := False;
                  end if;
               else
                  Present_Status :=
                    Terminal.App.Vulkan_Presenter.Swapchain_Out_Of_Date;
                  Can_Present := False;
               end if;
            end if;

            if Can_Present then
               Terminal.App.Renderer.Render_App
                 (R,
                  Snaps,
                  Active_Render_Index,
                  Terminal.App.Tabs.Snapshot (Tabs),
                  Terminal.App.Splits.Snapshot (Splits),
                  Render_Status);
               if Render_Status = Terminal.App.Renderer.Ok then
                  Terminal.App.Renderer.Present
                    (R, Vk_Ctx, Presenter, Present_Status);
               else
                  Present_Status := Terminal.App.Vulkan_Presenter.Invalid_Batch;
               end if;
            else
               Render_Status := Terminal.App.Renderer.Not_Initialized;
            end if;
            Handle_Present_Status (Present_Status);
            declare
               Grid_Status : constant String :=
                 Terminal.App.Resize.Grid_Status_Label
                   (FB_Width,
                    FB_Height,
                    Terminal.App.Renderer.Cell_Width (R),
                    Terminal.App.Renderer.Cell_Height (R),
                    Terminal.App.Renderer.Content_Margin);
               Scrollback_Status : constant String :=
                 Terminal.App.Scrollback_View.Status_Label
                   (Active_Core.all, Scroll_Offset);
               Selection_Status : constant String :=
                 Terminal.App.Selection.Status_Label (Selection);
               Link_Status : constant String :=
                 Terminal.App.Hyperlinks.Status_Label (Hovered_Link);
               Link_Activation_Status : constant String :=
                 Terminal.App.Hyperlinks.Activation_Status_Label
                   (if Has_Link_Activation
                    then Link_Activation
                    else Terminal.App.Hyperlinks.No_Link);
               Clipboard_Status : constant String :=
                 Terminal.App.Clipboard_OSC52.Status_Label
                   (Last_Clipboard_Target);
               Tab_Status : constant String :=
                 Terminal.App.Tabs.Status_Label (Tabs);
               Split_Status : constant String :=
                 Terminal.App.Splits.Status_Label (Splits);
               Config_Status : constant String :=
                 Terminal.App.Config.Status_Label (App_Config);
               Profile_Status : constant String :=
                 Terminal.App.Profile_Status_Label
                   (Terminal.App.Profile);
               Input_Status : constant String :=
                 Terminal.App.Input_Map.Input_Status_Label
                   (Terminal.Core.Modes (Active_Core.all));
               Mouse_Status : constant String :=
                 Terminal.App.Input_Map.Mouse_Status_Label
                   (Terminal.Core.Modes (Active_Core.all));
               Cursor_Status : constant String :=
                 Terminal.App.Cursor_Blink.Status_Label
                   (Snaps (Active_Render_Index).Cursor,
                    Current_Blink_Tick);
               Text_Blink_Status : constant String :=
                 Terminal.App.Text_Blink.Status_Label
                   (Snaps (Active_Render_Index), Current_Blink_Tick);
               Theme_Status : constant String :=
                 Terminal.App.Theme.Status_Label
                   (App_Config.Color_Theme);
               Graphics_Header_Status : constant String :=
                 Terminal.App.Graphics.Header_Status_Label
                   (Snaps (Active_Render_Index).Graphics);
               Graphics_Data_Status : constant String :=
                 Terminal.App.Graphics.Data_Status_Label
                   (Snaps (Active_Render_Index).Graphics);
               Statuses : Terminal.App.Diagnostics.Runtime_Statuses :=
                 (others => <>);
               Diag : Terminal.App.Diagnostics.Snapshot;
            begin
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Grid_Status, Grid_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Policy_Status,
                  Render_Policy_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Scrollback_Status,
                  Scrollback_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Selection_Status,
                  Selection_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Link_Status, Link_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Link_Activation_Status,
                  Link_Activation_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Clipboard_Status,
                  Clipboard_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Tab_Status, Tab_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Split_Status,
                  Split_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Config_Status,
                  Config_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Profile_Status,
                  Profile_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Input_Status,
                  Input_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Mouse_Status,
                  Mouse_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Cursor_Status,
                  Cursor_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Text_Blink_Status,
                  Text_Blink_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Theme_Status,
                  Theme_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Font_Status,
                  Runtime_Font_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.PTY_Backend_Status,
                  Runtime_PTY_Backend_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.ConPTY_Status,
                  Runtime_ConPTY_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Multiplexer_Status,
                  Runtime_Multiplexer_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Graphics_Header_Status,
                  Graphics_Header_Status);
               Terminal.App.Diagnostics.Set
                 (Statuses, Terminal.App.Diagnostics.Graphics_Data_Status,
                  Graphics_Data_Status);
               Diag := Terminal.App.Diagnostics.Collect
                 (Active_Core.all,
                  Active_PTY_Queue.all,
                  In_Q,
                  R,
                  Presenter,
                  Last_Feed_Status,
                  Last_Write_Status,
                  Statuses);
               Terminal.App.Diagnostics.Log_If_Changed (Diag);
            end;
            if Render_Status = Terminal.App.Renderer.Ok
              and then
                (Present_Status = Terminal.App.Vulkan_Presenter.Ok
                 or else Present_Status =
                   Terminal.App.Vulkan_Presenter.Validated_Not_Presented)
            then
               declare
                  More_Graphics : Boolean := False;
               begin
                  for I in Snaps'Range loop
                     declare
                        Runtime : constant access
                          Terminal.App.Session_Runtime.Runtime :=
                            (if Visible_Count = 1
                             then Active_Runtime
                             else Terminal.App.Session_Table.Runtime_At
                               (Sessions,
                                Terminal.App.Sessions.Session_Index
                                  (I)));
                        Core : constant access Terminal.Core.Terminal :=
                          (if Runtime = null
                           then Active_Core
                           else Terminal.App.Session_Runtime.Core
                             (Runtime.all));
                        Response_Runtime : constant access
                          Terminal.App.Session_Runtime.Runtime :=
                            (if Runtime = null
                             then Active_Runtime
                             else Runtime);
                     begin
                        if (I /= Active_Render_Index
                            or else Scroll_Offset = 0)
                        then
                           Terminal.Core.Complete_Graphics_Event
                             (Core.all,
                              Snaps (I).Graphics,
                              Terminal.App.Renderer.Graphics_Result
                                (R, Snaps (I).Graphics));
                           while not Terminal.App.Session_Runtime
                             .Has_Pending_Write (Response_Runtime.all)
                             and then
                               Terminal.Core.Pending_Response_Length
                                 (Core.all) > 0
                           loop
                              Chunk := (others => <>);
                              Terminal.Core.Read_Response
                                (Core.all,
                                 Chunk.Data,
                                 Chunk.Length);
                              exit when Chunk.Length = 0;
                              Terminal.App.Session_Runtime.Write
                                (Response_Runtime.all,
                                 Chunk,
                                 Write_Stat);
                              Last_Write_Status := Write_Stat;
                              if Fatal_Write (Write_Stat) then
                                 if Terminal.App.Session_Table.Count
                                   (Sessions) = 1
                                 then
                                    GLFW_Vulkan.Windows.Set_Should_Close
                                      (W, True);
                                 end if;
                                 exit;
                              elsif Write_Stat =
                                Terminal.App.PTY_Write.Incomplete
                              then
                                 exit;
                              end if;
                           end loop;
                        end if;
                        --  The active pane's graphics queue is
                        --  intentionally suspended while displaying
                        --  scrollback.  Do not turn that suspended
                        --  work into an immediate redraw request: it
                        --  would spin continuously without consuming
                        --  the event.  Returning to the live view is
                        --  itself a redraw request and resumes it.
                        if I /= Active_Render_Index
                          or else Scroll_Offset = 0
                        then
                           More_Graphics := More_Graphics
                             or else
                               Terminal.Core
                                 .Pending_Graphics_Event_Count
                                   (Core.all) > 0;
                        end if;
                     end;
                  end loop;
                  Terminal.App.Renderer.Commit_Graphics_Events (R);
                  Need_Redraw := More_Graphics;
               end;
               Terminal.Core.Clear_Damage (Active_Core.all);
            elsif Present_Status not in
              Terminal.App.Vulkan_Presenter.Swapchain_Out_Of_Date
                | Terminal.App.Vulkan_Presenter.Device_Lost
                | Terminal.App.Vulkan_Presenter.Resources_In_Flight
            then
               Need_Redraw :=
                 Terminal.App.Vulkan_Recovery.Is_Pending
                   (Vulkan_Recovery);
            elsif Present_Status =
              Terminal.App.Vulkan_Presenter.Resources_In_Flight
            then
               --  A submitted frame still owns the shared descriptor
               --  or vertex resources. Retry after its fence signals.
               Need_Redraw := True;
            end if;
         end;
      end if;
      end;
   end Run_Frame;


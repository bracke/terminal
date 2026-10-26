separate (Terminal.App.Main_Loop.Run)
   procedure Run_Frame is
      Chunk      : Terminal.App.Queues.Byte_Chunk;
      Event      : Terminal.App.Queues.Input_Event;
      Has_Event  : Boolean;
      Write_Stat : Terminal.App.PTY_Write.Write_All_Status;
      Dirty      : Boolean := Need_Redraw;
      Local_Redraw : Boolean := False;
      Current_Blink_Tick : Natural := Last_Blink_Tick;

      function Frame_Diagnostic_Statuses
        (Snaps                : Terminal.App.Renderer.Snapshot_Array;
         Active_Render_Index  : Positive;
         Render_Policy_Status : String)
         return Terminal.App.Diagnostics.Runtime_Statuses
      is
         Statuses : Terminal.App.Diagnostics.Runtime_Statuses := (others => <>);

         procedure Set
           (Kind : Terminal.App.Diagnostics.Runtime_Status_Kind;
            Text : String) is
         begin
            Terminal.App.Diagnostics.Set (Statuses, Kind, Text);
         end Set;
      begin
         Set
           (Terminal.App.Diagnostics.Grid_Status,
            Terminal.App.Resize.Grid_Status_Label
              (FB_Width,
               FB_Height,
               Terminal.App.Renderer.Cell_Width (R),
               Terminal.App.Renderer.Cell_Height (R),
               Terminal.App.Renderer.Content_Margin));
         Set (Terminal.App.Diagnostics.Policy_Status, Render_Policy_Status);
         Set
           (Terminal.App.Diagnostics.Scrollback_Status,
            Terminal.App.Scrollback_View.Status_Label
              (Active_Core.all, Scroll_Offset));
         Set
           (Terminal.App.Diagnostics.Selection_Status,
            Terminal.App.Selection.Status_Label (Selection));
         Set
           (Terminal.App.Diagnostics.Link_Status,
            Terminal.App.Hyperlinks.Status_Label (Hovered_Link));
         Set
           (Terminal.App.Diagnostics.Link_Activation_Status,
            Terminal.App.Hyperlinks.Activation_Status_Label
              (if Has_Link_Activation
               then Link_Activation
               else Terminal.App.Hyperlinks.No_Link));
         Set
           (Terminal.App.Diagnostics.Clipboard_Status,
            Terminal.App.Clipboard_OSC52.Status_Label
              (Last_Clipboard_Target));
         Set
           (Terminal.App.Diagnostics.Tab_Status,
            Terminal.App.Tabs.Status_Label (Tabs));
         Set
           (Terminal.App.Diagnostics.Split_Status,
            Terminal.App.Splits.Status_Label (Splits));
         Set
           (Terminal.App.Diagnostics.Config_Status,
            Terminal.App.Config.Status_Label (App_Config));
         Set
           (Terminal.App.Diagnostics.Profile_Status,
            Terminal.App.Profile_Status_Label (Terminal.App.Profile));
         Set
           (Terminal.App.Diagnostics.Input_Status,
            Terminal.App.Input_Map.Input_Status_Label
              (Terminal.Core.Modes (Active_Core.all)));
         Set
           (Terminal.App.Diagnostics.Mouse_Status,
            Terminal.App.Input_Map.Mouse_Status_Label
              (Terminal.Core.Modes (Active_Core.all)));
         Set
           (Terminal.App.Diagnostics.Cursor_Status,
            Terminal.App.Cursor_Blink.Status_Label
              (Snaps (Active_Render_Index).Cursor, Current_Blink_Tick));
         Set
           (Terminal.App.Diagnostics.Text_Blink_Status,
            Terminal.App.Text_Blink.Status_Label
              (Snaps (Active_Render_Index), Current_Blink_Tick));
         Set
           (Terminal.App.Diagnostics.Theme_Status,
            Terminal.App.Theme.Status_Label (App_Config.Color_Theme));
         Set (Terminal.App.Diagnostics.Font_Status, Runtime_Font_Status);
         Set
           (Terminal.App.Diagnostics.PTY_Backend_Status,
            Runtime_PTY_Backend_Status);
         Set
           (Terminal.App.Diagnostics.ConPTY_Status,
            Runtime_ConPTY_Status);
         Set
           (Terminal.App.Diagnostics.Multiplexer_Status,
            Runtime_Multiplexer_Status);
         Set
           (Terminal.App.Diagnostics.Graphics_Header_Status,
            Terminal.App.Graphics.Header_Status_Label
              (Snaps (Active_Render_Index).Graphics));
         Set
           (Terminal.App.Diagnostics.Graphics_Data_Status,
            Terminal.App.Graphics.Data_Status_Label
              (Snaps (Active_Render_Index).Graphics));
         return Statuses;
      end Frame_Diagnostic_Statuses;

      type Frame_Completion_Result is record
         Redraw          : Boolean;
         Write_Attempted : Boolean := False;
         Write_Status    : Terminal.App.PTY_Write.Write_All_Status :=
           Terminal.App.PTY_Write.Ok;
         Close_Window    : Boolean := False;
      end record;

      procedure Handle_Input_Event (Stop : out Boolean) is separate;
      procedure Poll_Backends is separate;
      procedure Resize_Surface is separate;
      procedure Log_Frame_Diagnostics
        (Current_Core         : Terminal.Core.Terminal;
         PTY_Queue            : Terminal.App.Queues.PTY_Output_Queue;
         Input_Queue          : Terminal.App.Queues.Input_Event_Queue;
         Renderer_State       : Terminal.App.Renderer.Renderer;
         Presenter_State      : Terminal.App.Vulkan_Presenter.Presenter;
         Feed_Status          : Terminal.Core.Feed_Status;
         Write_Status         : Terminal.App.PTY_Write.Write_All_Status;
         Statuses             : Terminal.App.Diagnostics.Runtime_Statuses)
      is separate;
      procedure Complete_Frame_Graphics
        (Snaps               : Terminal.App.Renderer.Snapshot_Array;
         Active_Render_Index : Positive;
         Render_Status       : Terminal.App.Renderer.Render_Status;
         Present_Status      : Terminal.App.Vulkan_Presenter.Present_Status;
         Runtime_Table       : Terminal.App.Session_Table.Runtime_Table;
         Current_Runtime     : not null access
           Terminal.App.Session_Runtime.Runtime;
         Scrollback_Offset   : Natural;
         Renderer_State      : in out Terminal.App.Renderer.Renderer;
         Recovery_Pending    : Boolean;
         Result              : in out Frame_Completion_Result)
      is separate;

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
            Completion : Frame_Completion_Result :=
              (Redraw => Need_Redraw, others => <>);
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
            --  Handle_Present_Status may start recovery and request another
            --  frame.  Preserve that decision when completion has no more
            --  specific redraw result for this presentation status.
            Completion.Redraw := Need_Redraw;
            Log_Frame_Diagnostics
              (Active_Core.all,
               Active_PTY_Queue.all,
               In_Q,
               R,
               Presenter,
               Last_Feed_Status,
               Last_Write_Status,
               Frame_Diagnostic_Statuses
                 (Snaps, Active_Render_Index, Render_Policy_Status));
            Complete_Frame_Graphics
              (Snaps,
               Active_Render_Index,
               Render_Status,
               Present_Status,
               Sessions,
               Active_Runtime,
               Scroll_Offset,
               R,
               Terminal.App.Vulkan_Recovery.Is_Pending (Vulkan_Recovery),
               Completion);
            Need_Redraw := Completion.Redraw;
            if Completion.Write_Attempted then
               Last_Write_Status := Completion.Write_Status;
            end if;
            if Completion.Close_Window then
               GLFW_Vulkan.Windows.Set_Should_Close (W, True);
            end if;
         end;
      end if;
      end;
   end Run_Frame;


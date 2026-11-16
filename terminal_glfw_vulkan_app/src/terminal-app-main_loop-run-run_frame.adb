with Terminal.Core.Snapshot_Editing;
separate (Terminal.App.Main_Loop.Run)
   procedure Run_Frame is
      use type Terminal.App.Renderer.Graphics.Stage_Event_Status;
      Chunk      : Terminal.App.Queues.Byte_Chunk;
      Event      : Terminal.App.Queues.Input_Event;
      Has_Event  : Boolean;
      Write_Stat : Terminal.App.PTY_Write.Write_All_Status;
      Dirty      : Boolean := Need_Redraw;
      Local_Redraw : Boolean := False;
      Current_Blink_Tick : Natural := Last_Blink_Tick;

      function Shell_Quote (Value : String) return String is
         Result : String (1 .. Value'Length * 5 + 2);
         Last : Natural := 1;
      begin
         Result (1) := ''';
         for Ch of Value loop
            if Ch = ''' then
               Result (Last + 1 .. Last + 5) := "'""'""'";
               Last := Last + 5;
            else
               Last := Last + 1;
               Result (Last) := Ch;
            end if;
         end loop;
         Last := Last + 1;
         Result (Last) := ''';
         return Result (1 .. Last);
      end Shell_Quote;

      procedure Handle_Dropped_Files is
         Value : Terminal.App.File_Drop.Path_Value;
         Available : Boolean;
         Status : Terminal.App.PTY_Write.Write_All_Status;
         Modes : constant Terminal.Core.Mode_Snapshot :=
           Terminal.App.Session_Runtime.Modes (Active_Core);
      begin
         loop
            Terminal.App.File_Drop.Poll (Value, Available);
            exit when not Available;
            if not Read_Only and then Terminal.App.File_Drop.Text (Value) /= "" then
               Terminal.App.Session_Table.Write_Paste
                 (Active_Runtime,
                  Shell_Quote (Terminal.App.File_Drop.Text (Value)) & " ",
                  Modes.Bracketed_Paste,
                  Status);
               Last_Write_Status := Status;
               exit when Status /= Terminal.App.PTY_Write.Ok;
            end if;
         end loop;
      end Handle_Dropped_Files;

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
         procedure Set_Scrollback
           (Core : in out Terminal.Core.Terminal) is
         begin
            Set
              (Terminal.App.Diagnostics.Scrollback_Status,
               Terminal.App.Scrollback_View.Status_Label
                 (Core, Scroll_Offset));
         end Set_Scrollback;
      begin
         Set
           (Terminal.App.Diagnostics.Grid_Status,
            Terminal.App.Resize.Grid_Status_Label
              (FB_Width,
               FB_Height,
               Terminal.App.Renderer.Cell_Width (R),
               Terminal.App.Renderer.Cell_Height (R),
               Terminal.App.Renderer.Content_Padding (R)));
         Set (Terminal.App.Diagnostics.Policy_Status, Render_Policy_Status);
         Terminal.App.Session_Runtime.With_Core
           (Active_Core, Set_Scrollback'Access);
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
              (Terminal.App.Session_Runtime.Modes (Active_Core)));
         Set
           (Terminal.App.Diagnostics.Mouse_Status,
            Terminal.App.Input_Map.Mouse_Status_Label
              (Terminal.App.Session_Runtime.Modes (Active_Core)));
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
        (Current_Core         : Terminal.App.Session_Runtime.Core_Borrow;
         PTY_Queue            : Terminal.App.Session_Runtime.PTY_Queue_Borrow;
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
         Runtime_Table       : aliased in out
           Terminal.App.Session_Table.Runtime_Table;
         Scrollback_Offset   : Natural;
         Renderer_State      : in out Terminal.App.Renderer.Renderer;
         Decision            : Terminal.App.Frame_Completion.Decision;
         Result              : in out Frame_Completion_Result)
      is separate;

      procedure Refresh_Core_State (Core : in out Terminal.Core.Terminal) is
         Badge : constant Terminal.Core.Notification_Text :=
           Terminal.Core.Badge (Core);
      begin
         Scroll_Offset :=
           Terminal.App.Scrollback_View.Clamp_Offset (Core, Scroll_Offset);
         Active_Progress := Terminal.Core.Progress (Core);
         Unbounded.Set_Unbounded_String
           (Active_Badge,
            (if Badge.Length = 0 then ""
             else Badge.Text (1 .. Badge.Length)));
         if Dirty then
            Terminal.App.Renderer.Set_Status_Overlay (R, Interaction_Status);
            Apply_Title
              (W,
               Terminal.Core.Title (Core),
               Hovered_Link,
               Has_Link_Activation,
               Link_Activation,
               Interaction_Status,
               Sessions);
         end if;
      end Refresh_Core_State;

      procedure Apply_Pending_Clipboard
        (Runtime : in out Terminal.App.Session_Runtime.Runtime) is
         Core : constant Terminal.App.Session_Runtime.Core_Borrow :=
           Active_Core;
         Clipboard_Ok : Boolean;
         procedure Apply (Item : in out Terminal.Core.Terminal) is
         begin
            Apply_Clipboard_Request
              (W,
               Runtime,
               Clipboard_Targets,
               Item,
               Protected_Input,
               Clipboard_Ok,
               Last_Write_Status,
               Last_Clipboard_Target);
         end Apply;
      begin
         Terminal.App.Session_Runtime.With_Core (Core, Apply'Access);
         if not Clipboard_Ok
           and then Terminal.App.Session_Table.Count (Sessions) = 1
         then
            GLFW_Vulkan.Windows.Set_Should_Close (W, True);
         end if;
      end Apply_Pending_Clipboard;

      procedure Handle_Present_Status
        (Status        : Terminal.App.Vulkan_Presenter.Present_Status;
         Render_Status : Terminal.App.Renderer.Render_Status;
         Decision      : out Terminal.App.Frame_Completion.Decision)
      is
      begin
         case Terminal.App.Vulkan_Presenter.Action_For (Status) is
            when Terminal.App.Vulkan_Presenter.Recreate_Device =>
               Terminal.App.Vulkan_Presenter.Finalize (Presenter);
               Terminal.App.Vulkan_Recovery.Begin_Recovery
                 (Vulkan_Recovery,
                  Terminal.App.Vulkan_Recovery.Device_Lost,
                  Recovery_Tick);
            when Terminal.App.Vulkan_Presenter.Recreate_Swapchain =>
               Terminal.App.Vulkan_Presenter.Finalize (Presenter);
               Terminal.App.Vulkan_Recovery.Begin_Recovery
                 (Vulkan_Recovery,
                  Terminal.App.Vulkan_Recovery.Swapchain_Invalid,
                  Recovery_Tick);
            when Terminal.App.Vulkan_Presenter.Presentation_Complete
               | Terminal.App.Vulkan_Presenter.Presentation_Not_Attempted
               | Terminal.App.Vulkan_Presenter.Retry_Frame
               | Terminal.App.Vulkan_Presenter.Await_Recovery
               | Terminal.App.Vulkan_Presenter.Fatal_Error =>
               null;
         end case;

         Decision := Terminal.App.Frame_Completion.Decide
           (Render_Status,
            Status,
            Terminal.App.Vulkan_Recovery.Is_Pending (Vulkan_Recovery));
         Need_Redraw := Need_Redraw or Decision.Redraw;
         if Decision.Close_Window then
            GLFW_Vulkan.Windows.Set_Should_Close (W, True);
         end if;
      end Handle_Present_Status;
   begin
      Terminal.App.Platform_Launcher.Poll;
      if Terminal.App.Global_Hotkey.Poll then
         declare
            Status : GLFW_Vulkan.Windows.Property_Status;
         begin
            GLFW_Vulkan.Windows.Toggle_Visibility (W, Status);
         end;
      end if;
      Poll_Control;
      if App_Config.Save_Workspace
        and then Ada.Real_Time.To_Duration
          (Ada.Real_Time.Clock - Last_Workspace_Save) >= Workspace_Save_Interval
      then
         begin
            Save_Workspace;
         exception
            when E : others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Session_Table,
                  E,
                  "autosave workspace");
               Last_Workspace_Save := Ada.Real_Time.Clock;
         end;
      end if;
      if Recovery_Tick < Natural'Last then
         Recovery_Tick := Recovery_Tick + 1;
      end if;
      --  Input and PTY readers post GLFW events, so idle work can sleep until
      --  the next real visual deadline. The half-second ceiling still gives
      --  lifecycle polling a bounded fallback if a platform notification is
      --  lost.
      declare
         Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         Elapsed : constant Duration :=
           Ada.Real_Time.To_Duration (Now - Blink_Origin);
         Timeout : Duration :=
           (if Input_Grace > 0 or else Need_Redraw then 0.016 else 0.5);
      begin
         if Terminal.App.Blink_Activity.Active (Visible_Blink_Activity) then
            Timeout := Duration'Min
              (Timeout, Terminal.App.Cursor_Blink.Next_Tick_Delay (Elapsed));
         end if;
         Timeout := Terminal.App.Renderer.Graphics.Animation_Wait_Duration
           (R, Timeout);
         GLFW_Vulkan.Events.Wait_Timeout (Timeout);
      end;

      Current_Blink_Tick :=
        Terminal.App.Cursor_Blink.Tick
          (Ada.Real_Time.To_Duration
             (Ada.Real_Time.Clock - Blink_Origin));
      if Terminal.App.Blink_Activity.Requires_Redraw
        (Visible_Blink_Activity, Last_Blink_Tick, Current_Blink_Tick)
      then
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      end if;
      Last_Blink_Tick := Current_Blink_Tick;

      if Terminal.App.Renderer.Graphics.Animation_Frame_Due (R) then
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      end if;

      Poll_Backends;
      Terminal.App.Accessibility.Service (Accessibility);
      Terminal.App.Session_Runtime.With_Core
        (Active_Core, Refresh_Core_State'Access);
      Terminal.App.Session_Table.With_Runtime
        (Active_Runtime, Apply_Pending_Clipboard'Access);
      Handle_Dropped_Files;

      loop
         declare
            Code_Point : Wide_Wide_Character;
            Available : Boolean;
         begin
            Terminal.App.Platform_IME.Poll_Commit (Code_Point, Available);
            exit when not Available;
            In_Q.Push
              ((Kind => Terminal.App.Queues.Character,
                Character_Event => (Code_Point => Code_Point)));
            Dirty := True;
            Need_Redraw := True;
            Local_Redraw := True;
         end;
      end loop;

      loop
         exit when Terminal.App.Session_Table.State (Active_Runtime) /=
           Terminal.App.Session_Runtime.Active;
         exit when Terminal.App.Session_Table.Has_Pending_Write
           (Active_Runtime);
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
             (Modes                =>
                Terminal.App.Session_Runtime.Modes (Active_Core),
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
          (Modes                => Terminal.App.Session_Runtime.Modes
             (Active_Core),
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
            Decision : Terminal.App.Frame_Completion.Decision;
         begin
            Terminal.App.Renderer.Presentation.Present_Retained
              (R, Vk_Ctx, Presenter, Present_Status);
            Handle_Present_Status
              (Present_Status, Terminal.App.Renderer.Ok, Decision);
         end;
      elsif Dirty or else Grace_Active then
         declare
            Visible_Count : constant Positive :=
              (if not Pane_Zoomed
                 and then Terminal.App.Splits.Count (Splits) > 1
               then Positive (Terminal.App.Splits.Count (Splits))
               else 1);
            Active_Render_Index : constant Positive :=
              (if not Pane_Zoomed
                 and then Terminal.App.Splits.Count (Splits) > 1
               then Positive (Terminal.App.Splits.Active (Splits))
               else 1);
            Snaps : Terminal.App.Renderer.Snapshot_Array renames
              Snapshot_Cache (1 .. Visible_Count);
            Render_Status : Terminal.App.Renderer.Render_Status;
            Present_Status : Terminal.App.Vulkan_Presenter.Present_Status;
            Can_Present : Boolean := True;
            Staging_Failed : Boolean := False;
            Completion : Frame_Completion_Result :=
              (Redraw => Need_Redraw, others => <>);
            Decision : Terminal.App.Frame_Completion.Decision;
         begin
            Resize_Visible_Runtimes;
            Terminal.App.Blink_Activity.Reset (Visible_Blink_Activity);
            for I in Snaps'Range loop
               declare
                  Runtime_Borrow : constant
                    Terminal.App.Session_Table.Runtime_Borrow :=
                      (if Visible_Count = 1
                       then Active_Runtime
                       else Terminal.App.Session_Table.Runtime_At
                         (Owners.Sessions,
                          Terminal.App.Sessions.Session_Index (I)));
                  Core : constant Terminal.App.Session_Runtime.Core_Borrow :=
                    Terminal.App.Session_Table.Core (Runtime_Borrow);
                  Event : Terminal.Core.Graphics_Event;
                  procedure Build_Snapshot
                    (Item : in out Terminal.Core.Terminal) is
                  begin
                     Terminal.App.Scrollback_View.Snapshot
                       (Item,
                        (if I = Active_Render_Index
                         then Scroll_Offset
                         else 0),
                        Snaps (I));

                  --  Presentation effects mark every row they modify.  The
                  --  next incremental core refresh restores those rows before
                  --  the effects are applied again, avoiding a second full
                  --  snapshot allocation without leaking transient styles.
                  if I = Active_Render_Index then
                     Terminal.App.Copy_Mode.Apply_Match_Highlights
                       (Copy_State, Snaps (I));
                     Terminal.App.Selection.Apply_To_Snapshot
                       (Snaps (I), Selection);
                  end if;
                  Terminal.App.Blink_Activity.Include
                    (Visible_Blink_Activity, Snaps (I));
                  Terminal.App.Text_Blink.Apply
                    (Snaps (I), Current_Blink_Tick);
                  Terminal.App.Cursor_Blink.Apply
                    (Snaps (I), Current_Blink_Tick);

                  --  Render the oldest unconsumed graphics command.
                  --  It is acknowledged only after a successful
                  --  presentation, so swapchain retries cannot lose
                  --  protocol events.
                  if I /= Active_Render_Index
                    or else Scroll_Offset = 0
                  then
                     Terminal.Core.Peek_Graphics_Event
                       (Item, Event);
                     Terminal.Core.Snapshot_Editing.Set_Graphics (Snaps (I), Event);
                     if Event.Pending
                       and then Event.Payload_Length > Event.Preview_Length
                     then
                        declare
                           Stage_Status : constant
                             Terminal.App.Renderer.Graphics.Stage_Event_Status :=
                               Terminal.App.Renderer.Graphics.Stage_Event
                                 (R,
                                  Item,
                                  Event);
                        begin
                           Staging_Failed := Staging_Failed or else
                             Stage_Status = Terminal.App.Renderer.Graphics
                               .Stage_Allocation_Failed;
                           if Stage_Status in
                             Terminal.App.Renderer.Graphics.Stage_Invalid_Event
                               | Terminal.App.Renderer.Graphics
                                   .Stage_Quota_Exceeded
                           then
                              --  A structurally inconsistent event cannot
                              --  become valid on retry. Retire it with an
                              --  explicit protocol error instead of leaving
                              --  the session permanently blocked.
                              Terminal.Core.Complete_Graphics_Event
                                (Item, Event,
                                 Terminal.App.Renderer.Graphics.Rejection_Result
                                   (Event,
                                    (if Stage_Status =
                                       Terminal.App.Renderer.Graphics
                                         .Stage_Quota_Exceeded
                                     then Terminal.Core.Graphics_ENOSPC
                                     else Terminal.Core.Graphics_EINVAL)));
                              Terminal.Core.Snapshot_Editing.Set_Graphics
                                (Snaps (I), (others => <>));
                              Need_Redraw := True;
                           end if;
                        end;
                     end if;
                  else
                     Terminal.Core.Snapshot_Editing.Set_Graphics
                       (Snaps (I), (others => <>));
                  end if;
                  end Build_Snapshot;
               begin
                  Terminal.App.Session_Runtime.With_Core
                    (Core, Build_Snapshot'Access);
               end;
            end loop;

            Terminal.App.Accessibility.Publish
              (Accessibility,
               Snaps (Active_Render_Index),
               FB_Width,
               FB_Height,
               Terminal.App.Renderer.Cell_Width (R),
               Terminal.App.Renderer.Cell_Height (R),
               Terminal.App.Renderer.Content_Padding (R),
               (if Unbounded.Length (Last_Tab_Title) = 0
                then "Ada Terminal"
                else Unbounded.To_String (Last_Tab_Title)),
               Interaction_Status);
            Update_IME_Cursor (Snaps (Active_Render_Index).Cursor);

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

            if Staging_Failed then
               Render_Status := Terminal.App.Renderer.Allocation_Failed;
               Present_Status :=
                 Terminal.App.Vulkan_Presenter.Not_Attempted;
            elsif Can_Present then
               Terminal.App.Renderer.Layout.Render_Pane_Layout
                 (R,
                  Snaps,
                  Active_Render_Index,
                  Terminal.App.Tabs.Snapshot (Tabs),
                  (if Pane_Zoomed
                   then
                     (Count => 1,
                      Rects =>
                        (1 => (Row => 1, Col => 1,
                               Rows => Last_Rows, Cols => Last_Cols,
                               Active => True),
                         others => <>),
                      others => <>)
                   else Terminal.App.Splits.Layout
                     (Splits, Last_Rows, Last_Cols)),
                  Render_Status);
               if Render_Status = Terminal.App.Renderer.Ok then
                  Terminal.App.Renderer.Presentation.Present
                    (R, Vk_Ctx, Presenter, Present_Status);
               else
                  Present_Status := Terminal.App.Vulkan_Presenter.Not_Attempted;
               end if;
            else
               Render_Status := Terminal.App.Renderer.Not_Initialized;
            end if;
            Handle_Present_Status (Present_Status, Render_Status, Decision);
            --  Seed the result for write/close bookkeeping.  The shared
            --  completion policy makes the final redraw decision below.
            Completion.Redraw := Need_Redraw;
            Log_Frame_Diagnostics
              (Active_Core,
               Active_PTY_Queue,
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
               Owners.Sessions,
               Scroll_Offset,
               R,
               Decision,
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


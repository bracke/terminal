separate (Terminal.App.Main_Loop.Run.Run_Frame)
procedure Poll_Backends is
   Output : Terminal.App.Session_Table.Runtime_Output_Set;
   Runtime_Feed : Terminal.Core.Feed_Status;
   Runtime_Write : Terminal.App.PTY_Write.Write_All_Status;
   Graphics_Processed : Boolean;
   Graphics_Render : Terminal.App.Renderer.Render_Status;
   Graphics_Write : Terminal.App.PTY_Write.Write_All_Status;
   Active_State : Terminal.App.Session_Runtime.Runtime_Status;
   procedure Read_State
     (Runtime : in out Terminal.App.Session_Runtime.Runtime) is
   begin
      Active_State := Terminal.App.Session_Runtime.State (Runtime);
   end Read_State;
   procedure Capture_Output
     (Index : Terminal.App.Sessions.Session_Index;
      Chunk : Terminal.App.Queues.Byte_Chunk) is
   begin
      declare
         Runtime : constant Terminal.App.Session_Table.Runtime_Borrow :=
           Terminal.App.Session_Table.Runtime_At (Sessions, Index);
      begin
         Terminal.App.Session_Recording.Record_Output
           (Recording,
            Terminal.App.Session_Table.Graphics_Stream_ID (Runtime), Chunk);
      end;
   end Capture_Output;
   procedure Deliver_Notification (Index : Terminal.App.Sessions.Session_Index) is
      Runtime : constant Terminal.App.Session_Table.Runtime_Borrow :=
        Terminal.App.Session_Table.Runtime_At (Sessions, Index);
      Core : constant Terminal.App.Session_Runtime.Core_Borrow :=
        Terminal.App.Session_Table.Core (Runtime);
      procedure Deliver (Item : in out Terminal.Core.Terminal) is
         Request : constant Terminal.Core.Notification_Request :=
           Terminal.Core.Notification (Item);
         Launch : Terminal.App.Platform_Launcher.Launch_Status;
         function Text (Value : Terminal.Core.Notification_Text) return String is
           (if Value.Length = 0 then ""
            else Value.Text (1 .. Value.Length));
      begin
         if not Request.Pending then
            return;
         end if;
         if (Request.Kind = Terminal.Core.Desktop_Notification
             and then App_Config.Desktop_Notifications)
           or else
             (Request.Kind = Terminal.Core.Terminal_Bell
              and then App_Config.Bell_Notifications)
           or else
             (Request.Kind = Terminal.Core.Command_Completion
              and then App_Config.Command_Completion_Notifications)
         then
            Terminal.App.Platform_Launcher.Show_Notification
              ((if Request.Kind = Terminal.Core.Terminal_Bell
                then "Terminal bell"
                elsif Request.Title.Length = 0
                then "Terminal notification"
                else Text (Request.Title)),
               (if Request.Kind = Terminal.Core.Terminal_Bell
                then "A process requested attention"
                else Text (Request.Message)),
               Launch);
         end if;
         Terminal.Core.Clear_Notification (Item);
      end Deliver;
   begin
      Terminal.App.Session_Runtime.With_Core (Core, Deliver'Access);
   end Deliver_Notification;
begin
   if Terminal.App.Session_Recording.Active (Recording) then
      Terminal.App.Session_Table.Poll_Output
        (Sessions, Output, Runtime_Feed, Runtime_Write, Capture_Output'Access);
   else
      Terminal.App.Session_Table.Poll_Output
        (Sessions, Output, Runtime_Feed, Runtime_Write);
   end if;
   --  Parser recovery can be reported after a graphics event releases
   --  deferred input, without a corresponding PTY read in this frame.
   if Runtime_Feed /= Terminal.Core.Ok then
      Last_Feed_Status := Runtime_Feed;
   end if;
   for I in 1 .. Terminal.App.Session_Table.Count (Sessions) loop
      Deliver_Notification (Terminal.App.Sessions.Session_Index (I));
      if Output (I) then
         Last_Feed_Status := Runtime_Feed;
         if (Terminal.App.Splits.Count (Splits) <= 1
             and then I = Terminal.App.Session_Table.Active (Sessions))
           or else
             (Terminal.App.Splits.Count (Splits) > 1
              and then I <= Terminal.App.Splits.Count (Splits))
         then
            Dirty := True;
         end if;
      end if;
   end loop;
   if Fatal_Write (Runtime_Write) then
      if Terminal.App.Session_Table.Count (Sessions) = 1 then
         GLFW_Vulkan.Windows.Set_Should_Close (W, True);
      end if;
   end if;
   Terminal.App.Session_Table.With_Runtime (Active_Runtime, Read_State'Access);
   if Terminal.App.Session_Table.Count (Sessions) = 1
     and then Active_State = Terminal.App.Session_Runtime.Exited
   then
      GLFW_Vulkan.Windows.Set_Should_Close (W, True);
   end if;

   Terminal.App.Session_Graphics.Process_Hidden
     (Owners.Sessions,
      R,
      Graphics_Processed,
      Graphics_Render,
      Graphics_Write);
   if Graphics_Processed then
      Dirty := True;
      Need_Redraw := True;
   end if;
   if Fatal_Write (Graphics_Write) then
      Last_Write_Status := Graphics_Write;
   elsif Fatal_Write (Runtime_Write) then
      Last_Write_Status := Runtime_Write;
   elsif Runtime_Write = Terminal.App.PTY_Write.Incomplete
     or else Graphics_Write = Terminal.App.PTY_Write.Incomplete
   then
      Last_Write_Status := Terminal.App.PTY_Write.Incomplete;
   elsif Last_Write_Status = Terminal.App.PTY_Write.Incomplete then
      --  Clear only the transient backpressure state. Fatal statuses remain
      --  available to diagnostics until a later explicit write replaces them.
      Last_Write_Status := Terminal.App.PTY_Write.Ok;
   end if;
   if Graphics_Render /= Terminal.App.Renderer.Ok then
      Need_Redraw := True;
   end if;
end Poll_Backends;

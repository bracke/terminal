separate (Terminal.App.Main_Loop.Run.Run_Frame)
procedure Poll_Backends is
   Output : Terminal.App.Session_Table.Runtime_Output_Set;
   Runtime_Feed : Terminal.Core.Feed_Status;
   Runtime_Write : Terminal.App.PTY_Write.Write_All_Status;
   Graphics_Processed : Boolean;
   Graphics_Render : Terminal.App.Renderer.Render_Status;
   Graphics_Write : Terminal.App.PTY_Write.Write_All_Status;
begin
   Terminal.App.Session_Table.Poll_Output
     (Sessions, Output, Runtime_Feed, Runtime_Write);
   for I in 1 .. Terminal.App.Session_Table.Count (Sessions) loop
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
      Last_Write_Status := Runtime_Write;
      if Terminal.App.Session_Table.Count (Sessions) = 1 then
         GLFW_Vulkan.Windows.Set_Should_Close (W, True);
      end if;
   elsif Runtime_Write = Terminal.App.PTY_Write.Incomplete then
      Last_Write_Status := Runtime_Write;
   end if;
   if Terminal.App.Session_Table.Count (Sessions) = 1
     and then Terminal.App.Session_Runtime.State (Active_Runtime.all) =
       Terminal.App.Session_Runtime.Exited
   then
      GLFW_Vulkan.Windows.Set_Should_Close (W, True);
   end if;

   Terminal.App.Session_Graphics.Process_Hidden
     (Sessions,
      Splits,
      R,
      Graphics_Processed,
      Graphics_Render,
      Graphics_Write);
   if Graphics_Processed then
      Dirty := True;
      Need_Redraw := True;
   end if;
   if Fatal_Write (Graphics_Write)
     or else Graphics_Write = Terminal.App.PTY_Write.Incomplete
   then
      Last_Write_Status := Graphics_Write;
   end if;
   if Graphics_Render /= Terminal.App.Renderer.Ok then
      Need_Redraw := True;
   end if;
end Poll_Backends;

separate (Terminal.App.Main_Loop.Run.Run_Frame)
      procedure Handle_Input_Event (Stop : out Boolean) is
         procedure Handle_Key_Event is separate;
         procedure Handle_Character_Event is separate;
         procedure Handle_Mouse_Button_Event is separate;
         procedure Handle_Cursor_Position_Event is separate;
         procedure Handle_Scroll_Event is separate;
         procedure Encode_Focus (Core : in out Terminal.Core.Terminal) is
         begin
            Terminal.App.Input_Map.Encode_Focus
              (Event.Focus_Event, Terminal.Core.Modes (Core), Chunk);
         end Encode_Focus;
      begin
         Stop := False;
         case Event.Kind is
            when Terminal.App.Queues.Key =>
               Handle_Key_Event;
            when Terminal.App.Queues.Character =>
               Handle_Character_Event;
            when Terminal.App.Queues.Mouse_Button =>
               Handle_Mouse_Button_Event;
            when Terminal.App.Queues.Cursor_Position =>
               Handle_Cursor_Position_Event;
            when Terminal.App.Queues.Scroll =>
               Handle_Scroll_Event;
            when Terminal.App.Queues.Focus =>
               Terminal.App.Accessibility.Set_Focused
                 (Accessibility, Event.Focus_Event.Focused);
               Terminal.App.Session_Runtime.With_Core
                 (Active_Core, Encode_Focus'Access);
            when Terminal.App.Queues.Close_Request =>
               GLFW_Vulkan.Windows.Set_Should_Close (W, True);
               Chunk := (others => <>);
            when Terminal.App.Queues.Resize_Request =>
               Chunk := (others => <>);
         end case;

         if Read_Only then
            Chunk := (others => <>);
         end if;
         if Chunk.Length > 0 then
            if Broadcast_Input and then not Protected_Input
              and then Event.Kind in
                Terminal.App.Queues.Key | Terminal.App.Queues.Character
              and then Terminal.App.Splits.Count (Splits) > 1
            then
               Write_Stat := Terminal.App.PTY_Write.Ok;
               for I in 1 .. Terminal.App.Splits.Count (Splits) loop
                  declare
                     One_Status : Terminal.App.PTY_Write.Write_All_Status;
                  begin
                     Terminal.App.Session_Table.Write
                       (Terminal.App.Session_Table.Runtime_At
                          (Sessions, Terminal.App.Sessions.Session_Index (I)),
                        Chunk, One_Status);
                     if One_Status /= Terminal.App.PTY_Write.Ok then
                        Write_Stat := One_Status;
                     end if;
                  end;
               end loop;
            else
               Terminal.App.Session_Table.Write
                 (Active_Runtime, Chunk, Write_Stat);
            end if;
            Last_Write_Status := Write_Stat;
            if Fatal_Write (Write_Stat) then
               if Terminal.App.Session_Table.Count (Sessions) = 1 then
                  GLFW_Vulkan.Windows.Set_Should_Close (W, True);
               end if;
            elsif Write_Stat = Terminal.App.PTY_Write.Incomplete then
               Stop := True;
               return;
            end if;
         end if;
      end Handle_Input_Event;

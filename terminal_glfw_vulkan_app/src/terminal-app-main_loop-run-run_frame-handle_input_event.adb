separate (Terminal.App.Main_Loop.Run.Run_Frame)
      procedure Handle_Input_Event (Stop : out Boolean) is
         procedure Handle_Key_Event is separate;
         procedure Handle_Character_Event is separate;
         procedure Handle_Mouse_Button_Event is separate;
         procedure Handle_Cursor_Position_Event is separate;
         procedure Handle_Scroll_Event is separate;
      begin
         Stop := False;
         case Event.Kind is
            when Terminal.App.Queues.Key =>
               Handle_Key_Event;
            when Terminal.App.Queues.Character =>
               Handle_Character_Event;
            when Terminal.App.Queues.Bytes =>
               Chunk := Event.Bytes;
            when Terminal.App.Queues.Mouse_Button =>
               Handle_Mouse_Button_Event;
            when Terminal.App.Queues.Cursor_Position =>
               Handle_Cursor_Position_Event;
            when Terminal.App.Queues.Scroll =>
               Handle_Scroll_Event;
            when Terminal.App.Queues.Focus =>
               Terminal.App.Input_Map.Encode_Focus
                 (Event.Focus_Event,
                  Terminal.Core.Modes (Active_Core.all),
                  Chunk);
            when Terminal.App.Queues.Close_Request =>
               GLFW_Vulkan.Windows.Set_Should_Close (W, True);
               Chunk := (others => <>);
            when Terminal.App.Queues.Resize_Request =>
               Chunk := (others => <>);
         end case;

         if Chunk.Length > 0 then
            Terminal.App.Session_Runtime.Write
              (Active_Runtime.all, Chunk, Write_Stat);
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

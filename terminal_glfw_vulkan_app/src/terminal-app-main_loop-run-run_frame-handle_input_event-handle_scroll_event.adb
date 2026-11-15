separate (Terminal.App.Main_Loop.Run.Run_Frame.Handle_Input_Event)
procedure Handle_Scroll_Event is
   procedure Process (Core : in out Terminal.Core.Terminal) is
      Pos : constant Terminal.App.Selection.Cell_Position :=
        Active_Cell_From_Pixels (Event.Scroll_Event.X, Event.Scroll_Event.Y);
      Modes : constant Terminal.Core.Mode_Snapshot := Terminal.Core.Modes (Core);
   begin
      if Terminal.App.Input_Map.Mouse_Reporting_Enabled (Modes) then
         Terminal.App.Input_Map.Encode_Mouse_Wheel
           (Event.Scroll_Event, Modes, Pos.Row, Pos.Col, Chunk);
      elsif Event.Scroll_Event.Y_Offset > 0.0 then
         Scroll_Offset :=
           Terminal.App.Scrollback_View.Clamp_Offset
             (Core, Scroll_Offset + App_Config.Wheel_Scroll_Lines);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif Event.Scroll_Event.Y_Offset < 0.0 then
         if Scroll_Offset > App_Config.Wheel_Scroll_Lines then
            Scroll_Offset := Scroll_Offset - App_Config.Wheel_Scroll_Lines;
         else
            Scroll_Offset := 0;
         end if;
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      end if;
   end Process;
begin
   Chunk := (others => <>);
   Terminal.App.Session_Runtime.With_Core (Active_Core, Process'Access);
end Handle_Scroll_Event;

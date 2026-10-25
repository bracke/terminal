separate (Terminal.App.Main_Loop.Run.Run_Frame.Handle_Input_Event)
procedure Handle_Scroll_Event is
begin
   Chunk := (others => <>);
   declare
      Pos : constant Terminal.App.Selection.Cell_Position :=
        Active_Cell_From_Pixels
          (Event.Scroll_Event.X, Event.Scroll_Event.Y);
      Modes : constant Terminal.Core.Mode_Snapshot :=
        Terminal.Core.Modes (Active_Core.all);
   begin
      if Terminal.App.Input_Map.Mouse_Reporting_Enabled
        (Modes)
      then
         Terminal.App.Input_Map.Encode_Mouse_Wheel
           (Event.Scroll_Event,
            Modes,
            Pos.Row,
            Pos.Col,
            Chunk);
      elsif Event.Scroll_Event.Y_Offset > 0.0 then
         Scroll_Offset :=
           Terminal.App.Scrollback_View.Clamp_Offset
             (Active_Core.all,
              Scroll_Offset
                + App_Config.Wheel_Scroll_Lines);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif Event.Scroll_Event.Y_Offset < 0.0 then
         if Scroll_Offset > App_Config.Wheel_Scroll_Lines then
            Scroll_Offset :=
              Scroll_Offset
                - App_Config.Wheel_Scroll_Lines;
         else
            Scroll_Offset := 0;
         end if;
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      end if;
   end;
end Handle_Scroll_Event;

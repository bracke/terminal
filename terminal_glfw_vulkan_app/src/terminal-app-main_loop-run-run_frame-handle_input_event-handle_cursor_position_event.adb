separate (Terminal.App.Main_Loop.Run.Run_Frame.Handle_Input_Event)
procedure Handle_Cursor_Position_Event is
begin
   Chunk := (others => <>);
   declare
      Pos : constant Terminal.App.Selection.Cell_Position :=
        Active_Cell_From_Pixels
          (Event.Cursor_Event.X, Event.Cursor_Event.Y);
      Modes : constant Terminal.Core.Mode_Snapshot :=
        Terminal.Core.Modes (Active_Core.all);
   begin
      if Terminal.App.Selection.Is_Active (Selection) then
         Terminal.App.Selection.Update_Selection
           (Selection, Pos);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif Terminal.App.Input_Map.Mouse_Reporting_Enabled
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
      else
         declare
            Hover_Snap : Terminal.Core.Render_Snapshot :=
              Terminal.App.Scrollback_View.Snapshot
                (Active_Core.all, Scroll_Offset);
            New_Link : constant Terminal.Core.Hyperlink :=
              Supported_Link
                (Terminal.App.Hyperlinks.Link_At
                   (Hover_Snap, Pos));
         begin
            Terminal.Core.Release (Hover_Snap);
            if not Terminal.App.Hyperlinks.Same_Link
              (Hovered_Link, New_Link)
            then
               Apply_Hovered_Link (New_Link);
               Dirty := True;
               Need_Redraw := True;
               Local_Redraw := True;
            end if;
         end;
      end if;
   end;
end Handle_Cursor_Position_Event;

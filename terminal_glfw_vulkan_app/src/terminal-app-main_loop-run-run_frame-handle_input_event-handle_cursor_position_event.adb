separate (Terminal.App.Main_Loop.Run.Run_Frame.Handle_Input_Event)
procedure Handle_Cursor_Position_Event is
   Handled : Boolean := False;
   procedure Set_Scroll_From_Pixel (Core : in out Terminal.Core.Terminal) is
      Max : constant Natural := Terminal.App.Scrollback_View.Max_Offset (Core);
      Top : constant Float :=
        Float
          (Active_Pane_Origin_Y + Terminal.App.Renderer.Content_Padding (R));
      Height : constant Float :=
        Float (Active_Pane_Rows * Terminal.App.Renderer.Cell_Height (R));
      Position : Float := Event.Cursor_Event.Y - Top;
   begin
      if Max = 0 or else Height <= 0.0 then
         Scroll_Offset := 0;
         return;
      end if;
      Position := Float'Max (0.0, Float'Min (Height, Position));
      Scroll_Offset := Natural (Float (Max) * (Height - Position) / Height);
      Scroll_Offset := Terminal.App.Scrollback_View.Clamp_Offset
        (Core, Scroll_Offset);
   end Set_Scroll_From_Pixel;

   procedure Process (Core : in out Terminal.Core.Terminal) is
      Pos : constant Terminal.App.Selection.Cell_Position :=
        Active_Cell_From_Pixels
          (Event.Cursor_Event.X, Event.Cursor_Event.Y);
      Modes : constant Terminal.Core.Mode_Snapshot := Terminal.Core.Modes (Core);
   begin
      if Terminal.App.Selection.Is_Active (Selection) then
         Terminal.App.Selection.Update_Selection (Selection, Pos);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif Terminal.App.Input_Map.Mouse_Reporting_Enabled (Modes)
        and then not Read_Only
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
              Terminal.App.Scrollback_View.Snapshot (Core, Scroll_Offset);
            New_Link : constant Terminal.Core.Hyperlink :=
              Supported_Link
                (Terminal.App.Hyperlinks.Link_At (Hover_Snap, Pos));
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
   end Process;
begin
   Chunk := (others => <>);
   case Chrome_Drag is
      when Tab_Chrome_Drag =>
         declare
            Hit : constant Terminal.App.Tabs.Tab_Count :=
              Tab_At_Pixels (Event.Cursor_Event.X, Event.Cursor_Event.Y);
         begin
            if Hit > 0 and then Hit /= Drag_Tab then
               declare
                  From : constant Terminal.App.Sessions.Session_Index :=
                    Terminal.App.Sessions.Session_Index (Drag_Tab);
                  To : constant Terminal.App.Sessions.Session_Index :=
                    Terminal.App.Sessions.Session_Index (Hit);
               begin
                  Terminal.App.Session_Table.Reorder_Tab
                    (Sessions, Drag_Tab, Terminal.App.Tabs.Tab_Index (Hit),
                     Session_Table_Status);
                  if Session_Table_Status = Terminal.App.Session_Table.Ok then
                     Move_Session_Command (From, To);
                     Drag_Tab := Terminal.App.Tabs.Tab_Index (Hit);
                  end if;
               end;
            end if;
            Handled := True;
         end;
      when Divider_Chrome_Drag =>
         declare
            State : constant Terminal.App.Splits.Split_State := Splits;
            Layout : constant Terminal.App.Splits.Pane_Layout :=
              Terminal.App.Splits.Layout (State, Last_Rows, Last_Cols);
            Row : constant Positive := Positive'Max
              (1, Positive'Min
                (Last_Rows,
                 Integer'Max
                   (1, Integer ((Event.Cursor_Event.Y - Float (Tab_Bar_Height))
                     / Float (Terminal.App.Renderer.Cell_Height (R))) + 1)));
            Col : constant Positive := Positive'Max
              (1, Positive'Min
                (Last_Cols,
                 Integer'Max
                   (1, Integer (Event.Cursor_Event.X
                     / Float (Terminal.App.Renderer.Cell_Width (R))) + 1)));
         begin
            Terminal.App.Session_Table.Move_Pane_Divider
              (Sessions, Layout, Drag_Divider, Row, Col, Session_Table_Status);
            if Session_Table_Status = Terminal.App.Session_Table.Ok then
               Configure_Visible_Cores;
            end if;
            Handled := True;
         end;
      when Scrollbar_Chrome_Drag =>
         Terminal.App.Session_Runtime.With_Core
           (Active_Core, Set_Scroll_From_Pixel'Access);
         Handled := True;
      when No_Chrome_Drag =>
         null;
   end case;

   if Handled then
      Dirty := True;
      Need_Redraw := True;
      Local_Redraw := True;
   else
      Terminal.App.Session_Runtime.With_Core (Active_Core, Process'Access);
   end if;
end Handle_Cursor_Position_Event;

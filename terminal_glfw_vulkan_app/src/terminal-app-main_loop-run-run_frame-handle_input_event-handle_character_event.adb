separate (Terminal.App.Main_Loop.Run.Run_Frame.Handle_Input_Event)
procedure Handle_Character_Event is
   Keyboard_Locked : Boolean := False;
   procedure Read_Mode (Core : in out Terminal.Core.Terminal) is
   begin
      Keyboard_Locked := Terminal.Core.Modes (Core).Keyboard_Locked;
   end Read_Mode;
begin
   Terminal.App.Session_Runtime.With_Core (Active_Core, Read_Mode'Access);
   if Terminal.App.Text_Composition.Active (Text_Composition) then
      if Wide_Wide_Character'Pos (Event.Character_Event.Code_Point) in
        Character'Pos ('0') .. Character'Pos ('9')
          | Character'Pos ('a') .. Character'Pos ('f')
          | Character'Pos ('A') .. Character'Pos ('F')
      then
         Terminal.App.Text_Composition.Append
           (Text_Composition,
            Character'Val
              (Wide_Wide_Character'Pos (Event.Character_Event.Code_Point)));
      end if;
      Chunk := (others => <>);
      Suppress_Character := Wide_Wide_Character'Val (0);
      Dirty := True;
      Need_Redraw := True;
      Local_Redraw := True;
   elsif Terminal.App.Settings.Active (Settings) then
      if Terminal.App.Settings.Editing (Settings) then
         Terminal.App.Settings.Append
           (Settings,
            Terminal.Common.Code_Point
              (Wide_Wide_Character'Pos (Event.Character_Event.Code_Point)));
      end if;
      Chunk := (others => <>);
      Suppress_Character := Wide_Wide_Character'Val (0);
      Dirty := True;
      Need_Redraw := True;
      Local_Redraw := True;
   elsif Terminal.App.Command_Palette.Active (Command_Palette) then
      if Wide_Wide_Character'Pos (Event.Character_Event.Code_Point) in 32 .. 126
      then
         Terminal.App.Command_Palette.Append
           (Command_Palette,
            Character'Val
              (Wide_Wide_Character'Pos (Event.Character_Event.Code_Point)));
      end if;
      Chunk := (others => <>);
      Suppress_Character := Wide_Wide_Character'Val (0);
      Dirty := True;
      Need_Redraw := True;
      Local_Redraw := True;
   elsif Terminal.App.Copy_Mode.Searching (Copy_State) then
      declare
         procedure Add_Search_Character
           (Core : in out Terminal.Core.Terminal) is
         begin
            Terminal.App.Copy_Mode.Append
              (Copy_State,
               Terminal.Common.Code_Point
                 (Wide_Wide_Character'Pos
                    (Event.Character_Event.Code_Point)));
            Terminal.App.Copy_Mode.Find
              (Copy_State, Core, Restart => True);
            Scroll_Offset :=
              Terminal.App.Copy_Mode.Recommended_Offset (Copy_State, Core);
            if Terminal.App.Copy_Mode.Match_Found (Copy_State) then
               Terminal.App.Copy_Mode.Select_Cursor
                 (Copy_State, Core, Scroll_Offset, Selection);
            else
               Terminal.App.Selection.Clear (Selection);
            end if;
         end Add_Search_Character;
      begin
         Terminal.App.Session_Runtime.With_Core
           (Active_Core, Add_Search_Character'Access);
      end;
      Chunk := (others => <>);
      Suppress_Character := Wide_Wide_Character'Val (0);
      Dirty := True;
      Need_Redraw := True;
      Local_Redraw := True;
   elsif Terminal.App.Hyperlinks.Hints_Active (Link_Hints)
     or else Terminal.App.Copy_Mode.Active (Copy_State)
   then
      Chunk := (others => <>);
      Suppress_Character := Wide_Wide_Character'Val (0);
   else
      Scroll_Offset := 0;
   if Suppress_Character /= Wide_Wide_Character'Val (0)
     and then Event.Character_Event.Code_Point =
       Suppress_Character
   then
      Chunk := (others => <>);
      Suppress_Character := Wide_Wide_Character'Val (0);
   elsif Keyboard_Locked then
      Chunk := (others => <>);
      Suppress_Character := Wide_Wide_Character'Val (0);
   else
      Suppress_Character := Wide_Wide_Character'Val (0);
      if Terminal.App.Selection.Has_Selection (Selection) then
         Terminal.App.Selection.Clear (Selection);
         Dirty := True;
         Local_Redraw := True;
      end if;
      Terminal.App.Input_Map.Encode_Character
        (Event.Character_Event, Chunk);
   end if;
   end if;
end Handle_Character_Event;

separate (Terminal.App.Main_Loop.Run.Run_Frame.Handle_Input_Event)
procedure Handle_Character_Event is
begin
   Scroll_Offset := 0;
   if Suppress_Character /= Wide_Wide_Character'Val (0)
     and then Event.Character_Event.Code_Point =
       Suppress_Character
   then
      Chunk := (others => <>);
      Suppress_Character := Wide_Wide_Character'Val (0);
   elsif
     Terminal.Core.Modes (Active_Core.all).Keyboard_Locked
   then
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
end Handle_Character_Event;

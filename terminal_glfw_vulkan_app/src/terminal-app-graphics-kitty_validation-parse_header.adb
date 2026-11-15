separate (Terminal.App.Graphics.Kitty_Validation)
procedure Parse_Header
  (Params   : String;
   Has_Data : Boolean;
   Result   : out Graphics_Header)
is
   Fields         : Control_Fields;
   Controls_Valid : Boolean;
begin
   Result := (Protocol => Kitty, Has_Data => Has_Data, Recognized => True,
              others => <>);
   Index_Fields (Params, Fields, Controls_Valid);
   Result.Kitty_Control_Data_Valid := Controls_Valid;
   Populate_Base_Controls (Params, Fields, Result);
   Populate_Action_Controls (Params, Fields, Result);
   Validate_Action_Controls (Params, Fields, Result);
end Parse_Header;
